import 'dart:math' as math;

abstract class PoseMatcher {
  /// Translates coordinates to place the wrist (0) at origin (0, 0, 0)
  /// and scales coordinates by the distance between wrist (0) and middle finger knuckle (9).
  static List<double> normalizeHand(List<double> raw) {
    if (raw.length != 63) return raw;

    final normalized = List<double>.filled(63, 0.0);
    
    // Wrist coordinates
    final double wx = raw[0];
    final double wy = raw[1];
    final double wz = raw[2];
    
    // 1. Translate wrist to (0, 0, 0)
    final translated = List<double>.filled(63, 0.0);
    for (int i = 0; i < 21; i++) {
      translated[i * 3 + 0] = raw[i * 3 + 0] - wx;
      translated[i * 3 + 1] = raw[i * 3 + 1] - wy;
      translated[i * 3 + 2] = raw[i * 3 + 2] - wz;
    }
    
    // 2. Scale by distance between wrist (0) and middle MCP (9)
    final double mx = translated[9 * 3 + 0];
    final double my = translated[9 * 3 + 1];
    final double mz = translated[9 * 3 + 2];
    final double dist = math.sqrt(mx * mx + my * my + mz * mz);
    
    if (dist > 0) {
      for (int i = 0; i < 63; i++) {
        normalized[i] = translated[i] / dist;
      }
    } else {
      // Fallback to max distance
      double maxDist = 0.0;
      for (int i = 0; i < 21; i++) {
        final double x = translated[i * 3 + 0];
        final double y = translated[i * 3 + 1];
        final double z = translated[i * 3 + 2];
        final double d = math.sqrt(x * x + y * y + z * z);
        if (d > maxDist) maxDist = d;
      }
      
      if (maxDist > 0) {
        for (int i = 0; i < 63; i++) {
          normalized[i] = translated[i] / maxDist;
        }
      } else {
        return translated;
      }
    }
    return normalized;
  }

  /// Calculates Euclidean distance between two landmarks in flat coordinates.
  static double landmarkDistance(List<double> coords, int idxA, int idxB) {
    final double dx = coords[idxA * 3 + 0] - coords[idxB * 3 + 0];
    final double dy = coords[idxA * 3 + 1] - coords[idxB * 3 + 1];
    final double dz = coords[idxA * 3 + 2] - coords[idxB * 3 + 2];
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Evaluates 5-finger tip-to-wrist distance configurations.
  static Map<String, double> getFingerDistances(List<double> normalizedCoords) {
    final tips = [4, 8, 12, 16, 20];
    final names = ["Thumb", "Index", "Middle", "Ring", "Pinky"];
    final dists = <String, double>{};
    
    for (int i = 0; i < 5; i++) {
      dists[names[i]] = landmarkDistance(normalizedCoords, tips[i], 0);
    }
    
    return dists;
  }

  /// Compares two normalized hand poses (user and template).
  /// Returns a combined confidence map containing:
  /// - 'similarity': Match score between 0.0 and 1.0.
  /// - 'is_correct': True if similarity >= 0.75.
  /// - 'feedback': List of correction suggestion strings.
  static Map<String, dynamic> evaluatePose(List<double> user, List<double> template) {
    if (user.length != 63 || template.length != 63) {
      return {
        'similarity': 0.0,
        'is_correct': false,
        'feedback': ['Invalid hand tracker model. Keep hand visible.']
      };
    }

    // 1. Calculate Coordinate RMSE (Root-Mean-Square Error)
    double squaredSum = 0.0;
    for (int i = 0; i < 21; i++) {
      final double dx = user[i * 3 + 0] - template[i * 3 + 0];
      final double dy = user[i * 3 + 1] - template[i * 3 + 1];
      final double dz = user[i * 3 + 2] - template[i * 3 + 2];
      squaredSum += (dx * dx + dy * dy + dz * dz);
    }
    
    final double rmse = math.sqrt(squaredSum / 21.0);
    
    // Baseline similarity score
    double similarity = 0.0;
    if (rmse < 0.10) {
      similarity = 1.0;
    } else if (rmse > 0.24) {
      similarity = 0.0;
    } else {
      similarity = 1.0 - (rmse - 0.10) / (0.24 - 0.10);
    }

    // 2. Profile individual fingers to build diagnostics and penalties
    final userDists = getFingerDistances(user);
    final tempDists = getFingerDistances(template);
    
    final feedback = <String>[];
    final fingers = ["Thumb", "Index", "Middle", "Ring", "Pinky"];
    int incorrectFingersCount = 0;

    for (final finger in fingers) {
      final double uD = userDists[finger] ?? 0.0;
      final double tD = tempDists[finger] ?? 0.0;
      final double diff = tD - uD;
      
      if (diff > 0.22) {
        incorrectFingersCount++;
        feedback.add("Extend your ${finger.toLowerCase()} finger more.");
      } else if (diff < -0.22) {
        incorrectFingersCount++;
        feedback.add("Curl/bend your ${finger.toLowerCase()} finger more.");
      }
    }

    // 3. Check tilt/orientation vectors (wrist 0 -> middle MCP 9)
    final double ux = user[9 * 3 + 0];
    final double uy = user[9 * 3 + 1];
    final double uz = user[9 * 3 + 2];
    final double uLen = math.sqrt(ux * ux + uy * uy + uz * uz);
    
    final double tx = template[9 * 3 + 0];
    final double ty = template[9 * 3 + 1];
    final double tz = template[9 * 3 + 2];
    final double tLen = math.sqrt(tx * tx + ty * ty + tz * tz);
    
    if (uLen > 0 && tLen > 0) {
      final double dotProduct = (ux * tx + uy * ty + uz * tz) / (uLen * tLen);
      if (dotProduct < 0.85) {
        feedback.add("Adjust the tilt/angle of your hand.");
      }
    }

    // Apply multiplicative penalties for finger errors
    similarity = similarity * math.pow(0.5, incorrectFingersCount);

    if (feedback.isEmpty) {
      feedback.add("Excellent form! Keep holding it.");
    }

    return {
      'similarity': similarity,
      'is_correct': similarity >= 0.75,
      'feedback': feedback,
    };
  }
}
