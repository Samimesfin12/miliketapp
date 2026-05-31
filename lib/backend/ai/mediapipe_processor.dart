import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:camera/camera.dart';

abstract final class MediaPipeProcessor {
  static final _plugin = HandLandmarkerPlugin.create(
    numHands: 1,
    minHandDetectionConfidence: 0.45,
  );

  /// Converts a camera image frame into a flat list of 63 coordinates [x0,y0,z0,...,z20]
  static List<double>? processCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final hands = _plugin.detect(image, camera.sensorOrientation);
      if (hands.isEmpty) return null;

      final hand = hands.first;
      final flatCoords = <double>[];

      for (final landmark in hand.landmarks) {
        flatCoords.add(landmark.x);
        flatCoords.add(landmark.y);
        flatCoords.add(landmark.z);
      }

      return flatCoords.length == 63 ? flatCoords : null;
    } catch (e) {
      debugPrint("Error parsing hand landmarks: $e");
      return null;
    }
  }

  static Future<void> dispose() async {
    try {
      // Release native JNI resources
      _plugin.dispose();
    } catch (e) {
      debugPrint("Error disposing hand landmarker plugin: $e");
    }
  }
}