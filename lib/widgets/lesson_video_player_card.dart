import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

/// Sample HTTPS streams when a lesson has no DB [LessonItem.videoUrl] / local file.
Uri sampleStreamUriForLesson(LessonItem lesson) {
  const samples = <String>[
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
  ];
  return Uri.parse(samples[lesson.id.hashCode.abs() % samples.length]);
}

/// Full-featured inline player: mirror, speed, scrub, mute, fullscreen.
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

class _LessonVideoPlayerCardState extends State<LessonVideoPlayerCard> {
  VideoPlayerController? _controller;
  final ValueNotifier<bool> _mirror = ValueNotifier(false);

  bool _initialized = false;
  bool _error = false;
  bool _progressReported = false;

  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  double _speed = 1.0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(LessonVideoPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id ||
        oldWidget.lesson.videoLocalPath != widget.lesson.videoLocalPath ||
        oldWidget.lesson.videoUrl != widget.lesson.videoUrl) {
      _progressReported = false;
      _initPlayer();
    }
  }

  VideoPlayerController _controllerForRemoteOrSample() {
    final u = widget.lesson.videoUrl?.trim();
    if (u != null &&
        u.isNotEmpty &&
        (u.startsWith('http://') || u.startsWith('https://'))) {
      return VideoPlayerController.networkUrl(Uri.parse(u));
    }
    return VideoPlayerController.networkUrl(
      sampleStreamUriForLesson(widget.lesson),
    );
  }

  Future<void> _initPlayer() async {
    setState(() {
      _error = false;
      _initialized = false;
    });
    VideoPlayerController c;
    final local = widget.lesson.videoLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (await f.exists()) {
        c = VideoPlayerController.file(f);
      } else {
        c = _controllerForRemoteOrSample();
      }
    } else {
      c = _controllerForRemoteOrSample();
    }
    _controller?.removeListener(_onVideoUpdate);
    await _controller?.dispose();
    _controller = null;
    try {
      await c.initialize();
      await c.setLooping(true);
      c.addListener(_onVideoUpdate);
      await c.setVolume(_muted ? 0 : 1);
      await c.setPlaybackSpeed(_speed);
      _controller = c;
      await c.play();
      if (!mounted) return;
      setState(() => _initialized = true);
      _scheduleHideControls();
    } catch (_) {
      await c.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _error = true;
      });
    }
  }

  void _onVideoUpdate() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      if (mounted) setState(() {});
      return;
    }
    final cb = widget.onProgressLearned;
    if (cb != null && !_progressReported) {
      final pos = c.value.position;
      final dur = c.value.duration;
      if (dur > Duration.zero) {
        final timeOk = pos >= const Duration(seconds: 3);
        final portionOk = pos.inMilliseconds / dur.inMilliseconds >= 0.15;
        if (timeOk || portionOk) {
          _progressReported = true;
          cb();
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (!_controlsVisible) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !(_controller?.value.isPlaying ?? false)) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  Future<void> _setSpeed(double s) async {
    _speed = s;
    await _controller?.setPlaybackSpeed(s);
    setState(() {});
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _controller?.setVolume(_muted ? 0 : 1);
    setState(() {});
  }

  void _openFullscreen() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => _FullscreenLessonPlayer(
          controller: c,
          mirrorListenable: _mirror,
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
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _mirror.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPlayerSurface(),
        const SizedBox(height: 14),
        _buildToolRow(),
      ],
    );
  }

  Widget _buildPlayerSurface() {
    final height = MediaQuery.sizeOf(context).width * 9 / 16;
    final r = widget.borderRadius;

    if (_error) {
      return _errorPlaceholder(height, r);
    }

    if (!_initialized || _controller == null) {
      return _loadingPlaceholder(height, r);
    }

    final c = _controller!;
    final v = c.value;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
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
                      child: AspectRatio(
                        aspectRatio: aspect,
                        child: VideoPlayer(c),
                      ),
                    ),
                  );
                },
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
              if (widget.showEthBadge)
                Positioned(
                  left: 12,
                  bottom: 56,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF414141),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ETH SL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0.35,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF4CAF50),
                            bufferedColor: Color(0x66FFFFFF),
                            backgroundColor: Color(0x33FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                v.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            Text(
                              '${_fmt(v.position)} / ${_fmt(v.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            IconButton(
                              onPressed: _openFullscreen,
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingPlaceholder(double height, double r) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(r),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Loading video…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _errorPlaceholder(double height, double r) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.lesson.thumbnail, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'Could not load video',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _initPlayer,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolRow() {
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
        PopupMenuButton<double>(
          onSelected: _setSpeed,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0.5, child: Text('0.5×')),
            PopupMenuItem(value: 0.75, child: Text('0.75×')),
            PopupMenuItem(value: 1.0, child: Text('1×')),
            PopupMenuItem(value: 1.25, child: Text('1.25×')),
            PopupMenuItem(value: 1.5, child: Text('1.5×')),
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
                Text(
                  '${_speed == 1.0 ? '1' : _speed}×',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kPrimaryDark,
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
}

class _FullscreenLessonPlayer extends StatefulWidget {
  const _FullscreenLessonPlayer({
    required this.controller,
    required this.mirrorListenable,
    required this.lesson,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final ValueNotifier<bool> mirrorListenable;
  final LessonItem lesson;
  final VoidCallback onClose;

  @override
  State<_FullscreenLessonPlayer> createState() =>
      _FullscreenLessonPlayerState();
}

class _FullscreenLessonPlayerState extends State<_FullscreenLessonPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.mirrorListenable,
                builder: (context, mirror, _) {
                  final v = widget.controller.value;
                  final aspect = v.aspectRatio == 0 ? 1.0 : v.aspectRatio;
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
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      widget.controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF8BC34A),
                        bufferedColor: Color(0x66FFFFFF),
                        backgroundColor: Color(0x33FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            widget.controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${widget.lesson.sign} · ${widget.lesson.signAm}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                        IconButton(
                          onPressed: () => widget.mirrorListenable.value =
                              !widget.mirrorListenable.value,
                          icon: const Icon(
                            Icons.swap_horiz,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
