import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/repositories/ai_feedback_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/dictionary_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/lesson_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/progress_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/quiz_repository.dart';
import 'package:esl_learning_flutter/backend/auth/auth_session_notifier.dart';
import 'package:esl_learning_flutter/backend/repositories/user_repository.dart';
import 'package:esl_learning_flutter/backend/services/localisation_service.dart';
import 'package:esl_learning_flutter/backend/services/video_downloader.dart';

final sqliteHelperProvider = Provider<SQLiteHelper>(
  (ref) => SQLiteHelper.instance,
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(sqliteHelperProvider)),
);

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>(
      (ref) => AuthSessionNotifier(
        ref.watch(userRepositoryProvider),
        ref.watch(sqliteHelperProvider),
      ),
    );

final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => LessonRepository(ref.watch(sqliteHelperProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(sqliteHelperProvider)),
);

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.watch(sqliteHelperProvider)),
);

final aiFeedbackRepositoryProvider = Provider<AIFeedbackRepository>(
  (ref) => AIFeedbackRepository(ref.watch(sqliteHelperProvider)),
);

final dictionaryRepositoryProvider = Provider<DictionaryRepository>(
  (ref) => DictionaryRepository(ref.watch(sqliteHelperProvider)),
);

final videoDownloaderProvider = Provider<VideoDownloader>(
  (ref) => VideoDownloader(),
);

final localisationServiceProvider = Provider<LocalisationService>(
  (ref) => LocalisationService(),
);
