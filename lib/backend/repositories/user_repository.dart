import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

/// CRUD on [users] and bcrypt password checks (work factor 10).
final class UserRepository {
  UserRepository(this._helper);
  final SQLiteHelper _helper;

  static const int _bcryptLogRounds = 10;

  String hashPassword(String plain) =>
      BCrypt.hashpw(plain, BCrypt.gensalt(logRounds: _bcryptLogRounds));

  bool verifyPassword(String plain, String passwordHash) =>
      BCrypt.checkpw(plain, passwordHash);

  Future<int> insertUser({
    required String email,
    required String passwordPlain,
    required String fullName,
    String languagePreference = 'en',
  }) async {
    final db = await _helper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('users', {
      'email': email.toLowerCase().trim(),
      'password_hash': hashPassword(passwordPlain),
      'full_name': fullName,
      'language_preference': languagePreference,
      'signs_learned': 0,
      'day_streak': 0,
      'total_practiced': 0,
      'is_admin': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> allUsers() async {
    final db = await _helper.database;
    return db.query('users', orderBy: 'created_at DESC');
  }

  Future<int> countUsers() async {
    final db = await _helper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM users');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, Object?>?> getUserByEmail(String email) async {
    final db = await _helper.database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, Object?>?> getUserById(int id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> updateLanguage(int userId, String language) async {
    final db = await _helper.database;
    return db.update(
      'users',
      {
        'language_preference': language,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateCounters({
    required int userId,
    int? signsLearned,
    int? dayStreak,
    int? totalPracticed,
  }) async {
    final db = await _helper.database;
    final map = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (signsLearned != null) map['signs_learned'] = signsLearned;
    if (dayStreak != null) map['day_streak'] = dayStreak;
    if (totalPracticed != null) map['total_practiced'] = totalPracticed;
    return db.update('users', map, where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> touchLogin(int userId) async {
    final db = await _helper.database;
    return db.update(
      'users',
      {
        'last_login_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Example atomic write: mark login + bump total_practiced inside one transaction.
  Future<void> recordLoginSession(int userId) async {
    await _helper.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.rawUpdate(
        '''
UPDATE users SET last_login_at = ?, updated_at = ?, total_practiced = total_practiced + 1
WHERE id = ?
''',
        [now, now, userId],
      );
    });
  }
}
