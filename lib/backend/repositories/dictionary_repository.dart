import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// Dictionary search (LIKE on EN + Amharic) and favourites junction.
final class DictionaryRepository {
  DictionaryRepository(this._helper);
  final SQLiteHelper _helper;

  Future<List<Map<String, Object?>>> search(String query) async {
    final db = await _helper.database;
    final q = '%${query.trim()}%';
    return db.query(
      'dictionary_signs',
      where: 'sign_en LIKE ? OR sign_am LIKE ?',
      whereArgs: [q, q],
      orderBy: 'sign_en ASC',
    );
  }

  Future<List<Map<String, Object?>>> allSigns() async {
    final db = await _helper.database;
    return db.query('dictionary_signs', orderBy: 'sign_en ASC');
  }

  Future<int> addFavourite(int userId, String dictionarySignId) async {
    final db = await _helper.database;
    return db.insert('favourites', {
      'user_id': userId,
      'dictionary_sign_id': dictionarySignId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> removeFavourite(int userId, String dictionarySignId) async {
    final db = await _helper.database;
    return db.delete(
      'favourites',
      where: 'user_id = ? AND dictionary_sign_id = ?',
      whereArgs: [userId, dictionarySignId],
    );
  }

  Future<Set<String>> favouriteSignIds(int userId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'favourites',
      columns: ['dictionary_sign_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((e) => e['dictionary_sign_id']! as String).toSet();
  }

  Future<void> upsertForLesson({
    required String lessonId,
    required String signEn,
    required String signAm,
    required String thumbnailEmoji,
    String? videoUrl,
  }) async {
    final db = await _helper.database;
    final dictId = 'dict_$lessonId';
    await db.insert(
      'dictionary_signs',
      {
        'id': dictId,
        'sign_en': signEn,
        'sign_am': signAm,
        'thumbnail_emoji': thumbnailEmoji,
        'video_url': videoUrl,
        'video_local_path': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteForLesson(String lessonId) async {
    final db = await _helper.database;
    return db.delete(
      'dictionary_signs',
      where: 'id = ?',
      whereArgs: ['dict_$lessonId'],
    );
  }
}
