import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Google Drive direct-download + local cache (virus-scan confirm, Range resume).
///
/// EthSL videos are produced off-device (yt-dlp + FFmpeg) and hosted on Drive as
/// `.mp4` files. Store `drive:FILE_ID` or a standard Drive link in [lessons.video_url].
final class VideoDownloader {
  VideoDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static String driveDirectUrl(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';

  static String defaultLessonVideoPath(Directory root, String lessonId) =>
      p.join(root.path, 'lesson_videos', '$lessonId.mp4');

  /// Extracts a Drive file id from [videoUrl], or `null` if not Drive-backed.
  static String? parseDriveFileId(String? videoUrl) {
    if (videoUrl == null) return null;
    final s = videoUrl.trim();
    if (s.isEmpty) return null;

    final drivePrefix = RegExp(r'^drive:([-\w]+)$', caseSensitive: false);
    final m0 = drivePrefix.firstMatch(s);
    if (m0 != null) return m0.group(1);

    Uri? uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final isDriveHost =
        host == 'drive.google.com' || host.endsWith('.drive.google.com');

    if (isDriveHost) {
      final idParam = uri.queryParameters['id'];
      if (idParam != null && idParam.isNotEmpty) return idParam;

      final filePath = RegExp(r'/file/d/([-\w]+)');
      final m2 = filePath.firstMatch(uri.path);
      if (m2 != null) return m2.group(1);
    }

    // Bare file id stored without drive: prefix (e.g. family Father lesson).
    if (!s.contains('://') &&
        !s.contains('/') &&
        RegExp(r'^[-\w]{10,}$').hasMatch(s)) {
      return s;
    }

    return null;
  }

  static String drivePlaybackCachePath(Directory cacheDir, String fileId) =>
      p.join(cacheDir.path, 'drive_playback_cache', '$fileId.mp4');

  /// True when [file] exists and is not an HTML error page from Drive.
  static Future<bool> isValidVideoFile(File file) async {
    if (!await file.exists()) return false;
    final size = await file.length();
    if (size < 512) return false;
    final raf = await file.open();
    try {
      final head = await raf.read(12);
      if (head.isEmpty) return false;
      if (head[0] == 0x3C) return false;
      if (head.length >= 8 &&
          String.fromCharCodes(head.sublist(4, 8)) == 'ftyp') {
        return true;
      }
      if (head.length >= 4 &&
          head[0] == 0x1A &&
          head[1] == 0x45 &&
          head[2] == 0xDF &&
          head[3] == 0xA3) {
        return true;
      }
      return size > 10 * 1024;
    } finally {
      await raf.close();
    }
  }

  /// Downloads Drive (or HTTPS) media into [cacheDir] and returns a local file path.
  /// ExoPlayer cannot stream raw Drive links; caching avoids 403/HTML responses.
  Future<ResolvedPlaybackSource> resolvePlaybackSource(
    String urlOrFileId, {
    required Directory cacheDir,
    CancelToken? cancelToken,
  }) async {
    final trimmed = urlOrFileId.trim();
    final driveId = parseDriveFileId(trimmed);
    if (driveId != null) {
      final cacheFile = File(drivePlaybackCachePath(cacheDir, driveId));
      await cacheFile.parent.create(recursive: true);
      if (!await isValidVideoFile(cacheFile)) {
        if (await cacheFile.exists()) await cacheFile.delete();
        await downloadDriveVideoToFile(
          fileId: driveId,
          destinationPath: cacheFile.path,
          cancelToken: cancelToken,
        );
        if (!await isValidVideoFile(cacheFile)) {
          throw StateError(
            'Drive file $driveId did not download as video. '
            'Share it as "Anyone with the link".',
          );
        }
      }
      return ResolvedPlaybackSource.file(cacheFile.path);
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return ResolvedPlaybackSource.network(trimmed);
    }

    throw ArgumentError('Unsupported video source: $urlOrFileId');
  }

  /// Downloads Drive [fileId] to [destinationPath] with streaming I/O and Range resume.
  Future<void> downloadDriveVideoToFile({
    required String fileId,
    required String destinationPath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await Directory(p.dirname(destinationPath)).create(recursive: true);
    final dest = File(destinationPath);

    final resolved = await _resolveDownloadTarget(fileId, cancelToken);
    if (resolved is _DirectBytes) {
      await dest.writeAsBytes(resolved.bytes, flush: true);
      onProgress?.call(resolved.bytes.length, resolved.bytes.length);
      return;
    }

    final url = (resolved as _StreamUrl).url;
    var resumeFrom = 0;
    if (await dest.exists()) {
      resumeFrom = await dest.length();
    }

    await _streamDownloadWithResume(
      url: url,
      destination: dest,
      resumeFrom: resumeFrom,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (!await isValidVideoFile(dest)) {
      await dest.delete();
      throw StateError(
        'Drive file $fileId did not download as video. '
        'Share it as "Anyone with the link".',
      );
    }
  }

  /// Downloads a video (either a Google Drive ID/URL or a standard web URL) to the local file system.
  Future<void> downloadVideoToFile({
    required String urlOrFileId,
    required String destinationPath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await Directory(p.dirname(destinationPath)).create(recursive: true);
    final dest = File(destinationPath);

    final driveId = parseDriveFileId(urlOrFileId);
    if (driveId != null) {
      final resolved = await _resolveDownloadTarget(driveId, cancelToken);
      if (resolved is _DirectBytes) {
        await dest.writeAsBytes(resolved.bytes, flush: true);
        onProgress?.call(resolved.bytes.length, resolved.bytes.length);
        return;
      }

      final url = (resolved as _StreamUrl).url;
      var resumeFrom = 0;
      if (await dest.exists()) {
        resumeFrom = await dest.length();
      }

      await _streamDownloadWithResume(
        url: url,
        destination: dest,
        resumeFrom: resumeFrom,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      var resumeFrom = 0;
      if (await dest.exists()) {
        resumeFrom = await dest.length();
      }
      await _streamDownloadWithResume(
        url: urlOrFileId,
        destination: dest,
        resumeFrom: resumeFrom,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  /// First hop: small HTML (virus scan) vs immediate binary (small files).
  Future<_DownloadTarget> _resolveDownloadTarget(
    String fileId,
    CancelToken? cancelToken,
  ) async {
    final initial = driveDirectUrl(fileId);
    final probe = await _dio.get<List<int>>(
      initial,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (c) => c != null && c < 500,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
        },
      ),
      cancelToken: cancelToken,
    );

    final bytes = probe.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty response from Drive for file $fileId');
    }

    final ct = probe.headers.value('content-type')?.toLowerCase() ?? '';
    final looksHtml =
        ct.contains('text/html') ||
        (bytes.length >= 2 && bytes[0] == 0x3C && (bytes[1] == 0x21 || bytes[1] == 0x68));

    if (!looksHtml) {
      return _DirectBytes(Uint8List.fromList(bytes));
    }

    final html = String.fromCharCodes(bytes);
    final userContent = RegExp(
      r'https://drive\.usercontent\.google\.com/download[^\s"<>]+',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);
    if (userContent != null) {
      return _StreamUrl(
        Uri.decodeFull(userContent.replaceAll('&amp;', '&')),
      );
    }

    final confirm = _extractConfirmToken(html);
    if (confirm != null && confirm.isNotEmpty) {
      return _StreamUrl('$initial&confirm=$confirm');
    }

    // Large-file workaround when Google omits a confirm input on the scan page.
    return _StreamUrl('$initial&confirm=t');
  }

  static String? _extractConfirmToken(String html) {
    final patterns = <RegExp>[
      RegExp(r'name="confirm"\s+value="([^"]+)"', caseSensitive: false),
      RegExp(r'id="confirm"\s+value="([^"]+)"', caseSensitive: false),
      RegExp(r'"confirm"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'data-confirm="([^"]+)"', caseSensitive: false),
      RegExp(
        r'confirm=([0-9A-Za-z_\-]+)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final token = match?.group(1);
      if (token != null && token.isNotEmpty && token != 't') return token;
    }
    return null;
  }

  Future<void> _streamDownloadWithResume({
    required String url,
    required File destination,
    required int resumeFrom,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    };
    if (resumeFrom > 0) {
      headers['Range'] = 'bytes=$resumeFrom-';
    }

    late Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          maxRedirects: 12,
          validateStatus: (c) => c != null && (c == 200 || c == 206 || c == 416),
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (resumeFrom > 0 && e.response?.statusCode == 416) {
        if (await destination.exists()) await destination.delete();
        await _streamDownloadWithResume(
          url: url,
          destination: destination,
          resumeFrom: 0,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        return;
      }
      rethrow;
    }

    final code = response.statusCode ?? 0;
    if (code == 416) {
      if (await destination.exists()) await destination.delete();
      await _streamDownloadWithResume(
        url: url,
        destination: destination,
        resumeFrom: 0,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    if (code != 200 && code != 206) {
      throw StateError('Unexpected HTTP $code for Drive download');
    }

    final totalLen = _parseTotalLength(response.headers, resumeFrom);

    var received = resumeFrom;
    IOSink? sink;
    try {
      sink = destination.openWrite(
        mode: resumeFrom > 0 ? FileMode.append : FileMode.write,
      );

      final stream = response.data?.stream;
      if (stream == null) throw StateError('Empty download stream');

      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && totalLen != null) {
          onProgress(received, totalLen);
        } else {
          onProgress?.call(received, received);
        }
      }
      await sink.flush();
    } finally {
      await sink?.close();
    }

    if (onProgress != null && totalLen != null) {
      onProgress(totalLen, totalLen);
    }
  }

  static int? _parseTotalLength(Headers headers, int resumeFrom) {
    final cr = headers.value('content-range');
    if (cr != null) {
      final m = RegExp(r'bytes\s+\d+-\d+/(\d+)').firstMatch(cr);
      if (m != null) return int.tryParse(m.group(1)!);
    }
    final cl = headers.value('content-length');
    final n = int.tryParse(cl ?? '');
    if (n == null) return null;
    return resumeFrom + n;
  }
}

/// Playback target after resolving Google Drive virus-scan / redirect pages.
final class ResolvedPlaybackSource {
  const ResolvedPlaybackSource._({this.networkUrl, this.filePath});

  factory ResolvedPlaybackSource.network(String url) =>
      ResolvedPlaybackSource._(networkUrl: url);

  factory ResolvedPlaybackSource.file(String path) =>
      ResolvedPlaybackSource._(filePath: path);

  final String? networkUrl;
  final String? filePath;
}

sealed class _DownloadTarget {}

final class _DirectBytes extends _DownloadTarget {
  _DirectBytes(this.bytes);
  final Uint8List bytes;
}

final class _StreamUrl extends _DownloadTarget {
  _StreamUrl(this.url);
  final String url;
}
