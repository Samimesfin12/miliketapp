import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:hand_landmarker/hand_landmarker_bindings.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

/// Separated Y/U/V buffers extracted from NV21 or other packed layouts.
final class _YuvPlanes {
  const _YuvPlanes({
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
}

abstract final class MediaPipeProcessor {
  static HandLandmarkerPlugin? _plugin;
  static MyHandLandmarker? _nv21Landmarker;
  static StreamSubscription<List<Hand>>? _landmarkSubscription;
  static StreamController<List<double>?>? _landmarkUpdatesController;

  static List<double>? _latestCoords;
  static bool _handDetected = false;
  static bool _initialized = false;
  static bool _loggedFrameFormat = false;

  static List<double>? get latestCoords => _latestCoords;
  static bool get handDetected => _handDetected;

  /// Emits flattened landmark coords (63 doubles) or null when no hand is detected.
  static Stream<List<double>?> get landmarkUpdates {
    _landmarkUpdatesController ??=
        StreamController<List<double>?>.broadcast();
    return _landmarkUpdatesController!.stream;
  }

  /// Initializes native MediaPipe and listens for async landmark results.
  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    _plugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.55,
      delegate: HandLandmarkerDelegate.cpu,
    );

    _landmarkSubscription = _plugin!.landmarkStream.listen(
      _onHandsDetected,
      onError: (Object error) {
        debugPrint('Hand landmarker stream error: $error');
      },
    );

    _initialized = true;
  }

  static void _onHandsDetected(List<Hand> hands) {
    if (hands.isEmpty) {
      _setLandmarks(null);
      return;
    }

    final flatCoords = <double>[];
    for (final landmark in hands.first.landmarks) {
      flatCoords
        ..add(landmark.x)
        ..add(landmark.y)
        ..add(landmark.z);
    }

    _setLandmarks(flatCoords.length == 63 ? flatCoords : null);
  }

  static void _setLandmarks(List<double>? coords) {
    _latestCoords = coords;
    _handDetected = coords != null;
    _landmarkUpdatesController?.add(coords);
  }

  /// Feeds a camera frame into the native pipeline (non-blocking).
  static void feedCameraImage(CameraImage image, CameraDescription camera) {
    if (!_initialized || _plugin == null) return;

    if (!_loggedFrameFormat) {
      _loggedFrameFormat = true;
      debugPrint(
        'Camera frame: ${image.width}x${image.height}, '
        'planes=${image.planes.length}, format=${image.format.group}, '
        'orientation=${camera.sensorOrientation}',
      );
    }

    try {
      final orientation = camera.sensorOrientation;

      if (image.planes.length >= 3) {
        _plugin!.processFrame(image, orientation);
        return;
      }

      // Emulators often deliver NV21 as 1–2 planes with the default format.
      final planes = _extractYuvPlanes(image);
      if (planes == null) {
        debugPrint(
          'Unsupported camera format: ${image.format.group} '
          'with ${image.planes.length} plane(s)',
        );
        return;
      }

      _nv21Landmarker ??= MyHandLandmarker(androidApplicationContext)
        ..initialize(1, 0.55, false);

      _sendNv21Frame(
        _nv21Landmarker!,
        planes,
        image.width,
        image.height,
        orientation,
      );
    } catch (e) {
      debugPrint('Error feeding camera frame: $e');
    }
  }

  static void _sendNv21Frame(
    MyHandLandmarker landmarker,
    _YuvPlanes planes,
    int width,
    int height,
    int orientation,
  ) {
    final yBuffer = JByteBuffer.fromList(planes.y);
    final uBuffer = JByteBuffer.fromList(planes.u);
    final vBuffer = JByteBuffer.fromList(planes.v);

    try {
      landmarker.processFrame(
        yBuffer,
        uBuffer,
        vBuffer,
        width,
        height,
        planes.yRowStride,
        planes.uvRowStride,
        planes.uvPixelStride,
        orientation,
        DateTime.now().millisecondsSinceEpoch,
      );
    } finally {
      yBuffer.release();
      uBuffer.release();
      vBuffer.release();
    }
  }

  /// Copies a Y plane row-by-row when [bytesPerRow] exceeds [width].
  static Uint8List _copyYPlane(Plane yPlane, int width, int height) {
    final rowStride = yPlane.bytesPerRow == 0 ? width : yPlane.bytesPerRow;
    final yBytes = Uint8List(width * height);
    for (var row = 0; row < height; row++) {
      final srcStart = row * rowStride;
      final dstStart = row * width;
      if (srcStart + width > yPlane.bytes.length) break;
      yBytes.setRange(dstStart, dstStart + width, yPlane.bytes, srcStart);
    }
    return yBytes;
  }

  /// Converts 1- or 2-plane NV21 [CameraImage] data into separate Y/U/V buffers.
  static _YuvPlanes? _extractYuvPlanes(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final chromaWidth = width ~/ 2;
    final chromaHeight = height ~/ 2;
    final chromaSize = chromaWidth * chromaHeight;

    if (image.planes.length == 2) {
      final yPlane = image.planes[0];
      final uvPlane = image.planes[1];
      final uBytes = Uint8List(chromaSize);
      final vBytes = Uint8List(chromaSize);
      final pixelStride = uvPlane.bytesPerPixel ?? 2;
      final rowStride = uvPlane.bytesPerRow;

      var index = 0;
      for (var row = 0; row < chromaHeight; row++) {
        for (var col = 0; col < chromaWidth; col++) {
          final offset = row * rowStride + col * pixelStride;
          if (offset + 1 >= uvPlane.bytes.length) break;
          vBytes[index] = uvPlane.bytes[offset];
          uBytes[index] = uvPlane.bytes[offset + 1];
          index++;
        }
      }

      return _YuvPlanes(
        y: _copyYPlane(yPlane, width, height),
        u: uBytes,
        v: vBytes,
        yRowStride: width,
        uvRowStride: chromaWidth,
        uvPixelStride: 1,
      );
    }

    if (image.planes.length == 1) {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final yRowStride = plane.bytesPerRow == 0 ? width : plane.bytesPerRow;
      final ySize = yRowStride * height;
      if (bytes.length < ySize + 2) return null;

      final yBytes = _copyYPlane(plane, width, height);

      final uBytes = Uint8List(chromaSize);
      final vBytes = Uint8List(chromaSize);
      var uvIndex = 0;

      for (var row = 0; row < chromaHeight; row++) {
        final rowStart = ySize + row * width;
        for (var col = 0; col < chromaWidth; col++) {
          final offset = rowStart + col * 2;
          if (offset + 1 >= bytes.length || uvIndex >= chromaSize) break;
          vBytes[uvIndex] = bytes[offset];
          uBytes[uvIndex] = bytes[offset + 1];
          uvIndex++;
        }
      }

      return _YuvPlanes(
        y: yBytes,
        u: uBytes,
        v: vBytes,
        yRowStride: width,
        uvRowStride: chromaWidth,
        uvPixelStride: 1,
      );
    }

    return null;
  }

  static Future<void> dispose() async {
    await _landmarkSubscription?.cancel();
    _landmarkSubscription = null;

    try {
      _plugin?.dispose();
    } catch (e) {
      debugPrint('Error disposing hand landmarker plugin: $e');
    }

    try {
      _nv21Landmarker?.release();
    } catch (e) {
      debugPrint('Error disposing NV21 hand landmarker: $e');
    }

    await _landmarkUpdatesController?.close();
    _landmarkUpdatesController = null;

    _plugin = null;
    _nv21Landmarker = null;
    _latestCoords = null;
    _handDetected = false;
    _initialized = false;
    _loggedFrameFormat = false;
  }
}
