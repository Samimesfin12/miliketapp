import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/repositories/quiz_repository.dart';

final class QuizController {
  QuizController(this._ref);
  final Ref _ref;

  QuizRepository get quiz => _ref.read(quizRepositoryProvider);
}

final quizControllerProvider = Provider<QuizController>(
  (ref) => QuizController(ref),
);
