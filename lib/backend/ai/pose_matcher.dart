import 'dart:math' as math;

/// Pose matching — must stay identical to sign_practice/index.html:
/// normalizeHand(), evaluatePose(), _evaluateSingleOrientation().
abstract class PoseMatcher {
  static const _rmsePerfect = 0.12;
  static const _rmseZero = 0.28;
  static const _isCorrectThreshold = 0.75;
  static const _feedbackThreshold = 0.22;
  static const _penaltyThreshold = 0.30;
  static const _penaltyBase = 0.85;
  static const _boneExtendedLen = 0.45;
  static const _tiltDotThreshold = 0.85;

  static List<double> normalizeHand(List<double> raw) {
    if (raw.length != 63) return raw;

    final normalized = List<double>.filled(63, 0.0);

    final double wx = raw[0];
    final double wy = raw[1];
    final double wz = raw[2];

    final translated = List<double>.filled(63, 0.0);
    for (int i = 0; i < 21; i++) {
      translated[i * 3 + 0] = raw[i * 3 + 0] - wx;
      translated[i * 3 + 1] = raw[i * 3 + 1] - wy;
      translated[i * 3 + 2] = raw[i * 3 + 2] - wz;
    }

    final double mx = translated[9 * 3 + 0];
    final double my = translated[9 * 3 + 1];
    final double dist = math.sqrt(mx * mx + my * my);

    final scaled = List<double>.filled(63, 0.0);
    if (dist > 0) {
      for (int i = 0; i < 63; i++) {
        scaled[i] = translated[i] / dist;
      }
    } else {
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

    final double mcp9X = scaled[9 * 3 + 0];
    final double mcp9Y = scaled[9 * 3 + 1];

    final double angle = math.atan2(mcp9X, -mcp9Y);
    final double cosA = math.cos(-angle);
    final double sinA = math.sin(-angle);

    for (int i = 0; i < 21; i++) {
      final double x = scaled[i * 3 + 0];
      final double y = scaled[i * 3 + 1];
      final double z = scaled[i * 3 + 2];

      normalized[i * 3 + 0] = x * cosA - y * sinA;
      normalized[i * 3 + 1] = x * sinA + y * cosA;
      normalized[i * 3 + 2] = z;
    }

    return normalized;
  }

  static double landmarkDistance(List<double> coords, int idxA, int idxB) {
    final double dx = coords[idxA * 3 + 0] - coords[idxB * 3 + 0];
    final double dy = coords[idxA * 3 + 1] - coords[idxB * 3 + 1];
    return math.sqrt(dx * dx + dy * dy);
  }

  static Map<String, double> getFingerDistances(List<double> normalizedCoords) {
    const tips = [4, 8, 12, 16, 20];
    const names = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];
    final dists = <String, double>{};

    for (int i = 0; i < 5; i++) {
      dists[names[i]] = landmarkDistance(normalizedCoords, tips[i], 0);
    }

    return dists;
  }

  static Map<String, dynamic> evaluatePose(List<double> user, List<double> template) {
    if (user.length != 63 || template.length != 63) {
      return {
        'similarity': 0.0,
        'is_correct': false,
        'feedback': ['Keep hand fully in camera view.'],
      };
    }

    final evalOriginal = _evaluateSingleOrientation(user, template);

    final flippedUser = List<double>.from(user);
    for (int i = 0; i < 21; i++) {
      flippedUser[i * 3 + 0] = -flippedUser[i * 3 + 0];
    }
    final evalFlipped = _evaluateSingleOrientation(flippedUser, template);

    if ((evalFlipped['similarity'] as double) > (evalOriginal['similarity'] as double)) {
      return evalFlipped;
    }
    return evalOriginal;
  }

  static Map<String, dynamic> _evaluateSingleOrientation(
    List<double> user,
    List<double> template,
  ) {
    double squaredSum = 0.0;
    for (int i = 0; i < 21; i++) {
      final double dx = user[i * 3 + 0] - template[i * 3 + 0];
      final double dy = user[i * 3 + 1] - template[i * 3 + 1];
      squaredSum += (dx * dx + dy * dy);
    }

    final double rmse = math.sqrt(squaredSum / 21.0);

    double rmseSimilarity = 0.0;
    if (rmse <= _rmsePerfect) {
      rmseSimilarity = 1.0;
    } else if (rmse >= _rmseZero) {
      rmseSimilarity = 0.0;
    } else {
      rmseSimilarity = 1.0 - (rmse - _rmsePerfect) / (_rmseZero - _rmsePerfect);
    }

    const fingerBones = [
      [2, 4],
      [5, 8],
      [9, 12],
      [13, 16],
      [17, 20],
    ];

    double fingerSimSum = 0.0;
    for (final bone in fingerBones) {
      final int start = bone[0];
      final int end = bone[1];

      final double ux = user[end * 3 + 0] - user[start * 3 + 0];
      final double uy = user[end * 3 + 1] - user[start * 3 + 1];
      final double uLen = math.sqrt(ux * ux + uy * uy);

      final double tx = template[end * 3 + 0] - template[start * 3 + 0];
      final double ty = template[end * 3 + 1] - template[start * 3 + 1];
      final double tLen = math.sqrt(tx * tx + ty * ty);

      if (tLen > _boneExtendedLen) {
        if (uLen > _boneExtendedLen) {
          final double dot = (ux * tx + uy * ty) / (uLen * tLen);
          fingerSimSum += dot.clamp(0.0, 1.0);
        }
      } else {
        fingerSimSum += 1.0;
      }
    }
    final double fingerSimilarity = fingerSimSum / 5.0;

    double similarity = (rmseSimilarity * 0.8) + (fingerSimilarity * 0.2);

    final userDists = getFingerDistances(user);
    final tempDists = getFingerDistances(template);

    final feedback = <String>[];
    const fingers = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];
    var incorrectFingersCount = 0;

    for (final finger in fingers) {
      final double uD = userDists[finger] ?? 0.0;
      final double tD = tempDists[finger] ?? 0.0;
      final double diff = tD - uD;

      if (diff > _feedbackThreshold) {
        if (diff > _penaltyThreshold) incorrectFingersCount++;
        feedback.add('Extend your ${finger.toLowerCase()} finger more.');
      } else if (diff < -_feedbackThreshold) {
        if (diff < -_penaltyThreshold) incorrectFingersCount++;
        feedback.add('Curl/bend your ${finger.toLowerCase()} finger more.');
      }
    }

    final double ux = user[9 * 3 + 0];
    final double uy = user[9 * 3 + 1];
    final double uLen = math.sqrt(ux * ux + uy * uy);

    final double tx = template[9 * 3 + 0];
    final double ty = template[9 * 3 + 1];
    final double tLen = math.sqrt(tx * tx + ty * ty);

    if (uLen > 0 && tLen > 0) {
      final double dotProduct = (ux * tx + uy * ty) / (uLen * tLen);
      if (dotProduct < _tiltDotThreshold) {
        feedback.add('Adjust the tilt/angle of your hand.');
      }
    }

    similarity = similarity * math.pow(_penaltyBase, incorrectFingersCount);

    if (feedback.isEmpty) {
      feedback.add('Excellent form! Keep holding it.');
    }

    return {
      'similarity': similarity,
      'is_correct': similarity >= _isCorrectThreshold,
      'feedback': feedback,
    };
  }
}
