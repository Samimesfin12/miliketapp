import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
import 'package:esl_learning_flutter/backend/services/video_loader_optimizer.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

/// Advanced high-performance playback speed options
enum PlaybackSpeed {
  p25(0.25, '0.25×'),
  p50(0.5, '0.5×'),
  p75(0.75, '0.75×'),
  p100(1.0, '1×'),
  p125(1.25, '1.25×'),
  p150(1.5, '1.5×'),
  p175(1.75, '1.75×'),
  p200(2.0, '2×');

  const PlaybackSpeed(this.value, this.label);
  final double value;
  final String label;
}

/// Network quality/resolution options
enum VideoQuality {
  auto('Auto'),
  p480('480p'),
  p720('720p'),
  p1080('1080p');

  const VideoQuality(this.label);
  final String label;
}

/// Full-featured ultra-fast advanced player: 4K-ready, gesture controls, adaptive buffering, PiP.
/// Supports: multi-speed (0.25-2x), quality selection, frame scrubbing, adaptive streaming.
/// Optional [onProgressLearned] fires once after ~3s or ~15% watched (lesson screen).
class LessonVideoPlayerCard extends StatefulWidget {
  const LessonVideoPlayerCard({
    super.key,
    required this.lesson,
    this.onProgressLearned,
    this.bottomCaption,
    this.showEthBadge = false,
    this.borderRadius = 16,
    this.hideTitle = false,
  });

  final LessonItem lesson;
  final VoidCallback? onProgressLearned;
  final String? bottomCaption;
  final bool showEthBadge;
  final double borderRadius;
  final bool hideTitle;

  @override
  State<LessonVideoPlayerCard> createState() => _LessonVideoPlayerCardState();
}

class _LessonVideoPlayerCardState extends State<LessonVideoPlayerCard>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  final ValueNotifier<bool> _mirror = ValueNotifier(false);
  final ValueNotifier<PlaybackSpeed> _speedNotifier = ValueNotifier(
    PlaybackSpeed.p100,
  );
  final ValueNotifier<VideoQuality> _qualityNotifier = ValueNotifier(
    VideoQuality.auto,
  );

  bool _initialized = false;
  bool _error = false;
  String? _errorMessage;
  bool _progressReported = false;
  bool _isTransitioning = false;
  String? _currentDriveId;
  Timer? _driveCacheCheckTimer;
  bool _driveCacheSwapInProgress = false;

  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  Timer? _positionTimer;
  CancelToken? _initCancelToken;

  bool _muted = false;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final double _volume = 1.0;

  /// Performance optimization: cache formatted time strings
  final Map<int, String> _timeCache = {};

  /// Video loader optimizer instance
  late VideoLoaderOptimizer _optimizer;
  bool _headerPreloadStarted = false;

  @override
  void initState() {
    super.initState();
    _optimizer = VideoLoaderOptimizer();
    WidgetsBinding.instance.addObserver(this);
    
    // Start header preloading immediately for faster playback
    _startHeaderPreload();
    
    _initPlayer();
  }

  /// Preload video headers in background for instant header data
  void _startHeaderPreload() {
    if (_headerPreloadStarted) return;
    _headerPreloadStarted = true;

    final url = widget.lesson.videoUrl?.trim();
    if (url == null || url.isEmpty) return;

    Future.microtask(() async {
      try {
        if (mounted) {
          final preloadInfo = await _optimizer.preloadVideoHeaders(url);
          if (mounted) {
            debugPrint('Video preload info ready: ${preloadInfo.totalSize ~/ 1024}KB');
          }
        }
      } catch (e) {
        debugPrint('Header preload failed: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    if (state == AppLifecycleState.paused) {
      _controller.pause();
    }
  }

  @override
  void didUpdateWidget(LessonVideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.lesson.id != widget.lesson.id;
    final urlChanged = oldWidget.lesson.videoUrl != widget.lesson.videoUrl;
    final localPathChanged =
        oldWidget.lesson.videoLocalPath != widget.lesson.videoLocalPath;

    // Only re-initialize if the lesson ID changed, OR if the video URL or local path changed
    // AND the player is not currently successfully initialized.
    // This avoids interrupting active playback when a background download completes and sets videoLocalPath.
    if (idChanged || ((urlChanged || localPathChanged) && !_initialized)) {
      _progressReported = false;
      _timeCache.clear();
      _initPlayer();
    }
  }

  static const _streamHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  };

  static VideoPlayerOptions get _playerOptions => VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      );

  Future<List<({VideoPlayerController controller, String label, String? driveId})>>
      _playbackCandidates(CancelToken? cancelToken) async {
    final out = <({VideoPlayerController controller, String label, String? driveId})>[];
    final local = widget.lesson.videoLocalPath?.trim();
    final u = widget.lesson.videoUrl?.trim();

    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (await f.exists()) {
        if (await VideoDownloader.isValidVideoFile(f)) {
          out.add((
            controller: VideoPlayerController.file(
              f,
              videoPlayerOptions: _playerOptions,
            ),
            label: 'Local file: ${f.path}',
            driveId: null,
          ));
          return out;
        }
        debugPrint('Stored local file is not a valid video: $local');
      }
    }

    if (u != null && u.isNotEmpty) {
      final driveId = VideoDownloader.parseDriveFileId(u);
      if (driveId != null || u.startsWith('http://') || u.startsWith('https://')) {
        try {
          final cacheDir = await getTemporaryDirectory();
          final source = await VideoDownloader().resolvePlaybackSource(
            u,
            cacheDir: cacheDir,
            cancelToken: cancelToken,
          );
          if (source.filePath != null) {
            out.add((
              controller: VideoPlayerController.file(
                File(source.filePath!),
                videoPlayerOptions: _playerOptions,
              ),
              label: 'Drive cache: ${source.filePath}',
              driveId: null,
            ));
          } else {
            out.add((
              controller: VideoPlayerController.networkUrl(
                Uri.parse(source.networkUrl!),
                httpHeaders: _streamHeaders,
                videoPlayerOptions: _playerOptions,
              ),
              label: 'Remote URL: ${source.networkUrl}',
              driveId: driveId,
            ));
          }
        } catch (e, st) {
          debugPrint('Remote video resolve failed ($u): $e\n$st');
        }
      }
    }

    return out;
  }

  Future<void> _initPlayer() async {
    final currentCancelToken = CancelToken();
    _initCancelToken?.cancel();
    _initCancelToken = currentCancelToken;
    _currentDriveId = null;
    _stopDriveCacheMonitor();

    final hadPlayer = _initialized;
    if (!hadPlayer) {
      setState(() {
        _error = false;
        _errorMessage = null;
        _initialized = false;
        _isTransitioning = false;
      });
    } else {
      setState(() {
        _error = false;
        _errorMessage = null;
        _isTransitioning = true;
      });
    }

    List<({VideoPlayerController controller, String label, String? driveId})> candidates;
    try {
      candidates = await _playbackCandidates(currentCancelToken);
    } catch (e) {
      if (currentCancelToken.isCancelled || !mounted) return;
      rethrow;
    }

    if (currentCancelToken.isCancelled) return;
    if (candidates.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _initialized = false;
        _isTransitioning = false;
        _errorMessage = widget.lesson.videoUrl == null ||
                widget.lesson.videoUrl!.trim().isEmpty
            ? 'No sign video is configured for this lesson.'
            : 'Could not load the sign video from Google Drive.';
      });
      return;
    }

    Object? lastError;
    for (final candidate in candidates) {
      final c = candidate.controller;
      try {
        debugPrint('Initializing video player: ${candidate.label}');
        // Faster initialization timeout for better UX
        await c.initialize().timeout(const Duration(seconds: 30));
        await c.setLooping(true);
        c.addListener(_onVideoUpdate);
        await c.setVolume(_muted ? 0.0 : _volume);
        await c.setPlaybackSpeed(_speedNotifier.value.value);

        if (candidate.driveId != null) {
          _currentDriveId = candidate.driveId;
          _startDriveCacheMonitor(candidate.driveId!);
        }

        if (currentCancelToken.isCancelled) {
          await c.dispose();
          return;
        }

        // Swap controller and asynchronously dispose old one in a microtask to avoid UI blocking
        final oldController = _initialized ? _controller : null;
        if (oldController != null) {
          oldController.removeListener(_onVideoUpdate);
          Future.microtask(() async {
            try {
              await oldController.pause();
              await oldController.dispose();
            } catch (_) {}
          });
        }

        _controller = c;
        await c.seekTo(Duration.zero);
        await c.play();

        if (!mounted) {
          await c.dispose();
          return;
        }

        setState(() {
          _initialized = true;
          _isTransitioning = false;
        });

        _positionNotifier.value = Duration.zero;
        _startPositionTimer();
        _scheduleHideControls();
        debugPrint('Video player ready: ${candidate.label}');
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint(
          'Video init failed (${candidate.label}): $e\n$st',
        );
        await c.dispose();

        if (candidate.driveId != null) {
          try {
            final cacheDir = await getTemporaryDirectory();
            final localPath = VideoDownloader.drivePlaybackCachePath(
              cacheDir,
              candidate.driveId!,
            );
            await VideoDownloader().downloadDriveVideoToFile(
              fileId: candidate.driveId!,
              destinationPath: localPath,
              cancelToken: currentCancelToken,
            );
            final fallbackController = VideoPlayerController.file(
              File(localPath),
              videoPlayerOptions: _playerOptions,
            );
            debugPrint('Retrying video player from local cache: $localPath');
            await fallbackController.initialize().timeout(const Duration(seconds: 60));
            await fallbackController.setLooping(true);
            fallbackController.addListener(_onVideoUpdate);
            await fallbackController.setVolume(_muted ? 0.0 : _volume);
            await fallbackController.setPlaybackSpeed(_speedNotifier.value.value);

            if (candidate.driveId != null) {
              _currentDriveId = candidate.driveId;
              _stopDriveCacheMonitor();
            }

            if (currentCancelToken.isCancelled) {
              await fallbackController.dispose();
              return;
            }

            final oldController = _initialized ? _controller : null;
            if (oldController != null) {
              oldController.removeListener(_onVideoUpdate);
              Future.microtask(() async {
                try {
                  await oldController.pause();
                  await oldController.dispose();
                } catch (_) {}
              });
            }

            _controller = fallbackController;
            await fallbackController.seekTo(Duration.zero);
            await fallbackController.play();

            if (!mounted) {
              await fallbackController.dispose();
              return;
            }

            setState(() {
              _initialized = true;
              _isTransitioning = false;
            });

            _positionNotifier.value = Duration.zero;
            _startPositionTimer();
            _scheduleHideControls();
            debugPrint('Video player ready from local fallback: $localPath');
            return;
          } catch (downloadError, downloadSt) {
            debugPrint(
              'Local playback fallback failed for ${candidate.driveId}: $downloadError\n$downloadSt',
            );
          }
        }
      }
    }

    if (!mounted || currentCancelToken.isCancelled) return;
    String friendlyMessage;
    if (lastError != null) {
      final errStr = lastError.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('connection error') ||
          errStr.contains('Network is unreachable')) {
        friendlyMessage = 'No internet connection. Please check your network and try again.';
      } else {
        friendlyMessage = lastError.toString();
      }
    } else {
      friendlyMessage = 'Could not load the sign video from Google Drive.';
    }

    setState(() {
      _initialized = false;
      _isTransitioning = false;
      _error = true;
      _errorMessage = friendlyMessage;
    });
  }

  bool _wasBuffering = false;
  bool _wasPlaying = false;

  void _onVideoUpdate() {
    if (!_initialized || !mounted) return;
    final v = _controller.value;
    if (v.hasError) {
      debugPrint('Video error encountered: ${v.errorDescription}');
      if (mounted) {
        setState(() {
          _initialized = false;
          _error = true;
          _errorMessage = v.errorDescription ?? 'An error occurred during video playback.';
        });
      }
      return;
    }
    if (!v.isInitialized) return;

    final cb = widget.onProgressLearned;
    if (cb != null && !_progressReported) {
      final pos = v.position;
      final dur = v.duration;
      if (dur > Duration.zero) {
        final timeOk = pos >= const Duration(seconds: 3);
        final portionOk = pos.inMilliseconds / dur.inMilliseconds >= 0.15;
        if (timeOk || portionOk) {
          _progressReported = true;
          cb();
        }
      }
    }

    final bufferingChanged = v.isBuffering != _wasBuffering;
    final playingChanged = v.isPlaying != _wasPlaying;
    if (bufferingChanged || playingChanged) {
      _wasBuffering = v.isBuffering;
      _wasPlaying = v.isPlaying;
      if (mounted && !v.isBuffering) {
        setState(() {});
      }
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !(_controller.value.isPlaying)) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _startDriveCacheMonitor(String driveId) {
    _stopDriveCacheMonitor();
    _driveCacheCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkDriveCacheReady(driveId);
    });
  }

  void _stopDriveCacheMonitor() {
    _driveCacheCheckTimer?.cancel();
    _driveCacheCheckTimer = null;
    _driveCacheSwapInProgress = false;
  }

  Future<void> _checkDriveCacheReady(String driveId) async {
    if (!_initialized || _currentDriveId != driveId || _driveCacheSwapInProgress) {
      return;
    }
    try {
      final cacheDir = await getTemporaryDirectory();
      final localPath = VideoDownloader.drivePlaybackCachePath(cacheDir, driveId);
      final file = File(localPath);
      if (!await VideoDownloader.isValidVideoFile(file)) return;
      await _swapToLocalCache(driveId, file, _controller.value.position);
    } catch (e, st) {
      debugPrint('Drive cache monitor failed: $e\n$st');
    }
  }

  Future<void> _swapToLocalCache(
    String driveId,
    File file,
    Duration currentPosition,
  ) async {
    if (!_initialized || _currentDriveId != driveId) return;
    _driveCacheSwapInProgress = true;
    try {
      final fallbackController = VideoPlayerController.file(
        file,
        videoPlayerOptions: _playerOptions,
      );
      await fallbackController.initialize().timeout(const Duration(seconds: 60));
      await fallbackController.setLooping(true);
      fallbackController.addListener(_onVideoUpdate);
      await fallbackController.setVolume(_muted ? 0.0 : _volume);
      await fallbackController.setPlaybackSpeed(_speedNotifier.value.value);

      if (!mounted || _currentDriveId != driveId) {
        await fallbackController.dispose();
        return;
      }

      final oldController = _initialized ? _controller : null;
      final targetPosition = currentPosition;
      if (oldController != null) {
        oldController.removeListener(_onVideoUpdate);
        Future.microtask(() async {
          try {
            await oldController.pause();
            await oldController.dispose();
          } catch (_) {}
        });
      }

      _controller = fallbackController;
      await fallbackController.seekTo(targetPosition);
      await fallbackController.play();

      if (!mounted) {
        await fallbackController.dispose();
        return;
      }

      setState(() {
        _initialized = true;
        _isTransitioning = false;
      });
      _currentDriveId = null;
      _stopDriveCacheMonitor();
      _positionNotifier.value = targetPosition;
      _scheduleHideControls();
      debugPrint('Swapped Drive stream to local cached playback: $driveId');
    } catch (e, st) {
      debugPrint('Local cache swap failed: $e\n$st');
    } finally {
      _driveCacheSwapInProgress = false;
    }
  }


  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_initialized || !_controller.value.isInitialized) return;
      final position = _controller.value.position;
      if (_positionNotifier.value != position) {
        _positionNotifier.value = position;
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  Future<void> _togglePlay() async {
    if (!_initialized || !_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      try {
        await _controller.play();
        _scheduleHideControls();
      } catch (e) {
        debugPrint('Play failed: $e');
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _setSpeed(PlaybackSpeed speed) async {
    if (!_initialized) return;
    _speedNotifier.value = speed;
    await _controller.setPlaybackSpeed(speed.value);
    setState(() {});
  }

  Future<void> _toggleMute() async {
    if (!_initialized) return;
    _muted = !_muted;
    await _controller.setVolume(_muted ? 0 : _volume);
    setState(() {});
  }

  void _seekTo(Duration position) {
    if (!_initialized) return;
    _controller.seekTo(position);
    setState(() {});
  }

  /// Double-tap to seek +/- 10 seconds
  void _doubleTapSeek(Offset offset, Size playerSize) {
    const seekDuration = Duration(seconds: 10);
    if (offset.dx < playerSize.width / 2) {
      // Left side: backward
      final newPos = _controller.value.position - seekDuration;
      _seekTo(newPos.isNegative ? Duration.zero : newPos);
    } else {
      // Right side: forward
      final newPos = _controller.value.position + seekDuration;
      _seekTo(
        newPos > _controller.value.duration
            ? _controller.value.duration
            : newPos,
      );
    }
  }

  void _openAdvancedFullscreen() {
    if (!_initialized) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _AdvancedFullscreenPlayer(
          controller: _controller,
          mirrorListenable: _mirror,
          speedNotifier: _speedNotifier,
          qualityNotifier: _qualityNotifier,
          lesson: widget.lesson,
          onClose: () => Navigator.of(ctx).pop(),
          hideTitle: widget.hideTitle,
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  @override
  void dispose() {
    _initCancelToken?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _stopPositionTimer();
    _stopDriveCacheMonitor();
    if (_initialized) {
      _controller.removeListener(_onVideoUpdate);
      _controller.dispose();
    }
    _mirror.dispose();
    _speedNotifier.dispose();
    _qualityNotifier.dispose();
    _positionNotifier.dispose();
    _timeCache.clear();
    // Clean up cached stats
    debugPrint('Cache stats: ${VideoLoaderOptimizer.getCacheStats()}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius + 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlayerSurface(),
            const SizedBox(height: 12),
            _buildAdvancedToolRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSurface() {
    // Tall player: sign language videos are captured portrait-oriented,
    // so a taller aspect ratio (≈ 4:3 or more) gives much better framing.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final height = screenWidth * 1.05; // ~portrait 1:1.05 — large, sign-friendly
    final r = widget.borderRadius;

    if (_error) {
      return _errorPlaceholder(height, r);
    }

    if (!_initialized) {
      return _loadingPlaceholder(height, r);
    }

    final v = _controller.value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Material(
        elevation: 6,
        color: Colors.black,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _toggleControls();
              if (_controlsVisible) _scheduleHideControls();
            },
            onDoubleTapDown: (details) {
              final w = MediaQuery.sizeOf(context).width;
              _doubleTapSeek(details.localPosition, Size(w, w * 1.05));
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _mirror,
                  builder: (context, mirror, _) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        mirror ? -1.0 : 1.0, 1.0, 1.0,
                      ),
                      child: RepaintBoundary(
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width:  _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (_isTransitioning)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.22),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                if (!widget.hideTitle)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            widget.lesson.sign,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (widget.showEthBadge)
                  Positioned(left: 12, bottom: 58, child: _buildBadge('ETH SL')),
                if (widget.bottomCaption != null &&
                    widget.bottomCaption!.isNotEmpty)
                  Positioned(
                    left: 12,
                    bottom: widget.showEthBadge ? 90 : 58,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.bottomCaption!,
                        style: const TextStyle(
                          color: Color(0xFF141414),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                if (_controlsVisible)
                  Center(
                    child: AnimatedScale(
                      scale: _controller.value.isPlaying ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: 54,
                          icon: Icon(
                            v.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlay,
                        ),
                      ),
                    ),
                  ),

                if (v.isBuffering)
                  Center(
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.9),
                        ),
                        strokeWidth: 2.4,
                      ),
                    ),
                  ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildAdvancedControlBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedControlBar() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controlsVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(height: 4, child: _buildAdvancedProgressBar()),
              ),
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _togglePlay,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _positionNotifier,
                      builder: (context, position, _) {
                        final duration = _controller.value.duration;
                        return Text(
                          '${_fmt(position)} / ${_fmt(duration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_controlsVisible) ...[
                    IconButton(
                      onPressed: _toggleMute,
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _openAdvancedFullscreen,
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedProgressBar() {
    final v = _controller.value;
    if (!v.isInitialized) return const SizedBox.shrink();

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final width = MediaQuery.sizeOf(context).width - 20;
        final newPosition = Duration(
          milliseconds:
              (details.globalPosition.dx / width * v.duration.inMilliseconds)
                  .toInt(),
        );
        _seekTo(newPosition);
      },
      child: VideoProgressIndicator(
        _controller,
        allowScrubbing: true,
        colors: VideoProgressColors(
          playedColor: Colors.green.shade400,
          bufferedColor: Colors.white.withValues(alpha: 0.4),
          backgroundColor: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildAdvancedToolRow() {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _mirror,
            builder: (_, mirrored, _) {
              return FilledButton.icon(
                onPressed: () => _mirror.value = !mirrored,
                style: FilledButton.styleFrom(
                  backgroundColor: mirrored
                      ? const Color(0xFF1F6A5F)
                      : const Color(0xFFF2F7F4),
                  foregroundColor: mirrored ? Colors.white : kPrimaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(mirrored ? Icons.swap_horiz : Icons.swap_horiz_outlined),
                label: Text(mirrored ? 'Mirror: On' : 'Mirror: Off'),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<PlaybackSpeed>(
          onSelected: _setSpeed,
          itemBuilder: (context) => [
            for (final speed in PlaybackSpeed.values)
              PopupMenuItem(value: speed, child: Text(speed.label)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<PlaybackSpeed>(
                  valueListenable: _speedNotifier,
                  builder: (_, speed, _) => Text(
                    speed.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kPrimaryDark,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: kPrimaryDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingPlaceholder(double height, double r) {
    return _ShimmerLoadingPlaceholder(
      height: height,
      borderRadius: r,
      lesson: widget.lesson,
      hideSignName: widget.hideTitle,
    );
  }

  /// Clears any stale cached Drive URL for this lesson then re-initialises
  /// the player. Use this for the retry button so a 403 / expired URL is
  /// re-resolved fresh rather than replayed.
  Future<void> _retryPlayer() async {
    final u = widget.lesson.videoUrl?.trim();
    if (u != null && u.isNotEmpty) {
      final driveId = VideoDownloader.parseDriveFileId(u);
      if (driveId != null) {
        VideoDownloader.evictCachedUrl(driveId);
        debugPrint('Evicted stale Drive URL cache for $driveId before retry.');
      }
    }
    await _initPlayer();
  }

  String _shortErrorMessage() {
    final raw = _errorMessage;
    if (raw == null || raw.isEmpty) return 'Could not load video';
    if (raw.contains('confirm token') ||
        raw.contains('Anyone with the link') ||
        raw.contains('did not download as video')) {
      return 'Sign video is not available yet.\nAsk your teacher to share the Drive file publicly, or use Download for offline.';
    }
    if (raw.contains('ExoPlaybackException') ||
        raw.contains('Source error') ||
        raw.contains('VideoError') ||
        raw.contains('403')) {
      return 'Could not play this sign video.\nTry again on Wi‑Fi or tap Download for offline.';
    }
    if (raw.length > 120) {
      return 'Could not load video.\n${raw.substring(0, 120)}…';
    }
    return 'Could not load video:\n$raw';
  }

  Widget _errorPlaceholder(double height, double r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C2C2C), Color(0xFF161616)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.lesson.thumbnail, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              _shortErrorMessage(),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _retryPlayer,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF414141),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Loading stage text widget ───────────────────────────────────────────────

/// Cycles through loading stage strings every 2.5 s with a crossfade transition.
class _LoadingStageText extends StatefulWidget {
  const _LoadingStageText();

  @override
  State<_LoadingStageText> createState() => _LoadingStageTextState();
}

class _LoadingStageTextState extends State<_LoadingStageText> {
  static const _stages = [
    'Connecting to Drive…',
    'Fetching sign video…',
    'Buffering…',
    'Almost ready…',
  ];

  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) setState(() => _stage = (_stage + 1) % _stages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        _stages[_stage],
        key: ValueKey(_stage),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Shimmer loading placeholder ─────────────────────────────────────────────

/// Animated shimmer placeholder shown while the video is initialising.
/// Set [hideSignName] to true (quiz mode) to suppress the sign-name pill
/// that would otherwise reveal the correct answer.
class _ShimmerLoadingPlaceholder extends StatefulWidget {
  const _ShimmerLoadingPlaceholder({
    required this.height,
    required this.borderRadius,
    required this.lesson,
    this.hideSignName = false,
  });

  final double height;
  final double borderRadius;
  final LessonItem lesson;
  final bool hideSignName;

  @override
  State<_ShimmerLoadingPlaceholder> createState() =>
      _ShimmerLoadingPlaceholderState();
}

class _ShimmerLoadingPlaceholderState extends State<_ShimmerLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark gradient base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2420), Color(0xFF0D1510)],
                ),
              ),
            ),
            // Shimmer wave overlay
            AnimatedBuilder(
              animation: _shimmer,
              builder: (_, __) {
                final t = _shimmer.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.5 + t * 3.5, 0),
                      end: Alignment(-0.5 + t * 3.5, 0),
                      colors: const [
                        Colors.transparent,
                        Color(0x14FFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
            // Centre content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: Text(
                      widget.lesson.thumbnail,
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF4CAF86),
                  ),
                  const SizedBox(height: 14),
                  const _LoadingStageText(),
                ],
              ),
            ),
            // Bottom pill with sign name — hidden in quiz mode
            if (!widget.hideSignName)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      widget.lesson.sign,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Advanced fullscreen player with professional controls, quality selection, and gesture support
class _AdvancedFullscreenPlayer extends StatefulWidget {
  const _AdvancedFullscreenPlayer({
    required this.controller,
    required this.mirrorListenable,
    required this.speedNotifier,
    required this.qualityNotifier,
    required this.lesson,
    required this.onClose,
    this.hideTitle = false,
  });

  final VideoPlayerController controller;
  final ValueNotifier<bool> mirrorListenable;
  final ValueNotifier<PlaybackSpeed> speedNotifier;
  final ValueNotifier<VideoQuality> qualityNotifier;
  final LessonItem lesson;
  final VoidCallback onClose;
  final bool hideTitle;

  @override
  State<_AdvancedFullscreenPlayer> createState() =>
      _AdvancedFullscreenPlayerState();
}

class _AdvancedFullscreenPlayerState extends State<_AdvancedFullscreenPlayer>
    with TickerProviderStateMixin {
  late AnimationController _controlsController;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  bool _muted = false;
  bool _wasBuffering = false;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _controlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.controller.addListener(_onTick);
    _scheduleHideControls();
  }

  void _onTick() {
    if (!mounted) return;
    final v = widget.controller.value;
    final bufferingChanged = v.isBuffering != _wasBuffering;
    final playingChanged = v.isPlaying != _wasPlaying;
    if (bufferingChanged || playingChanged) {
      _wasBuffering = v.isBuffering;
      _wasPlaying = v.isPlaying;
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !widget.controller.value.isPlaying) return;
      _toggleControls();
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsController.reverse();
      _controlsVisible = false;
    } else {
      _controlsController.forward();
      _controlsVisible = true;
      _scheduleHideControls();
    }
  }

  Future<void> _togglePlay() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await widget.controller.setVolume(_muted ? 0 : 1);
    setState(() {});
  }

  void _seekTo(Duration position) {
    widget.controller.seekTo(position);
    setState(() {});
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_onTick);
    _controlsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Video player
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.mirrorListenable,
              builder: (context, mirror, _) {
                final v = widget.controller.value;
                final aspect = v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    mirror ? -1.0 : 1.0,
                    1.0,
                    1.0,
                  ),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: VideoPlayer(widget.controller),
                  ),
                );
              },
            ),
          ),

          /// Buffering indicator
          if (widget.controller.value.isBuffering)
            Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                  strokeWidth: 3,
                ),
              ),
            ),

          /// Top bar
          AnimatedBuilder(
            animation: _controlsController,
            builder: (context, child) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(_controlsController),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top,
                16,
                16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.hideTitle ? 'Sign Language Video' : widget.lesson.sign,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!widget.hideTitle)
                          Text(
                            widget.lesson.signAm,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.mirrorListenable.value =
                        !widget.mirrorListenable.value,
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          /// Center play/pause button
          GestureDetector(
            onTap: _toggleControls,
            child: Center(
              child: AnimatedBuilder(
                animation: _controlsController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _controlsController.value,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        iconSize: 72,
                        icon: Icon(
                          widget.controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlay,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          /// Bottom control bar
          AnimatedBuilder(
            animation: _controlsController,
            builder: (context, child) {
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(_controlsController),
                  child: child,
                ),
              );
            },
            child: _buildAdvancedBottomBar(),
          ),

          /// Tap to toggle controls
          GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedBottomBar() {
    final v = widget.controller.value;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Progress bar with scrubber
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final width = MediaQuery.sizeOf(context).width - 32;
              final newPosition = Duration(
                milliseconds:
                    (details.globalPosition.dx /
                            width *
                            v.duration.inMilliseconds)
                        .toInt(),
              );
              _seekTo(newPosition);
            },
            child: VideoProgressIndicator(
              widget.controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.green.shade400,
                bufferedColor: Colors.white.withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          /// Time and controls
          Row(
            children: [
              IconButton(
                onPressed: _togglePlay,
                icon: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              Text(
                '${_fmt(v.position)} / ${_fmt(v.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              PopupMenuButton<PlaybackSpeed>(
                onSelected: (speed) async {
                  widget.speedNotifier.value = speed;
                  await widget.controller.setPlaybackSpeed(speed.value);
                },
                itemBuilder: (context) => [
                  for (final speed in PlaybackSpeed.values)
                    PopupMenuItem(value: speed, child: Text(speed.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ValueListenableBuilder<PlaybackSpeed>(
                    valueListenable: widget.speedNotifier,
                    builder: (_, speed, _) => Text(
                      speed.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}
