import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

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
}
