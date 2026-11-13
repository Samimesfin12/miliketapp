import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/models/curriculum_data.dart';
import 'package:esl_learning_flutter/backend/models/daily_quiz_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/backend/repositories/ai_feedback_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/category_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/dictionary_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/lesson_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/progress_repository.dart';
import 'package:esl_learning_flutter/backend/repositories/quiz_repository.dart';
import 'package:esl_learning_flutter/backend/auth/auth_session_notifier.dart';
import 'package:esl_learning_flutter/backend/repositories/user_repository.dart';
import 'package:esl_learning_flutter/backend/services/cultural_image_service.dart';
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

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(sqliteHelperProvider)),
);

final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => LessonRepository(ref.watch(sqliteHelperProvider)),
);

final culturalImageServiceProvider = Provider<CulturalImageService>(
  (ref) => CulturalImageService(),
);

final cultureCardSignsProvider = FutureProvider<List<LessonItem>>((ref) async {
  return ref.watch(lessonRepositoryProvider).cultureCardSigns();
});

final curriculumProvider = FutureProvider<CurriculumData>((ref) async {
  final categories = await ref
      .watch(categoryRepositoryProvider)
      .allCategories();
  final lessons = await ref.watch(lessonRepositoryProvider).allLessons();
  final map = <String, List<LessonItem>>{};
  for (final cat in categories) {
    map[cat.id] = [];
  }
  for (final lesson in lessons) {
    map.putIfAbsent(lesson.categoryId, () => []).add(lesson);
  }
  return CurriculumData(categories: categories, lessonsByCategory: map);
});

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

// ─── Daily Quiz provider ──────────────────────────────────────────────────────
//
// Generates up to 5 quiz questions from lessons the learner has already
// completed. Questions are shuffled using today's UTC date as the seed so
// they stay stable throughout the day but change the next day.
// Also checks whether the learner already submitted a result today.

/// Input parameter for [dailyQuizProvider] – the current user's id (nullable
/// for guests) and the full set of their completed lesson ids.
class DailyQuizInput {
  const DailyQuizInput({required this.userId, required this.completedIds});
  final int? userId;
  final Set<String> completedIds;
}

final dailyQuizInputProvider = StateProvider<DailyQuizInput>(
  (ref) => const DailyQuizInput(userId: null, completedIds: {}),
);

final dailyQuizProvider = FutureProvider<DailyQuizData>((ref) async {
  final input = ref.watch(dailyQuizInputProvider);
  final curriculum = await ref.watch(curriculumProvider.future);

  // 1. Gather all completed lessons from the curriculum
  final allLessons = curriculum.lessonsByCategory.values
      .expand((list) => list)
      .toList();

  final completed = allLessons
      .where((l) => input.completedIds.contains(l.id))
      .toList();

  // 2. Shuffle deterministically by today's date
  final today = DateTime.now().toUtc();
  final seed = today.year * 10000 + today.month * 100 + today.day;
  _seededShuffle(completed, seed);

  // 3. Pick up to 5 questions
  const maxQ = 5;
  final pool = completed.take(maxQ).toList();

  // 4. Build QuizQuestion list with distractors
  final questions = <QuizQuestion>[];
  final lessons = <LessonItem>[];

  for (final lesson in pool) {
    final others = allLessons.where((l) => l.id != lesson.id).toList();
    final lessonSeed = seed + _stableStringHash(lesson.id);
    _seededShuffle(others, lessonSeed);
    final wrong = others.take(3).toList();

    final correctLabel = '${lesson.sign} / ${lesson.signAm}';
    final opts = [correctLabel, ...wrong.map((w) => '${w.sign} / ${w.signAm}')];
    _seededShuffle(opts, lessonSeed + 1);

    questions.add(
      QuizQuestion(
        type: QuizType.watchAndChoose,
        question: 'Watch the sign and choose the correct meaning',
        questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
        correctAnswer: correctLabel,
        options: opts,
      ),
    );
    lessons.add(lesson);
  }

  // 5. Fetch today's best result if logged in
  int? todayScore;
  int? todayTotal;
  if (input.userId != null) {
    final quizRepo = ref.read(quizRepositoryProvider);
    final row = await quizRepo.todayResult(input.userId!);
    if (row != null) {
      todayScore = row['score'] as int?;
      todayTotal = row['total_questions'] as int?;
    }
  } else {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(dailyQuizGuestDateKey) == dailyQuizDateKey()) {
      todayScore = prefs.getInt(dailyQuizGuestScoreKey);
      todayTotal = prefs.getInt(dailyQuizGuestTotalKey);
    }
  }

  return DailyQuizData(
    questions: questions,
    lessons: lessons,
    todayScore: todayScore,
    todayTotal: todayTotal,
  );
});

/// Fisher-Yates shuffle with an integer seed (no dart:math Random needed).
void _seededShuffle<T>(List<T> list, int seed) {
  var s = seed.abs() == 0 ? 1 : seed.abs();
  for (var i = list.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
    final j = s % (i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

int _stableStringHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  return hash;
}
