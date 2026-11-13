import 'package:esl_learning_flutter/models/app_models.dart';

const dailyQuizCategoryId = '__daily__';
const dailyQuizGuestDateKey = 'dailyQuizResultDate';
const dailyQuizGuestScoreKey = 'dailyQuizResultScore';
const dailyQuizGuestTotalKey = 'dailyQuizResultTotal';

String dailyQuizDateKey([DateTime? date]) {
  final utcDate = (date ?? DateTime.now()).toUtc();
  final year = utcDate.year.toString().padLeft(4, '0');
  final month = utcDate.month.toString().padLeft(2, '0');
  final day = utcDate.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Data bundle for the Practice Quiz of the Day.
/// [questions]  — up to 5 generated QuizQuestions from completed lessons.
/// [lessons]    — parallel list: lessons[i] is the lesson shown for questions[i].
/// [todayScore] — null if the learner hasn't taken the quiz today yet.
/// [todayTotal] — null if not yet taken today.
class DailyQuizData {
  const DailyQuizData({
    required this.questions,
    required this.lessons,
    this.todayScore,
    this.todayTotal,
  });

  final List<QuizQuestion> questions;
  final List<LessonItem> lessons;
  final int? todayScore;
  final int? todayTotal;

  /// True when the learner has at least one completed lesson to quiz on.
  bool get hasQuestions => questions.isNotEmpty;

  /// True when the learner already took (and completed) the daily quiz today.
  bool get takenToday => todayScore != null;

  int get questionCount => questions.length;
}
