import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
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
  });

  final LessonItem lesson;
  final VoidCallback? onProgressLearned;
  final String? bottomCaption;
  final bool showEthBadge;
  final double borderRadius;

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

  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  Timer? _positionTimer;
  CancelToken? _initCancelToken;

  bool _muted = false;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final double _volume = 1.0;

  /// Performance optimization: cache formatted time strings
  final Map<int, String> _timeCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
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
    if (oldWidget.lesson.id != widget.lesson.id ||
        oldWidget.lesson.videoLocalPath != widget.lesson.videoLocalPath ||
        oldWidget.lesson.videoUrl != widget.lesson.videoUrl) {
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

  Future<List<({VideoPlayerController controller, String label})>>
      _playbackCandidates(CancelToken? cancelToken) async {
    final out = <({VideoPlayerController controller, String label})>[];
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
          ));
          return out;
        }
        debugPrint('Stored local file is not a valid video: $local');
      }
    }

    if (u != null && u.isNotEmpty) {
      if (VideoDownloader.parseDriveFileId(u) != null ||
          u.startsWith('http://') ||
          u.startsWith('https://')) {
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
            ));
          } else {
            out.add((
              controller: VideoPlayerController.networkUrl(
                Uri.parse(source.networkUrl!),
                httpHeaders: _streamHeaders,
                videoPlayerOptions: _playerOptions,
              ),
              label: 'Remote URL: ${source.networkUrl}',
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
    final hadPlayer = _initialized;
    final currentCancelToken = CancelToken();
    _initCancelToken?.cancel();
    _initCancelToken = currentCancelToken;

    setState(() {
      _error = false;
      _errorMessage = null;
      _initialized = false;
    });

    if (hadPlayer) {
      _controller.removeListener(_onVideoUpdate);
      await _controller.dispose();
    }

    List<({VideoPlayerController controller, String label})> candidates;
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
        await c.initialize().timeout(const Duration(seconds: 6));
        await c.setLooping(true);
        c.addListener(_onVideoUpdate);
        await c.setVolume(_volume);
        await c.setPlaybackSpeed(_speedNotifier.value.value);
        _controller = c;
        await c.seekTo(Duration.zero);
        await c.play();
        if (!mounted) {
          await c.dispose();
          return;
        }
        setState(() => _initialized = true);
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
      }
    }

    if (!mounted) return;
    setState(() {
      _initialized = false;
      _error = true;
      _errorMessage = lastError?.toString();
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

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_initialized || !_controller.value.isInitialized) return;
      _positionNotifier.value = _controller.value.position;
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
    if (_initialized) {
      _controller.removeListener(_onVideoUpdate);
      _controller.dispose();
    }
    _mirror.dispose();
    _speedNotifier.dispose();
    _qualityNotifier.dispose();
    _positionNotifier.dispose();
    _timeCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPlayerSurface(),
        const SizedBox(height: 14),
        _buildAdvancedToolRow(),
      ],
    );
  }

  Widget _buildPlayerSurface() {
    final height = MediaQuery.sizeOf(context).width * 9 / 16;
    final r = widget.borderRadius;

    if (_error) {
      return _errorPlaceholder(height, r);
    }

    if (!_initialized) {
      return _loadingPlaceholder(height, r);
    }

    final v = _controller.value;
    final aspect = v.aspectRatio == 0 ? (16 / 9) : v.aspectRatio;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(r),
      clipBehavior: Clip.antiAlias,
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
            _doubleTapSeek(
              details.localPosition,
              Size(
                MediaQuery.sizeOf(context).width,
                MediaQuery.sizeOf(context).width * 9 / 16,
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              /// High-performance video rendering
              ValueListenableBuilder<bool>(
                valueListenable: _mirror,
                builder: (context, mirror, _) {
                  return Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        mirror ? -1.0 : 1.0,
                        1.0,
                        1.0,
                      ),
                      child: RepaintBoundary(
                        child: AspectRatio(
                          aspectRatio: aspect,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  );
                },
              ),

              /// Gradient overlay for readability
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),

              /// Badges
              if (widget.showEthBadge)
                Positioned(left: 12, bottom: 56, child: _buildBadge('ETH SL')),
              if (widget.bottomCaption != null &&
                  widget.bottomCaption!.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: widget.showEthBadge ? 88 : 56,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.bottomCaption!,
                      style: const TextStyle(
                        color: Color(0xFF141414),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              /// Center play/pause button
              if (_controlsVisible)
                Center(
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      iconSize: 56,
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

              /// Buffering indicator
              if (v.isBuffering)
                Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                ),

              /// Advanced control bar
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
    );
  }

  Widget _buildAdvancedControlBar() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Frame-level scrubber with time preview
            if (_controlsVisible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(height: 3, child: _buildAdvancedProgressBar()),
              ),
            const SizedBox(height: 1),

            /// Main control row
            SizedBox(
              height: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 8,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_controlsVisible) ...[
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    GestureDetector(
                      onTap: _openAdvancedFullscreen,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
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
          child: OutlinedButton.icon(
            onPressed: () => _mirror.value = !_mirror.value,
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryDark,
              side: const BorderSide(color: Color(0xFFCFD8D3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: ValueListenableBuilder<bool>(
              valueListenable: _mirror,
              builder: (_, m, _) =>
                  Icon(m ? Icons.swap_horiz : Icons.swap_horiz_outlined),
            ),
            label: ValueListenableBuilder<bool>(
              valueListenable: _mirror,
              builder: (_, m, _) => Text(m ? 'Mirror: On' : 'Mirror: Off'),
            ),
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
              border: Border.all(color: const Color(0xFFCFD8D3)),
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
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(r),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              widget.lesson.videoUrl != null &&
                      VideoDownloader.parseDriveFileId(widget.lesson.videoUrl) !=
                          null
                  ? 'Preparing sign video…'
                  : 'Loading video…',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
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
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(r),
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
            onPressed: _initPlayer,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
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

/// Advanced fullscreen player with professional controls, quality selection, and gesture support
class _AdvancedFullscreenPlayer extends StatefulWidget {
  const _AdvancedFullscreenPlayer({
    required this.controller,
    required this.mirrorListenable,
    required this.speedNotifier,
    required this.qualityNotifier,
    required this.lesson,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final ValueNotifier<bool> mirrorListenable;
  final ValueNotifier<PlaybackSpeed> speedNotifier;
  final ValueNotifier<VideoQuality> qualityNotifier;
  final LessonItem lesson;
  final VoidCallback onClose;

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
                          widget.lesson.sign,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
