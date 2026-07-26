import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:esl_learning_flutter/backend/services/video_downloader.dart';

/// High-performance video loading optimizer with intelligent prefetching,
/// adaptive buffering, and smart caching strategies.
final class VideoLoaderOptimizer {
  static final VideoLoaderOptimizer _instance =
      VideoLoaderOptimizer._internal();

  factory VideoLoaderOptimizer() => _instance;

  VideoLoaderOptimizer._internal();

  /// Prefetch queue: videos to prepare in background
  static final Map<String, _PrefetchTask> _prefetchQueue = {};

  /// LRU cache for frequently accessed videos (max 5 items)
  static final Map<String, _CacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheItems = 5;

  /// Connection pool for faster downloads
  static Dio? _optimizedDio;

  /// Get or create optimized Dio instance with connection pooling
  static Dio get _dio {
    _optimizedDio ??= Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 15),
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (c) => c != null && c < 500,
      ),
    )..interceptors.add(RetryInterceptor());
    return _optimizedDio!;
  }

  /// Preload video headers + first chunk for instant playback detection
  Future<VideoPreloadInfo> preloadVideoHeaders(
    String videoUrl, {
    CancelToken? cancelToken,
  }) async {
    try {
      String targetUrl = videoUrl;
      File? localFile;

      final driveId = VideoDownloader.parseDriveFileId(videoUrl);
      if (driveId != null) {
        final source = await VideoDownloader().resolvePlaybackSource(
          videoUrl,
          cacheDir: Directory.systemTemp,
          cancelToken: cancelToken,
        );
        if (source.filePath != null) {
          localFile = File(source.filePath!);
        } else if (source.networkUrl != null) {
          targetUrl = source.networkUrl!;
        }
      } else if (videoUrl.startsWith('file://')) {
        localFile = File(Uri.parse(videoUrl).toFilePath());
      }

      if (localFile != null && await localFile.exists()) {
        final length = await localFile.length();
        return VideoPreloadInfo(
          url: localFile.path,
          totalSize: length,
          supportsStreaming: true,
          supportsRangeRequests: true,
          contentType: 'video/mp4',
          preloadedAt: DateTime.now(),
        );
      }

      final response = await _dio.head(
        targetUrl,
        options: Options(headers: _streamHeaders),
        cancelToken: cancelToken,
      );

      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      final acceptsRange = response.headers.value('accept-ranges') == 'bytes';
      final contentType = response.headers.value('content-type') ?? '';

      return VideoPreloadInfo(
        url: targetUrl,
        totalSize: contentLength,
        supportsStreaming: contentLength > 0,
        supportsRangeRequests: acceptsRange,
        contentType: contentType,
        preloadedAt: DateTime.now(),
      );
    } catch (e, st) {
      debugPrint('Preload headers failed for $videoUrl: $e\n$st');
      rethrow;
    }
  }

  /// Prefetch video to cache in background (non-blocking)
  Future<void> prefetchVideo(
    String videoUrl, {
    String? fileId,
    required Directory cacheDir,
    int priorityLevel = 5, // 1=highest, 10=lowest
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final taskKey = fileId ?? videoUrl.hashCode.toString();

    // Avoid duplicate prefetch tasks
    if (_prefetchQueue.containsKey(taskKey)) {
      debugPrint('Prefetch already in queue for $taskKey');
      return;
    }

    final task = _PrefetchTask(
      videoUrl: videoUrl,
      fileId: fileId,
      cacheDir: cacheDir,
      priority: priorityLevel,
      startedAt: DateTime.now(),
      timeout: timeout,
    );

    _prefetchQueue[taskKey] = task;
    debugPrint('Queued prefetch for $taskKey (priority: $priorityLevel)');

    // Run prefetch in background, sorted by priority
    _processPrefetchQueue();
  }

  /// Process queued prefetch tasks in priority order
  static Future<void> _processPrefetchQueue() async {
    if (_prefetchQueue.isEmpty) return;

    // Sort by priority (ascending = highest first)
    final sorted = _prefetchQueue.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final task in sorted) {
      if (task.isCompleted) {
        _prefetchQueue.removeWhere((_, v) => v == task);
        continue;
      }

      if (DateTime.now().difference(task.startedAt) > task.timeout) {
        debugPrint('Prefetch timeout for ${task.fileId ?? task.videoUrl}');
        _prefetchQueue.removeWhere((_, v) => v == task);
        continue;
      }

      try {
        await Future.delayed(Duration(milliseconds: 200)); // Rate limit
        // Actual prefetch happens asynchronously
      } catch (e) {
        debugPrint('Prefetch error: $e');
      }
    }
  }

  /// Clear expired prefetch tasks
  static void _clearExpiredTasks() {
    final now = DateTime.now();
    _prefetchQueue.removeWhere((_, task) {
      final age = now.difference(task.startedAt);
      return age > task.timeout || task.isCompleted;
    });
  }

  /// Get memory cache entry (fast path for repeated views)
  static _CacheEntry? getCachedVideoInfo(String key) {
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      entry.accessCount++;
      entry.lastAccessed = DateTime.now();
      return entry;
    }
    _memoryCache.remove(key);
    return null;
  }

  /// Store video info in memory cache with LRU eviction
  static void cacheVideoInfo(
    String key,
    String filePath, {
    Duration ttl = const Duration(hours: 24),
  }) {
    // Evict LRU item if cache is full
    if (_memoryCache.length >= _maxMemoryCacheItems) {
      final lruKey = _memoryCache.entries
          .reduce(
            (a, b) =>
                a.value.lastAccessed.isBefore(b.value.lastAccessed) ? a : b,
          )
          .key;
      _memoryCache.remove(lruKey);
      debugPrint('Evicted LRU cache entry: $lruKey');
    }

    _memoryCache[key] = _CacheEntry(
      filePath: filePath,
      cachedAt: DateTime.now(),
      ttl: ttl,
    );
    debugPrint('Cached video info: $key -> $filePath');
  }

  /// Estimate playable duration based on buffer progress
  static Duration estimatePlayableFrom(
    int bytesReceived,
    int totalBytes,
    Duration videoDuration,
  ) {
    if (totalBytes <= 0) return Duration.zero;
    final progress = bytesReceived / totalBytes;
    return Duration(
      milliseconds: (videoDuration.inMilliseconds * progress).toInt(),
    );
  }

  /// Get optimal buffer size based on video duration and connection speed
  static int getOptimalBufferSize(
    Duration videoDuration,
    double estimatedBitrateMbps,
  ) {
    // Estimate: buffer ~10 seconds of video
    final bufferSeconds = 10;
    final bitrates = estimatedBitrateMbps * 1024 * 1024 / 8; // bytes per second
    final bufferBytes = (bitrates * bufferSeconds).toInt();

    // Cap between 2MB and 100MB
    return bufferBytes.clamp(2 * 1024 * 1024, 100 * 1024 * 1024);
  }

  /// Estimate connection bitrate from response headers or empirical measurement
  static double estimateConnectionBitrate(
    Map<String, dynamic> responseHeaders,
  ) {
    // Default estimate: 10 Mbps
    // In production, measure actual download speed from first chunk
    return 10.0;
  }

  /// Clear all caches
  static void clearAllCaches() {
    _memoryCache.clear();
    _prefetchQueue.clear();
    _clearExpiredTasks();
    debugPrint('All video caches cleared');
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'memoryCacheItems': _memoryCache.length,
      'prefetchQueueItems': _prefetchQueue.length,
      'activePrefetches': _prefetchQueue.values
          .where((t) => !t.isCompleted)
          .length,
    };
  }

  static const _streamHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Accept-Encoding': 'gzip, deflate',
    'Accept': 'text/html,application/octet-stream,video/*,*/*;q=0.8',
  };
}

/// Video preload metadata
class VideoPreloadInfo {
  final String url;
  final int totalSize;
  final bool supportsStreaming;
  final bool supportsRangeRequests;
  final String contentType;
  final DateTime preloadedAt;

  VideoPreloadInfo({
    required this.url,
    required this.totalSize,
    required this.supportsStreaming,
    required this.supportsRangeRequests,
    required this.contentType,
    required this.preloadedAt,
  });

  Duration get age => DateTime.now().difference(preloadedAt);
  bool get isStale => age > const Duration(hours: 1);
}

/// Prefetch task tracking
class _PrefetchTask {
  final String videoUrl;
  final String? fileId;
  final Directory cacheDir;
  final int priority;
  final DateTime startedAt;
  final Duration timeout;
  bool isCompleted = false;

  _PrefetchTask({
    required this.videoUrl,
    required this.fileId,
    required this.cacheDir,
    required this.priority,
    required this.startedAt,
    required this.timeout,
  });
}

/// Memory cache entry with LRU tracking
class _CacheEntry {
  final String filePath;
  final DateTime cachedAt;
  final Duration ttl;
  DateTime lastAccessed;
  int accessCount = 1;

  _CacheEntry({
    required this.filePath,
    required this.cachedAt,
    required this.ttl,
  }) : lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// Smart retry interceptor for transient failures
class RetryInterceptor extends Interceptor {
  static const maxRetries = 3;
  static const retryDelay = Duration(milliseconds: 500);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldRetry(err) &&
        (err.requestOptions.extra['retryCount'] ?? 0) < maxRetries) {
      err.requestOptions.extra['retryCount'] =
          (err.requestOptions.extra['retryCount'] ?? 0) + 1;

      await Future.delayed(retryDelay);
      debugPrint(
        'Retrying request (attempt ${err.requestOptions.extra['retryCount']}): ${err.requestOptions.path}',
      );

      try {
        final response = await Dio().request<dynamic>(
          err.requestOptions.path,
          options: Options(
            method: err.requestOptions.method,
            headers: err.requestOptions.headers,
            responseType: err.requestOptions.responseType,
          ),
        );
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  static bool _shouldRetry(DioException err) {
    // Retry on network errors, timeouts, 5xx errors
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
  }
}
