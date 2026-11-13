import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

/// Google Drive direct-download + local cache (virus-scan confirm, Range resume).
///
/// EthSL videos are produced off-device (yt-dlp + FFmpeg) and hosted on Drive as
/// `.mp4` files. Store `drive:FILE_ID` or a standard Drive link in [lessons.video_url].
final class VideoDownloader {
  VideoDownloader({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// Public map exposing background download progress for UI (driveId -> 0.0..1.0)
  static final Map<String, double> downloadProgressMap = {};

  final Dio _dio;

  /// Cache of resolved Drive URLs to allow instant playback
  static final Map<String, String> _resolvedUrlCache = {};

  static String driveDirectUrl(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';

  static List<String> driveCandidateUrls(String fileId) {
    final hosts = ['drive.google.com', 'docs.google.com'];

    final urls = <String>[];
    for (final host in hosts) {
      final base = 'https://$host/uc?export=download&id=$fileId';
      urls.addAll([
        base,
        '$base&confirm=t',
        '$base&confirm=1',
        '$base&download=1',
        '$base&confirm=t&download=1',
      ]);
    }
    return urls;
  }

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
      final idParam =
          uri.queryParameters['id'] ?? uri.queryParameters['fileid'];
      if (idParam != null && idParam.isNotEmpty) return idParam;

      final filePath = RegExp(r'/file/d/([-\w]+)(?:/|$)', caseSensitive: false);
      final m2 = filePath.firstMatch(uri.path);
      if (m2 != null) return m2.group(1);

      final sharePath = RegExp(r'/d/([-\w]+)(?:/|$)', caseSensitive: false);
      final m3 = sharePath.firstMatch(uri.path);
      if (m3 != null) return m3.group(1);
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

  static final Map<String, Future<void>> _activeDownloads = {};

  void _startBackgroundDownload(String driveId, String destinationPath) {
    if (_activeDownloads.containsKey(driveId)) return;
    final downloadFuture = Future(() async {
      try {
        final tempDest = '$destinationPath.tmp';
        final tempFile = File(tempDest);
        // Resume from existing partial download (downloadDriveVideoToFile handles this internally)
        await downloadDriveVideoToFile(
          fileId: driveId,
          destinationPath: tempDest,
          onProgress: (received, total) {
            if (total > 0) {
              downloadProgressMap[driveId] = received / total;
            }
          },
        );
        downloadProgressMap.remove(driveId);
        final destFile = File(destinationPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        await tempFile.rename(destinationPath);
      } catch (e) {
        debugPrint('Background download error for $driveId: $e');
        downloadProgressMap.remove(driveId);
        try {
          final tempFile = File('$destinationPath.tmp');
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      } finally {
        _activeDownloads.remove(driveId);
      }
    });
    _activeDownloads[driveId] = downloadFuture;
  }

  /// Resolves Drive (or HTTPS) media. Streaming-first for instant playback,
  /// with background local caching for future offline use.
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
      if (await isValidVideoFile(cacheFile)) {
        return ResolvedPlaybackSource.file(cacheFile.path);
      }

      // Start background download to cache file if not already downloading
      _startBackgroundDownload(driveId, cacheFile.path);

      // Resolve direct stream URL to play immediately
      final resolved = await _resolveDownloadTarget(driveId, cancelToken);
      final streamUrl = (resolved as _StreamUrl).url;
      return ResolvedPlaybackSource.network(streamUrl);
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

    if (await dest.exists() && await isValidVideoFile(dest)) {
      onProgress?.call(await dest.length(), await dest.length());
      return;
    }

    final resolved = await _resolveDownloadTarget(fileId, cancelToken);
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

    if (await dest.exists() && await isValidVideoFile(dest)) {
      onProgress?.call(await dest.length(), await dest.length());
      return;
    }

    final driveId = parseDriveFileId(urlOrFileId);
    if (driveId != null) {
      final resolved = await _resolveDownloadTarget(driveId, cancelToken);
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
    // 1. Check in-memory cache first for instant resolution
    if (_resolvedUrlCache.containsKey(fileId)) {
      final cachedUrl = _resolvedUrlCache[fileId]!;
      debugPrint('Drive resolution cache hit (memory) for $fileId: $cachedUrl');
      return _StreamUrl(cachedUrl);
    }

    // 2. Check persistent cache for instant resolution
    final persistentCachedUrl = await _getPersistentCache(fileId);
    if (persistentCachedUrl != null) {
      debugPrint('Drive resolution cache hit (persistent) for $fileId: $persistentCachedUrl');
      _resolvedUrlCache[fileId] = persistentCachedUrl;
      return _StreamUrl(persistentCachedUrl);
    }

    const headers = {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/octet-stream,video/*,*/*;q=0.8',
    };

    Object? lastError;
    for (final candidateUrl in driveCandidateUrls(fileId)) {
      try {
        final response = await _dio.get<ResponseBody>(
          candidateUrl,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: true,
            maxRedirects: 16,
            validateStatus: (c) => c != null && c < 500,
            headers: headers,
          ),
          cancelToken: cancelToken,
        );

        final stream = response.data?.stream;
        if (stream == null) {
          lastError = StateError('Empty stream response from Drive for file $fileId');
          continue;
        }

        final bytes = <int>[];
        bool looksHtml = false;

        await for (final chunk in stream) {
          bytes.addAll(chunk);
          if (bytes.isNotEmpty) {
            // Check if response starts with '<' (HTML / DOCTYPE)
            looksHtml = bytes[0] == 0x3C;
            if (!looksHtml) {
              break;
            }
          }
          if (bytes.length > 256 * 1024) break; // limit to 256KB for safety
        }

        if (!looksHtml) {
          // Direct video stream! Close connection stream to free resources
          try {
            final sub = stream.listen((_) {});
            await sub.cancel();
          } catch (_) {}

          final directUrl = response.realUri.toString();
          debugPrint('Drive direct URL resolved (non-HTML): $directUrl');
          _resolvedUrlCache[fileId] = directUrl;
          _setPersistentCache(fileId, directUrl); // non-blocking save
          return _StreamUrl(directUrl);
        }

        final html = String.fromCharCodes(bytes);
        final userContent = RegExp(
          r'https://drive\.usercontent\.google\.com/download[^\s"<>]+',
          caseSensitive: false,
        ).firstMatch(html)?.group(0);
        if (userContent != null) {
          final resolved = Uri.decodeFull(userContent.replaceAll('&amp;', '&'));
          debugPrint('Drive user content URL resolved: $resolved');
          _resolvedUrlCache[fileId] = resolved;
          _setPersistentCache(fileId, resolved); // non-blocking save
          return _StreamUrl(resolved);
        }

        final downloadUrl = RegExp(
          r'https://[^\s"<>]+(?:/download|\?export=download)[^\s"<>]*',
          caseSensitive: false,
        ).firstMatch(html)?.group(0);
        if (downloadUrl != null) {
          final resolved = Uri.decodeFull(downloadUrl.replaceAll('&amp;', '&'));
          debugPrint('Drive download URL resolved: $resolved');
          _resolvedUrlCache[fileId] = resolved;
          _setPersistentCache(fileId, resolved); // non-blocking save
          return _StreamUrl(resolved);
        }

        final confirm = _extractConfirmToken(html);
        if (confirm != null && confirm.isNotEmpty) {
          final resolved = '$candidateUrl&confirm=$confirm';
          debugPrint('Drive URL resolved with confirm token: $resolved');
          _resolvedUrlCache[fileId] = resolved;
          _setPersistentCache(fileId, resolved); // non-blocking save
          return _StreamUrl(resolved);
        }

        lastError = StateError(
          'Drive returned HTML warning page but could not extract confirmation/download URL',
        );
      } on DioException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      debugPrint('Drive resolution failed for $fileId: $lastError');
      if (lastError is Exception) {
        throw lastError;
      }
      if (lastError is Error) {
        throw lastError;
      }
      throw StateError(lastError.toString());
    }

    throw StateError(
      'Could not resolve Google Drive video for $fileId. Try sharing the file publicly.',
    );
  }

  static String? _extractConfirmToken(String html) {
    final patterns = <RegExp>[
      RegExp(r'name="confirm"\s+value="([^"]+)"', caseSensitive: false),
      RegExp(r'id="confirm"\s+value="([^"]+)"', caseSensitive: false),
      RegExp(r'"confirm"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'data-confirm="([^"]+)"', caseSensitive: false),
      RegExp(r'confirm=([0-9A-Za-z_\-]+)', caseSensitive: false),
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
          validateStatus: (c) =>
              c != null && (c == 200 || c == 206 || c == 416),
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

      var bytesSinceFlush = 0;
      const flushThreshold = 2 * 1024 * 1024; // flush every 2MB
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        bytesSinceFlush += chunk.length;
        if (onProgress != null && totalLen != null) {
          onProgress(received, totalLen);
        } else {
          onProgress?.call(received, received);
        }
        if (bytesSinceFlush >= flushThreshold) {
          await sink.flush();
          bytesSinceFlush = 0;
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

  static SharedPreferences? _prefs;

  static Future<void> _initPrefs() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Future<String?> _getPersistentCache(String fileId) async {
    await _initPrefs();
    if (_prefs == null) return null;
    final data = _prefs!.getString('resolved_drive_$fileId');
    if (data == null) return null;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final timestamp = json['timestamp'] as int;
      final url = json['url'] as String;
      
      // Google Drive links are valid for at least 4 hours.
      // Let's use a safe threshold of 3 hours (10,800,000 milliseconds).
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp < 6 * 3600 * 1000) {
        return url;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _setPersistentCache(String fileId, String url) async {
    await _initPrefs();
    if (_prefs == null) return;
    try {
      final data = jsonEncode({
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _prefs!.setString('resolved_drive_$fileId', data);
    } catch (_) {}
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

final class _StreamUrl extends _DownloadTarget {
  _StreamUrl(this.url);
  final String url;
}
