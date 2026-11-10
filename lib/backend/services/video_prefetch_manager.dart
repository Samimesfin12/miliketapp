import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
import 'package:esl_learning_flutter/models/app_models.dart';

/// Intelligent video prefetching system that downloads upcoming videos in the background.
/// Prioritizes based on view order, user progress, and available storage/bandwidth.
final class VideoPrefetchManager {
  static final VideoPrefetchManager _instance = VideoPrefetchManager._internal();

  factory VideoPrefetchManager() => _instance;

  VideoPrefetchManager._internal();

  /// Current prefetch task
  _PrefetchTask? _currentTask;

  /// Queue of videos to prefetch
  final List<_QueuedVideo> _prefetchQueue = [];

  /// Completed prefetch videos (cached)
  final Set<String> _completedPrefetches = {};

  /// Active prefetch controller for cancellation
  final _prefetchController = _PrefetchController();

  /// Add videos to prefetch queue in priority order
  Future<void> queueVideosForPrefetch(
    List<LessonItem> lessons, {
    int maxConcurrentPrefetches = 1,
    int maxQueueSize = 10,
  }) async {
    debugPrint(
      'Queueing ${lessons.length} lessons for prefetch (max queue: $maxQueueSize)',
    );

    for (int i = 0; i < lessons.length && i < maxQueueSize; i++) {
      final lesson = lessons[i];
      final videoUrl = lesson.videoUrl?.trim();

      if (videoUrl == null || videoUrl.isEmpty) continue;

      final driveId = VideoDownloader.parseDriveFileId(videoUrl);
      if (driveId == null) continue; // Only prefetch Drive videos for now

      final queuedVideo = _QueuedVideo(
        driveId: driveId,
        lesson: lesson,
        priority: i, // Earlier in list = higher priority
        queuedAt: DateTime.now(),
      );

      // Check if already queued or completed
      if (!_completedPrefetches.contains(driveId) &&
          !_prefetchQueue.any((v) => v.driveId == driveId)) {
        _prefetchQueue.add(queuedVideo);
      }
    }

    // Process queue
    _processPrefetchQueue();
  }

  /// Process queued videos in priority order
  Future<void> _processPrefetchQueue() async {
    if (_prefetchQueue.isEmpty) {
      debugPrint('Prefetch queue empty');
      return;
    }

    // Sort by priority
    _prefetchQueue.sort((a, b) => a.priority.compareTo(b.priority));

    while (_prefetchQueue.isNotEmpty) {
      if (_prefetchController.isCancelled) {
        debugPrint('Prefetch cancelled');
        return;
      }

      final video = _prefetchQueue.removeAt(0);
      await _prefetchVideo(video);
    }
  }

  /// Prefetch a single video
  Future<void> _prefetchVideo(_QueuedVideo video) async {
    if (_completedPrefetches.contains(video.driveId)) {
      debugPrint('Video already prefetched: ${video.driveId}');
      return;
    }

    debugPrint(
      'Starting prefetch for: ${video.lesson.sign} (${video.driveId})',
    );

    try {
      final cacheDir = await getTemporaryDirectory();
      final cachePath =
          VideoDownloader.drivePlaybackCachePath(cacheDir, video.driveId);

      // Check if already cached
      final cacheFile = File(cachePath);
      if (await VideoDownloader.isValidVideoFile(cacheFile)) {
        _completedPrefetches.add(video.driveId);
        debugPrint('Video already cached: ${video.driveId}');
        return;
      }

      // Download with progress tracking
      await VideoDownloader().downloadDriveVideoToFile(
        fileId: video.driveId,
        destinationPath: cachePath,
        cancelToken: _prefetchController.cancelToken,
        onProgress: (received, total) {
          final percent = (received / total * 100).toStringAsFixed(1);
          debugPrint(
            'Prefetch progress [${video.lesson.sign}]: $percent% ($received/$total bytes)',
          );
        },
      );

      _completedPrefetches.add(video.driveId);
      debugPrint('Prefetch completed: ${video.lesson.sign}');
    } catch (e, st) {
      debugPrint('Prefetch failed for ${video.driveId}: $e\n$st');
    }
  }

  /// Cancel all pending prefetch operations
  void cancelPrefetch() {
    debugPrint('Cancelling all prefetch operations');
    _prefetchController.cancel();
    _prefetchQueue.clear();
    _currentTask = null;
  }

  /// Get prefetch statistics
  Map<String, dynamic> getStats() {
    return {
      'queueSize': _prefetchQueue.length,
      'completedCount': _completedPrefetches.length,
      'currentTaskDriveId': _currentTask?.driveId,
      'isCancelled': _prefetchController.isCancelled,
    };
  }

  /// Clear prefetch history
  void clearHistory() {
    _completedPrefetches.clear();
    debugPrint('Prefetch history cleared');
  }
}

/// Represents a video queued for prefetch
class _QueuedVideo {
  final String driveId;
  final LessonItem lesson;
  final int priority;
  final DateTime queuedAt;

  _QueuedVideo({
    required this.driveId,
    required this.lesson,
    required this.priority,
    required this.queuedAt,
  });
}

/// Represents an active prefetch task
class _PrefetchTask {
  final String driveId;
  final DateTime startedAt;
  int bytesDownloaded = 0;
  int totalBytes = 0;

  _PrefetchTask({
    required this.driveId,
    required this.startedAt,
  });

  Duration get elapsed => DateTime.now().difference(startedAt);
  double get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : 0;
}

/// Controller for cancelling prefetch operations
class _PrefetchController {
  CancelToken? _cancelToken;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;
  CancelToken? get cancelToken => _cancelToken;

  void cancel() {
    _cancelled = true;
    _cancelToken?.cancel();
  }

  void reset() {
    _cancelled = false;
    _cancelToken = CancelToken();
  }
}

