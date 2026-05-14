import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// Lesson queries, lock updates, and local video path updates.
final class LessonRepository {
  LessonRepository(this._helper);
  final SQLiteHelper _helper;

  Future<List<Map<String, Object?>>> lessonsForCategory(
    String categoryId,
  ) async {
    final db = await _helper.database;
    return db.query(
      'lessons',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'order_index ASC',
    );
  }

  Future<Map<String, Object?>?> lessonById(String lessonId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> setLocked(String lessonId, bool locked) async {
    final db = await _helper.database;
    return db.update(
      'lessons',
      {'locked': locked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }

  Future<int> setLocalVideoPath(String lessonId, String? localPath) async {
    final db = await _helper.database;
    return db.update(
      'lessons',
      {'video_local_path': localPath},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }

  Future<int> setVideoUrl(String lessonId, String? url) async {
    final db = await _helper.database;
    return db.update(
      'lessons',
      {'video_url': url},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
  }
}
