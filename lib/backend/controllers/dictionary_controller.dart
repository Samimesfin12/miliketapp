import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/repositories/dictionary_repository.dart';

final class DictionaryController {
  DictionaryController(this._ref);
  final Ref _ref;

  DictionaryRepository get dictionary =>
      _ref.read(dictionaryRepositoryProvider);
}

final dictionaryControllerProvider = Provider<DictionaryController>(
  (ref) => DictionaryController(ref),
);
