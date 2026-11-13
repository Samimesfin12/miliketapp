import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/backend/models/daily_quiz_data.dart';

/// Persists quiz session scores.
final class QuizRepository {
  QuizRepository(this._helper);
  final SQLiteHelper _helper;

  Future<int> insertResult({
    required int userId,
    required String categoryId,
    required int score,
    required int totalQuestions,
  }) async {
    final db = await _helper.database;
    if (categoryId == dailyQuizCategoryId) {
      await db.insert('categories', {
        'id': dailyQuizCategoryId,
        'title': 'Daily Quiz',
        'title_am': 'ዕለታዊ ጥያቄ',
        'icon': '☀️',
        'color_argb': 0xFF0A6D40,
        'description': 'Reserved category for daily quiz results',
        'sort_order': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return db.insert('quiz_results', {
      'user_id': userId,
      'category_id': categoryId,
      'score': score,
      'total_questions': totalQuestions,
      'taken_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> recentResults(
    int userId, {
    int limit = 20,
  }) async {
    final db = await _helper.database;
    return db.query(
      'quiz_results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'taken_at DESC',
      limit: limit,
    );
  }

  /// Returns the best [score, total_questions] row for the daily quiz
  /// taken by [userId] on today's UTC calendar date, or null if not yet taken.
  Future<Map<String, Object?>?> todayResult(int userId) async {
    final db = await _helper.database;
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final nextDayStart = dayStart.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      '''
SELECT score, total_questions
FROM quiz_results
WHERE user_id = ? AND category_id = ? AND taken_at >= ? AND taken_at < ?
ORDER BY (1.0 * score / total_questions) DESC, score DESC
LIMIT 1
''',
      [
        userId,
        dailyQuizCategoryId,
        dayStart.toIso8601String(),
        nextDayStart.toIso8601String(),
      ],
    );
    return rows.isEmpty ? null : rows.first;
  }
}
