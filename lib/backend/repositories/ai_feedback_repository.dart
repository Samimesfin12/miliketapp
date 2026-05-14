import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// AI practice session rows and simple aggregates.
final class AIFeedbackRepository {
  AIFeedbackRepository(this._helper);
  final SQLiteHelper _helper;

  Future<int> insertFeedback({
    required int userId,
    required String targetSign,
    required String predictedSign,
    required double confidence,
    required bool isCorrect,
  }) async {
    final db = await _helper.database;
    return db.insert('ai_feedback', {
      'user_id': userId,
      'target_sign': targetSign,
      'predicted_sign': predictedSign,
      'confidence': confidence,
      'is_correct': isCorrect ? 1 : 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<double> averageConfidence(int userId) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT AVG(confidence) AS a FROM ai_feedback WHERE user_id = ?',
      [userId],
    );
    final v = rows.first['a'];
    if (v == null) return 0;
    return (v as num).toDouble();
  }
}
