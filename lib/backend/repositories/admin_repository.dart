import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// Aggregated queries for the admin dashboard.
final class AdminRepository {
  AdminRepository(this._helper);
  final SQLiteHelper _helper;

  Future<int> countQuizAttempts() async {
    final db = await _helper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM quiz_results');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countAiFeedback() async {
    final db = await _helper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM ai_feedback');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, Object?>>> recentQuizResults({int limit = 20}) async {
    final db = await _helper.database;
    return db.query(
      'quiz_results',
      orderBy: 'taken_at DESC',
      limit: limit,
    );
  }
}
