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

    return null;
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
      r'"(https://drive\.usercontent\.google\.com/download[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (userContent != null) {
      return _StreamUrl(Uri.decodeFull(userContent.replaceAll('&amp;', '&')));
    }

    final confirm = _extractConfirmToken(html);
    if (confirm == null || confirm.isEmpty) {
      throw StateError(
        'Could not parse Drive confirm token (virus-scan page). '
        'Ensure the file is shared as "Anyone with the link" and the id is correct.',
      );
    }

    final withConfirm = '$initial&confirm=$confirm';
    return _StreamUrl(withConfirm);
  }

  static String? _extractConfirmToken(String html) {
    final input = RegExp(
      r'name="confirm"\s+value="([^"]+)"',
      caseSensitive: false,
    );
    final m1 = input.firstMatch(html);
    if (m1 != null) return m1.group(1);

    final href = RegExp(r'confirm=([\w-]+)', caseSensitive: false);
    final m2 = href.firstMatch(html);
    if (m2 != null) return m2.group(1);
    return null;
  }

  Future<void> _streamDownloadWithResume({
    required String url,
    required File destination,
    required int resumeFrom,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final headers = <String, dynamic>{};
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

sealed class _DownloadTarget {}

final class _DirectBytes extends _DownloadTarget {
  _DirectBytes(this.bytes);
  final Uint8List bytes;
}

final class _StreamUrl extends _DownloadTarget {
  _StreamUrl(this.url);
  final String url;
}
