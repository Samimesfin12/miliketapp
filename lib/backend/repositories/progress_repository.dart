import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// Completion tracking and simple aggregates for progress UI.
final class ProgressRepository {
  ProgressRepository(this._helper);
  final SQLiteHelper _helper;

  Future<bool> isCompleted(int userId, String lessonId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'progress',
      columns: ['id'],
      where: 'user_id = ? AND lesson_id = ?',
      whereArgs: [userId, lessonId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> completedLessonIds(int userId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'progress',
      columns: ['lesson_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((e) => e['lesson_id']! as String).toSet();
  }

  /// Inserts a [progress] row when missing (idempotent per user + lesson).
  Future<void> markLessonCompleted(int userId, String lessonId) async {
    await _helper.transaction((txn) async {
      final done = await txn.query(
        'progress',
        where: 'user_id = ? AND lesson_id = ?',
        whereArgs: [userId, lessonId],
        limit: 1,
      );
      if (done.isNotEmpty) return;

      final completedAt = DateTime.now().toUtc().toIso8601String();
      await txn.insert('progress', {
        'user_id': userId,
        'lesson_id': lessonId,
        'completed_at': completedAt,
      });
    });
  }

  /// Completed lessons whose [completed_at] is on the same UTC calendar day as [day].
  Future<int> countCompletionsOnDay(int userId, DateTime day) async {
    final db = await _helper.database;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
    ).toUtc().toIso8601String();
    final end = DateTime(
      day.year,
      day.month,
      day.day,
      23,
      59,
      59,
      999,
    ).toUtc().toIso8601String();
    final rows = await db.rawQuery(
      '''
SELECT COUNT(*) AS c FROM progress
WHERE user_id = ? AND completed_at >= ? AND completed_at <= ?
''',
      [userId, start, end],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
