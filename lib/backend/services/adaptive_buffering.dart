import 'package:video_player/video_player.dart';

/// Adaptive buffering strategy for optimal video playback performance.
/// Automatically adjusts buffer sizes based on network conditions and video properties.
class AdaptiveBufferingStrategy {
  /// Minimum buffer duration before starting playback (for fast loading)
  static const Duration minInitialBuffer = Duration(milliseconds: 500);

  /// Target buffer duration during playback (maintains smooth playback)
  static const Duration targetPlaybackBuffer = Duration(seconds: 5);

  /// Maximum buffer duration (prevent excessive memory usage)
  static const Duration maxBuffer = Duration(seconds: 30);

  /// Re-buffer threshold: pause if buffer falls below this
  static const Duration rebufferThreshold = Duration(seconds: 2);

  /// Buffer level at which to resume playback
  static const Duration resumeThreshold = Duration(seconds: 4);

  /// Detects current network quality based on buffer state
  static NetworkQuality detectNetworkQuality(
    Duration bufferedDuration,
    Duration currentPosition,
    Duration totalDuration,
  ) {
    final bufferPercentage =
        (bufferedDuration.inMilliseconds / totalDuration.inMilliseconds) * 100;

    if (bufferPercentage < 5) {
      return NetworkQuality.poor;
    } else if (bufferPercentage < 15) {
      return NetworkQuality.fair;
    } else if (bufferPercentage < 40) {
      return NetworkQuality.good;
    } else {
      return NetworkQuality.excellent;
    }
  }

  /// Determines if playback should resume based on buffer level
  static bool shouldResumePlayback(Duration bufferedDuration) {
    return bufferedDuration >= resumeThreshold;
  }

  /// Determines if playback should pause due to insufficient buffer
  static bool shouldPauseForBuffering(Duration bufferedDuration) {
    return bufferedDuration < rebufferThreshold;
  }

  /// Estimates estimated time until buffer is full
  static Duration estimateBufferTime(
    int currentBufferBytes,
    int targetBufferBytes,
    double downloadSpeedBytesPerSec,
  ) {
    if (downloadSpeedBytesPerSec <= 0) {
      return const Duration(seconds: 60);
    }

    final remainingBytes = targetBufferBytes - currentBufferBytes;
    if (remainingBytes <= 0) {
      return Duration.zero;
    }

    final seconds = remainingBytes / downloadSpeedBytesPerSec;
    return Duration(seconds: seconds.toInt());
  }

  /// Calculates adaptive playback speed based on network conditions
  static double getAdaptivePlaybackSpeed(
    NetworkQuality quality,
    double currentSpeed,
  ) {
    switch (quality) {
      case NetworkQuality.poor:
        return 0.5; // Reduce playback speed on poor connections
      case NetworkQuality.fair:
        return 0.75;
      case NetworkQuality.good:
        return 1.0;
      case NetworkQuality.excellent:
        return 1.0; // Could enable 1.25x on excellent networks
    }
  }
}

/// Enumeration of network quality levels
enum NetworkQuality {
  poor,   // < 5% buffered
  fair,   // 5-15% buffered
  good,   // 15-40% buffered
  excellent; // > 40% buffered

  bool get isPoor => this == NetworkQuality.poor;
  bool get isFair => this == NetworkQuality.fair;
  bool get isGood => this == NetworkQuality.good;
  bool get isExcellent => this == NetworkQuality.excellent;
  
  String get label {
    switch (this) {
      case NetworkQuality.poor:
        return '🔴 Poor';
      case NetworkQuality.fair:
        return '🟡 Fair';
      case NetworkQuality.good:
        return '🟢 Good';
      case NetworkQuality.excellent:
        return '✅ Excellent';
    }
  }
}

/// Enhanced video player controller with adaptive buffering
class AdaptiveVideoController {
  final VideoPlayerController _controller;

  AdaptiveVideoController(this._controller);

  /// Check if we should pause for buffering
  bool shouldPauseForBuffering() {
    final value = _controller.value;
    if (!value.isInitialized) return false;

    final bufferedDuration = _getBufferedDuration();
    return AdaptiveBufferingStrategy.shouldPauseForBuffering(bufferedDuration);
  }

  /// Check if we should resume from pause
  bool shouldResumePlayback() {
    final value = _controller.value;
    if (!value.isInitialized) return false;

    final bufferedDuration = _getBufferedDuration();
    return AdaptiveBufferingStrategy.shouldResumePlayback(bufferedDuration);
  }

  /// Get buffered duration estimate
  Duration _getBufferedDuration() {
    final value = _controller.value;
    if (value.buffered.isEmpty) return Duration.zero;

    // Last buffered range
    final lastRange = value.buffered.last;
    return lastRange.end - value.position;
  }

  /// Get current network quality assessment
  NetworkQuality getNetworkQuality() {
    final value = _controller.value;
    if (!value.isInitialized) return NetworkQuality.fair;

    final bufferedDuration = _getBufferedDuration();
    return AdaptiveBufferingStrategy.detectNetworkQuality(
      bufferedDuration,
      value.position,
      value.duration,
    );
  }
}
