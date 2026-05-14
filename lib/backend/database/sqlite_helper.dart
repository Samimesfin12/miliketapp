import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/db_constants.dart';
import 'package:esl_learning_flutter/data/app_data.dart' as app;

/// Singleton owning the single SQLite connection for miliketapp.db.
/// Enforces [PRAGMA foreign_keys = ON] and exposes [transaction] for atomic writes.
final class SQLiteHelper {
  SQLiteHelper._();
  static final SQLiteHelper instance = SQLiteHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, DbConstants.fileName);
  }

  Future<Database> _open() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: DbConstants.schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedInitialData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Future migrations: bump [DbConstants.schemaVersion] and migrate here.
      },
    );
  }

  /// Run a callback inside a single SQLite transaction (atomic commit/rollback).
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  language_preference TEXT NOT NULL DEFAULT 'en',
  signs_learned INTEGER NOT NULL DEFAULT 0,
  day_streak INTEGER NOT NULL DEFAULT 0,
  total_practiced INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_login_at TEXT
);
''');

    await db.execute('''
CREATE TABLE categories (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  title_am TEXT NOT NULL,
  icon TEXT NOT NULL,
  color_argb INTEGER NOT NULL,
  description TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);
''');

    await db.execute('''
CREATE TABLE lessons (
  id TEXT NOT NULL PRIMARY KEY,
  category_id TEXT NOT NULL,
  sign_en TEXT NOT NULL,
  sign_am TEXT NOT NULL,
  thumbnail_emoji TEXT NOT NULL,
  video_url TEXT,
  video_local_path TEXT,
  locked INTEGER NOT NULL DEFAULT 1,
  order_index INTEGER NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  lesson_id TEXT NOT NULL,
  completed_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (lesson_id) REFERENCES lessons (id) ON DELETE CASCADE,
  UNIQUE (user_id, lesson_id)
);
''');

    await db.execute('''
CREATE TABLE quiz_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  category_id TEXT NOT NULL,
  score INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  taken_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE ai_feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  target_sign TEXT NOT NULL,
  predicted_sign TEXT NOT NULL,
  confidence REAL NOT NULL,
  is_correct INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);
''');

    await db.execute('''
CREATE TABLE dictionary_signs (
  id TEXT NOT NULL PRIMARY KEY,
  sign_en TEXT NOT NULL,
  sign_am TEXT NOT NULL,
  thumbnail_emoji TEXT NOT NULL,
  video_url TEXT,
  video_local_path TEXT
);
''');

    await db.execute('''
CREATE TABLE favourites (
  user_id INTEGER NOT NULL,
  dictionary_sign_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, dictionary_sign_id),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (dictionary_sign_id) REFERENCES dictionary_signs (id) ON DELETE CASCADE
);
''');

    await db.execute('CREATE INDEX idx_progress_user ON progress (user_id);');
    await db.execute(
      'CREATE INDEX idx_lessons_category ON lessons (category_id, order_index);',
    );
    await db.execute(
      'CREATE INDEX idx_dictionary_sign_en ON dictionary_signs (sign_en);',
    );
    await db.execute(
      'CREATE INDEX idx_dictionary_sign_am ON dictionary_signs (sign_am);',
    );
  }

  /// Seeds categories, lessons, and dictionary rows from existing in-app curriculum.
  static Future<void> _seedInitialData(Database db) async {
    for (var i = 0; i < app.categories.length; i++) {
      final c = app.categories[i];
      await db.insert('categories', {
        'id': c.id,
        'title': c.title,
        'title_am': c.titleAm,
        'icon': c.icon,
        'color_argb': _colorToArgb32(c.color),
        'description': c.description,
        'sort_order': i,
      });
    }

    for (final entry in app.lessonsByCategory.entries) {
      final categoryId = entry.key;
      final lessons = entry.value;
      for (var i = 0; i < lessons.length; i++) {
        final l = lessons[i];
        final locked = i == 0 ? 0 : 1;
        await db.insert('lessons', {
          'id': l.id,
          'category_id': categoryId,
          'sign_en': l.sign,
          'sign_am': l.signAm,
          'thumbnail_emoji': l.thumbnail,
          'video_url': null,
          'video_local_path': null,
          'locked': locked,
          'order_index': i,
        });

        await db.insert('dictionary_signs', {
          'id': 'dict_${l.id}',
          'sign_en': l.sign,
          'sign_am': l.signAm,
          'thumbnail_emoji': l.thumbnail,
          'video_url': null,
          'video_local_path': null,
        });
      }
    }
  }
}

int _colorToArgb32(Color c) {
  final a = (c.a * 255).round();
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return (a << 24) | (r << 16) | (g << 8) | b;
}
