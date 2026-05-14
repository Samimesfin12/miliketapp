import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/ai/mediapipe_processor.dart';
import 'package:esl_learning_flutter/backend/ai/tflite_classifier.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/repositories/ai_feedback_repository.dart';

final class AIPracticeController {
  AIPracticeController(this._ref);
  final Ref _ref;

  AIFeedbackRepository get feedback => _ref.read(aiFeedbackRepositoryProvider);

  /// Wire [MediaPipeProcessor] + [TfliteClassifier] when models are bundled.
  void dispose() {
    MediaPipeProcessor.dispose();
    TfliteClassifier.dispose();
  }
}

final aiPracticeControllerProvider = Provider<AIPracticeController>(
  (ref) => AIPracticeController(ref),
);
