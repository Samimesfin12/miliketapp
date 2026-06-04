import 'dart:math' as math;

abstract class PoseMatcher {
  /// Translates coordinates to place the wrist (0) at origin (0, 0, 0),
  /// scales coordinates by the distance between wrist (0) and middle finger knuckle (9),
  /// and automatically rotates the hand points so the hand points straight up (0, -1, 0).
  /// This makes the matching system 100% invariant to hand tilt and camera roll.
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
    
    // 2. Scale by 2D distance between wrist (0) and middle MCP (9) for absolute scale invariance
    final double mx = translated[9 * 3 + 0];
    final double my = translated[9 * 3 + 1];
    final double dist = math.sqrt(mx * mx + my * my);
    
    final scaled = List<double>.filled(63, 0.0);
    if (dist > 0) {
      for (int i = 0; i < 63; i++) {
        scaled[i] = translated[i] / dist;
      }
    } else {
      // Fallback to max 2D distance
      double maxDist = 0.0;
      for (int i = 0; i < 21; i++) {
        final double x = translated[i * 3 + 0];
        final double y = translated[i * 3 + 1];
        final double d = math.sqrt(x * x + y * y);
        if (d > maxDist) maxDist = d;
      }
      
      if (maxDist > 0) {
        for (int i = 0; i < 63; i++) {
          scaled[i] = translated[i] / maxDist;
        }
      } else {
        return translated;
      }
    }

    // 3. Align Rotation: rotate points so the vector from wrist (0) to middle MCP (9) points straight up (0, -1)
    final double mcp9X = scaled[9 * 3 + 0];
    final double mcp9Y = scaled[9 * 3 + 1];
    
    // Angle relative to straight vertical up in image space (0, -1)
    final double angle = math.atan2(mcp9X, -mcp9Y);
    final double cosA = math.cos(-angle);
    final double sinA = math.sin(-angle);

    for (int i = 0; i < 21; i++) {
      final double x = scaled[i * 3 + 0];
      final double y = scaled[i * 3 + 1];
      final double z = scaled[i * 3 + 2];

      normalized[i * 3 + 0] = x * cosA - y * sinA;
      normalized[i * 3 + 1] = x * sinA + y * cosA;
      normalized[i * 3 + 2] = z; // Keep depth Z same
    }

    return normalized;
  }

  /// Calculates Euclidean distance between two landmarks in flat 2D coordinates.
  /// Drops the noisy Z depth parameter for highly accurate shape estimation.
  static double landmarkDistance(List<double> coords, int idxA, int idxB) {
    final double dx = coords[idxA * 3 + 0] - coords[idxB * 3 + 0];
    final double dy = coords[idxA * 3 + 1] - coords[idxB * 3 + 1];
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Evaluates 5-finger tip-to-wrist distance configurations in 2D.
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
  /// Automatically supports both Left/Right hand and mirrored camera feeds by
  /// evaluating both raw and X-flipped coordinates, returning the higher match.
  static Map<String, dynamic> evaluatePose(List<double> user, List<double> template) {
    if (user.length != 63 || template.length != 63) {
      return {
        'similarity': 0.0,
        'is_correct': false,
        'feedback': ['Invalid hand tracker model. Keep hand visible.']
      };
    }

    // 1. Evaluate original raw orientation
    final evalOriginal = _evaluateSingleOrientation(user, template);

    // 2. Evaluate X-flipped (mirrored) orientation to support Left/Right hand and mirror-feeds
    final flippedUser = List<double>.from(user);
    for (int i = 0; i < 21; i++) {
      flippedUser[i * 3 + 0] = -flippedUser[i * 3 + 0]; // Flip X axis coordinates
    }
    final evalFlipped = _evaluateSingleOrientation(flippedUser, template);

    // 3. Return the evaluation that has the higher similarity score
    if ((evalFlipped['similarity'] as double) > (evalOriginal['similarity'] as double)) {
      return evalFlipped;
    }
    return evalOriginal;
  }

  /// Internal evaluator for a single pose orientation.
  /// Uses a hybrid of exponential-decay 2D Coordinate RMSE and 2D Bone Vector Cosine Similarity
  /// to provide an extremely accurate, fast, and robust confidence matching system.
  static Map<String, dynamic> _evaluateSingleOrientation(List<double> user, List<double> template) {
    // 1. Calculate Coordinate RMSE (Root-Mean-Square Error) in 2D (X and Y only)
    double squaredSum = 0.0;
    for (int i = 0; i < 21; i++) {
      final double dx = user[i * 3 + 0] - template[i * 3 + 0];
      final double dy = user[i * 3 + 1] - template[i * 3 + 1];
      squaredSum += (dx * dx + dy * dy);
    }
    
    final double rmse = math.sqrt(squaredSum / 21.0);
    
    // Smooth linear mapping for coordinate RMSE tuned for mobile camera noise & lens distortions
    double rmseSimilarity = 0.0;
    if (rmse <= 0.12) {
      rmseSimilarity = 1.0;
    } else if (rmse >= 0.28) {
      rmseSimilarity = 0.0;
    } else {
      rmseSimilarity = 1.0 - (rmse - 0.12) / (0.28 - 0.12);
    }

    // 2. Calculate 2D Cosine Similarity of Finger Bone Directions
    final fingerBones = [
      [2, 4],   // Thumb vector (knuckle to tip)
      [5, 8],   // Index vector
      [9, 12],  // Middle vector
      [13, 16], // Ring vector
      [17, 20]  // Pinky vector
    ];
    
    double fingerSimSum = 0.0;
    for (final bone in fingerBones) {
      final int start = bone[0];
      final int end = bone[1];
      
      // User bone vector
      final double ux = user[end * 3 + 0] - user[start * 3 + 0];
      final double uy = user[end * 3 + 1] - user[start * 3 + 1];
      final double uLen = math.sqrt(ux * ux + uy * uy);
      
      // Template bone vector
      final double tx = template[end * 3 + 0] - template[start * 3 + 0];
      final double ty = template[end * 3 + 1] - template[start * 3 + 1];
      final double tLen = math.sqrt(tx * tx + ty * ty);
      
      if (tLen > 0.45) {
        if (uLen > 0.45) {
          final double dot = (ux * tx + uy * ty) / (uLen * tLen);
          fingerSimSum += dot.clamp(0.0, 1.0);
        } else {
          // Template is extended but user is curled (mismatch)
          fingerSimSum += 0.0;
        }
      } else {
        // Curled finger in template: ignore direction vectors (which are highly noisy for curled shapes)
        // Rely purely on distance measurements for curled configuration
        fingerSimSum += 1.0;
      }
    }
    final double fingerSimilarity = fingerSimSum / 5.0;

    // Combine matching characteristics: 80% absolute coordinates space, 20% bone alignment directions
    // (Weighted more towards coordinates for noise protection)
    double similarity = (rmseSimilarity * 0.8) + (fingerSimilarity * 0.2);

    // 3. Profile individual finger extensions/flexions to build diagnostics and penalties
    final userDists = getFingerDistances(user);
    final tempDists = getFingerDistances(template);
    
    final feedback = <String>[];
    final fingers = ["Thumb", "Index", "Middle", "Ring", "Pinky"];
    int incorrectFingersCount = 0;

    for (final finger in fingers) {
      final double uD = userDists[finger] ?? 0.0;
      final double tD = tempDists[finger] ?? 0.0;
      final double diff = tD - uD;
      
      // Dual-threshold logic: feedback starts at 0.22 deviation, penalty only triggers at 0.30 deviation
      if (diff > 0.22) {
        if (diff > 0.30) {
          incorrectFingersCount++;
        }
        feedback.add("Extend your ${finger.toLowerCase()} finger more.");
      } else if (diff < -0.22) {
        if (diff < -0.30) {
          incorrectFingersCount++;
        }
        feedback.add("Curl/bend your ${finger.toLowerCase()} finger more.");
      }
    }

    // 4. Check tilt/orientation vectors (wrist 0 -> middle MCP 9) in 2D
    final double ux = user[9 * 3 + 0];
    final double uy = user[9 * 3 + 1];
    final double uLen = math.sqrt(ux * ux + uy * uy);
    
    final double tx = template[9 * 3 + 0];
    final double ty = template[9 * 3 + 1];
    final double tLen = math.sqrt(tx * tx + ty * ty);
    
    if (uLen > 0 && tLen > 0) {
      final double dotProduct = (ux * tx + uy * ty) / (uLen * tLen);
      if (dotProduct < 0.85) {
        feedback.add("Adjust the tilt/angle of your hand.");
      }
    }

    // Apply softer multiplicative penalty (0.85 instead of 0.8) to keep feedback granular rather than binary
    similarity = similarity * math.pow(0.85, incorrectFingersCount);

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
