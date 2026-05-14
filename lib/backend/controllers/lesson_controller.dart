import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/repositories/lesson_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/progress_repository.dart';

final class LessonController {
  LessonController(this._ref);
  final Ref _ref;

  LessonRepository get lessons => _ref.read(lessonRepositoryProvider);
  ProgressRepository get progress => _ref.read(progressRepositoryProvider);
}

final lessonControllerProvider = Provider<LessonController>(
  (ref) => LessonController(ref),
);
