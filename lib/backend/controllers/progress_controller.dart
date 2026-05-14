import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/repositories/progress_repository.dart';

final class ProgressController {
  ProgressController(this._ref);
  final Ref _ref;

  ProgressRepository get progress => _ref.read(progressRepositoryProvider);
}

final progressControllerProvider = Provider<ProgressController>(
  (ref) => ProgressController(ref),
);
