import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/ai/tflite_classifier.dart';
import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/ai/pose_matcher.dart';

/// Live practice controller — scoring must stay identical to
/// C:\Users\hp\sign_practice\index.html (processHandFrame + evaluatePose).
final class AIPracticeController {
  AIPracticeController(this._ref);
  final Ref _ref;

  static const _bufferSize = 5;

  final List<List<double>> slidingBuffer = [];

  List<double>? _cachedTemplate;
  String? _cachedSignId;

  SQLiteHelper get _sqliteHelper => _ref.read(sqliteHelperProvider);

  Future<void> preloadTemplate(String targetSign) async {
    final normalizedSignId = targetSign.toLowerCase().trim();
    if (_cachedSignId == normalizedSignId) {
      return;
    }
    _cachedSignId = normalizedSignId;
    final rawTemplate = await _sqliteHelper.getSignTemplate(normalizedSignId);
    if (rawTemplate != null) {
      // Templates from sign_practice are already post-normalizeHand().
      _cachedTemplate = List<double>.from(rawTemplate);
    } else {
      _cachedTemplate = null;
    }
  }

  Future<Map<String, dynamic>?> processFrame(
    List<double> frameLandmarks,
    String targetSign,
  ) async {
    await preloadTemplate(targetSign);
    final template = _cachedTemplate;
    if (template == null) {
      return {
        'target_confidence': 0.0,
        'is_correct': false,
        'feedback': ['Practice sign not trained. Record a template first!'],
      };
    }

    final normalizedFrame = PoseMatcher.normalizeHand(frameLandmarks);
    slidingBuffer.add(normalizedFrame);
    if (slidingBuffer.length > _bufferSize) {
      slidingBuffer.removeAt(0);
    }

    if (slidingBuffer.length < _bufferSize) {
      return {
        'target_confidence': 0.0,
        'is_correct': false,
        'feedback': ['Analyzing... Hold your pose steady.'],
      };
    }

    final avgUserPose = _averagePose(slidingBuffer);
    final evaluation = PoseMatcher.evaluatePose(avgUserPose, template);
    final similarity = (evaluation['similarity'] as num).toDouble();

    return {
      'target_confidence': similarity,
      'is_correct': evaluation['is_correct'] as bool,
      'feedback': evaluation['feedback'] as List<String>,
    };
  }

  /// 5-frame arithmetic mean — matches sign_practice slidingBuffer logic.
  static List<double> _averagePose(List<List<double>> frames) {
    final avg = List<double>.filled(63, 0.0);
    for (var i = 0; i < 63; i++) {
      var sum = 0.0;
      for (final frame in frames) {
        sum += frame[i];
      }
      avg[i] = sum / frames.length;
    }
    return avg;
  }

  Future<void> saveFeedback({
    required int userId,
    required String targetSign,
    required String predictedSign,
    required double confidence,
    required bool isCorrect,
  }) async {
    final repo = _ref.read(aiFeedbackRepositoryProvider);
    await repo.insertFeedback(
      userId: userId,
      targetSign: targetSign,
      predictedSign: predictedSign,
      confidence: confidence,
      isCorrect: isCorrect,
    );
  }

  void clearBuffer() {
    slidingBuffer.clear();
  }

  void dispose() {
    _cachedTemplate = null;
    _cachedSignId = null;
    TfliteClassifier.dispose();
  }
}

final aiPracticeControllerProvider = Provider<AIPracticeController>(
  (ref) => AIPracticeController(ref),
);
