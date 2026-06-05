import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/models/app_models.dart';

/// Lesson queries, lock updates, and local video path updates.
final class LessonRepository {
  LessonRepository(this._helper);
  final SQLiteHelper _helper;

  static LessonItem lessonFromRow(Map<String, Object?> row) {
    return LessonItem(
      id: row['id']! as String,
      categoryId: row['category_id']! as String,
      sign: row['sign_en']! as String,
      signAm: row['sign_am']! as String,
      thumbnail: row['thumbnail_emoji']! as String,
      videoUrl: row['video_url'] as String?,
      videoLocalPath: row['video_local_path'] as String?,
      culturalNote: row['cultural_note'] as String?,
      cardImagePath: row['card_image_path'] as String?,
      showOnCultureCard: (row['show_on_culture_card'] as int? ?? 0) == 1,
    );
  }

  Future<List<LessonItem>> cultureCardSigns() async {
    final db = await _helper.database;
    final rows = await db.query(
      'lessons',
      where: 'show_on_culture_card = 1',
      orderBy: 'order_index ASC',
    );
    return rows.map(lessonFromRow).toList();
  }

  Future<List<LessonItem>> allLessons() async {
    final db = await _helper.database;
    final rows = await db.query('lessons', orderBy: 'order_index ASC');
    return rows.map(lessonFromRow).toList();
  }

  Future<List<LessonItem>> lessonsForCategoryAsModels(String categoryId) async {
    final rows = await lessonsForCategory(categoryId);
    return rows.map(lessonFromRow).toList();
  }

  Future<int> countLessons() async {
    final db = await _helper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM lessons');
    return Sqflite.firstIntValue(result) ?? 0;
  }

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

  Future<int> nextOrderIndex(String categoryId) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT MAX(order_index) AS m FROM lessons WHERE category_id = ?',
      [categoryId],
    );
    final max = result.first['m'] as int?;
    return (max ?? -1) + 1;
  }

  Future<String> generateLessonId(String categoryId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'lessons',
      columns: ['id'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    const knownPrefixes = {
      'greetings': 'g',
      'family': 'f',
      'food': 'fo',
      'shopping': 's',
      'emergency': 'e',
      'numbers': 'n',
    };

    if (knownPrefixes.containsKey(categoryId)) {
      final prefix = knownPrefixes[categoryId]!;
      var maxNum = 0;
      for (final row in rows) {
        final id = row['id']! as String;
        final match =
            RegExp('^${RegExp.escape(prefix)}(\\d+)\$').firstMatch(id);
        if (match != null) {
          final n = int.tryParse(match.group(1)!) ?? 0;
          if (n > maxNum) maxNum = n;
        }
      }
      return '$prefix${maxNum + 1}';
    }

    var maxNum = 0;
    final prefix = '${categoryId}_';
    for (final row in rows) {
      final id = row['id']! as String;
      if (id.startsWith(prefix)) {
        final n = int.tryParse(id.substring(prefix.length)) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return '$prefix${maxNum + 1}';
  }

  Future<void> insertLesson({
    required String id,
    required String categoryId,
    required String signEn,
    required String signAm,
    required String thumbnailEmoji,
    String? videoUrl,
    String? culturalNote,
    String? cardImagePath,
    bool showOnCultureCard = false,
    bool locked = true,
    required int orderIndex,
  }) async {
    final db = await _helper.database;
    await db.insert('lessons', {
      'id': id,
      'category_id': categoryId,
      'sign_en': signEn,
      'sign_am': signAm,
      'thumbnail_emoji': thumbnailEmoji,
      'video_url': videoUrl,
      'video_local_path': null,
      'locked': locked ? 1 : 0,
      'order_index': orderIndex,
      'cultural_note': culturalNote,
      'card_image_path': cardImagePath,
      'show_on_culture_card': showOnCultureCard ? 1 : 0,
    });
  }

  Future<int> updateLesson({
    required String id,
    required String signEn,
    required String signAm,
    required String thumbnailEmoji,
    String? videoUrl,
    String? culturalNote,
    String? cardImagePath,
    bool? showOnCultureCard,
    bool clearCardImagePath = false,
    String? categoryId,
    bool? locked,
  }) async {
    final db = await _helper.database;
    final map = <String, Object?>{
      'sign_en': signEn,
      'sign_am': signAm,
      'thumbnail_emoji': thumbnailEmoji,
      'video_url': videoUrl,
      'cultural_note': culturalNote,
    };
    if (clearCardImagePath) {
      map['card_image_path'] = null;
    } else if (cardImagePath != null) {
      map['card_image_path'] = cardImagePath;
    }
    if (showOnCultureCard != null) {
      map['show_on_culture_card'] = showOnCultureCard ? 1 : 0;
    }
    if (categoryId != null) map['category_id'] = categoryId;
    if (locked != null) map['locked'] = locked ? 1 : 0;
    return db.update('lessons', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteLesson(String lessonId) async {
    final db = await _helper.database;
    return db.delete('lessons', where: 'id = ?', whereArgs: [lessonId]);
  }

  Future<bool> isLocked(String lessonId) async {
    final row = await lessonById(lessonId);
    if (row == null) return true;
    return (row['locked'] as int? ?? 1) == 1;
  }
}
