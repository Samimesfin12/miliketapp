import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/ai/mediapipe_processor.dart';
import 'package:esl_learning_flutter/backend/ai/tflite_classifier.dart';
import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/ai/pose_matcher.dart';

final class AIPracticeController {
  AIPracticeController(this._ref);
  final Ref _ref;
  
  // Rolling sequence buffer
  final List<List<double>> slidingBuffer = [];

  List<double>? _cachedTemplate;
  String? _cachedSignId;

  SQLiteHelper get _sqliteHelper => _ref.read(sqliteHelperProvider);

  /// Preloads target sign template to avoid database queries on every frame
  Future<void> preloadTemplate(String targetSign) async {
    final normalizedSignId = targetSign.toLowerCase().trim();
    if (_cachedSignId == normalizedSignId) {
      return; // Already queried/cached
    }
    _cachedSignId = normalizedSignId;
    final rawTemplate = await _sqliteHelper.getSignTemplate(normalizedSignId);
    if (rawTemplate != null) {
      _cachedTemplate = PoseMatcher.normalizeHand(rawTemplate);
    } else {
      _cachedTemplate = null;
    }
  }

  /// Evaluates hand coordinate landmarks against the target sign locally.
  /// Decays sequences, averages frames, and compares to templates in SQLite.
  Future<Map<String, dynamic>?> processFrame(List<double> frameLandmarks, String targetSign) async {
    // 1. Ensure template is loaded in cache
    await preloadTemplate(targetSign);
    final template = _cachedTemplate;
    if (template == null) {
      return {
        'target_confidence': 0.0,
        'is_correct': false,
        'feedback': ['Practice sign not trained. Record a template first!']
      };
    }

    // 2. Normalize user landmarks frame-by-frame
    final normalizedFrame = PoseMatcher.normalizeHand(frameLandmarks);
    slidingBuffer.add(normalizedFrame);
    if (slidingBuffer.length > 5) {
      slidingBuffer.removeAt(0);
    }

    if (slidingBuffer.length == 5) {
      // 3. Average the user coordinates in the sliding buffer (5 frames for fast responsiveness)
      final userAvgPose = List<double>.filled(63, 0.0);
      for (int i = 0; i < 63; i++) {
        double sum = 0.0;
        for (int f = 0; f < 5; f++) {
          sum += slidingBuffer[f][i];
        }
        userAvgPose[i] = sum / 5.0;
      }

      // 4. Match averaged user pose with local database template
      final evaluation = PoseMatcher.evaluatePose(userAvgPose, template);
      return {
        'target_confidence': evaluation['similarity'] as double,
        'is_correct': evaluation['is_correct'] as bool,
        'feedback': evaluation['feedback'] as List<String>,
      };
    } else {
      // Return a default "Analyzing..." state while buffer is filling
      return {
        'target_confidence': 0.0,
        'is_correct': false,
        'feedback': ['Analyzing... Hold your pose steady.']
      };
    }
  }



  /// Saves an evaluation result to the SQLite ai_feedback table
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
    MediaPipeProcessor.dispose();
    TfliteClassifier.dispose();
  }
}

final aiPracticeControllerProvider = Provider<AIPracticeController>(
  (ref) => AIPracticeController(ref),
);
