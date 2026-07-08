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
        if (oldVersion < 2) {
          await db.update(
            'lessons',
            {'video_url': 'drive:1wQoueUDZVv_HBqmmcOmSIST3GqPtW9td'},
            where: 'id = ?',
            whereArgs: ['g2'],
          );
          await db.update(
            'dictionary_signs',
            {'video_url': 'drive:1wQoueUDZVv_HBqmmcOmSIST3GqPtW9td'},
            where: 'id = ?',
            whereArgs: ['dict_g2'],
          );
        }
        if (oldVersion < 3) {
          // Create the sign_templates table
          await db.execute('''
CREATE TABLE sign_templates (
  sign_id TEXT NOT NULL PRIMARY KEY,
  coordinates TEXT NOT NULL
);
''');
          // Seed the 'three' gesture coordinates
          await db.insert('sign_templates', {
            'sign_id': 'three',
            'coordinates': '0.0,0.0,0.0,0.2082,-0.1467,-0.0924,0.3498,-0.4279,-0.1198,0.2573,-0.6575,-0.1373,0.0932,-0.7832,-0.1597,0.2794,-0.9444,-0.0513,0.3541,-1.2841,-0.092,0.4008,-1.4843,-0.1326,0.4288,-1.671,-0.1656,0.1092,-0.9862,-0.0691,0.1407,-1.4013,-0.1055,0.1563,-1.6445,-0.1588,0.1661,-1.8622,-0.1956,-0.0496,-0.9128,-0.0982,-0.0701,-1.2798,-0.1924,-0.063,-1.5256,-0.2846,-0.0647,-1.7461,-0.3433,-0.2024,-0.7479,-0.1299,-0.1474,-0.9453,-0.2362,-0.0701,-0.8195,-0.2595,-0.017,-0.6689,-0.2651'
          });
        }
        if (oldVersion < 4) {
          // Seed the 'two' gesture coordinates
          await db.insert('sign_templates', {
            'sign_id': 'two',
            'coordinates': '0.0000,0.0000,0.0000,0.3447,-0.2075,-0.2052,0.5021,-0.5020,-0.2912,0.3141,-0.6513,-0.3822,0.0490,-0.7276,-0.4611,0.3087,-1.0378,-0.0962,0.3484,-1.4078,-0.2372,0.3498,-1.6420,-0.3391,0.3264,-1.8425,-0.4101,0.0000,-1.0000,-0.1310,-0.0747,-1.4165,-0.3022,-0.1283,-1.6817,-0.4300,-0.1838,-1.8955,-0.4998,-0.2570,-0.8474,-0.1946,-0.3524,-1.1058,-0.4869,-0.2076,-0.9279,-0.5727,-0.1020,-0.7663,-0.5505,-0.4633,-0.6203,-0.2722,-0.4221,-0.7420,-0.5457,-0.2322,-0.6069,-0.5954,-0.0915,-0.4742,-0.5688'
          });
        }
        if (oldVersion < 5) {
          const familyDrive = 'drive:1irPruo9Umo4Y7lQLCt9KBu7zqqs94llm';
          for (final lessonId in ['f2', 'f3']) {
            await db.update(
              'lessons',
              {'video_url': familyDrive},
              where: 'id = ?',
              whereArgs: [lessonId],
            );
            await db.update(
              'dictionary_signs',
              {'video_url': familyDrive},
              where: 'id = ?',
              whereArgs: ['dict_$lessonId'],
            );
          }
        }
        if (oldVersion < 6) {
          const familyVideos = <String, String>{
            'f1': 'drive:1sDiPwsldo5bNo6odsbfTCntrQUBDQgk_',
            'f2': 'drive:1ESRvlcuhz5iojfVVBGInRXBP46gISdVl',
            'f3': 'drive:1irPruo9Umo4Y7lQLCt9KBu7zqqs94llm',
          };
          for (final entry in familyVideos.entries) {
            await db.update(
              'lessons',
              {'video_url': entry.value},
              where: 'id = ?',
              whereArgs: [entry.key],
            );
            await db.update(
              'dictionary_signs',
              {'video_url': entry.value},
              where: 'id = ?',
              whereArgs: ['dict_${entry.key}'],
            );
          }
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE lessons ADD COLUMN cultural_note TEXT',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE lessons ADD COLUMN card_image_path TEXT',
          );
          await db.execute(
            'ALTER TABLE lessons ADD COLUMN show_on_culture_card INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 10) {
          // Convert all sign_id values to lowercase in the database to prevent case sensitivity issues
          await db.execute('UPDATE sign_templates SET sign_id = LOWER(sign_id)');
          // Ensure 'three' coordinates are properly seeded as lowercase
          await db.insert(
            'sign_templates',
            {
              'sign_id': 'three',
              'coordinates': '0.0,0.0,0.0,0.2082,-0.1467,-0.0924,0.3498,-0.4279,-0.1198,0.2573,-0.6575,-0.1373,0.0932,-0.7832,-0.1597,0.2794,-0.9444,-0.0513,0.3541,-1.2841,-0.092,0.4008,-1.4843,-0.1326,0.4288,-1.671,-0.1656,0.1092,-0.9862,-0.0691,0.1407,-1.4013,-0.1055,0.1563,-1.6445,-0.1588,0.1661,-1.8622,-0.1956,-0.0496,-0.9128,-0.0982,-0.0701,-1.2798,-0.1924,-0.063,-1.5256,-0.2846,-0.0647,-1.7461,-0.3433,-0.2024,-0.7479,-0.1299,-0.1474,-0.9453,-0.2362,-0.0701,-0.8195,-0.2595,-0.017,-0.6689,-0.2651'
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          // Ensure 'two' coordinates are properly seeded as lowercase
          await db.insert(
            'sign_templates',
            {
              'sign_id': 'two',
              'coordinates': '0.0000,0.0000,0.0000,0.3447,-0.2075,-0.2052,0.5021,-0.5020,-0.2912,0.3141,-0.6513,-0.3822,0.0490,-0.7276,-0.4611,0.3087,-1.0378,-0.0962,0.3484,-1.4078,-0.2372,0.3498,-1.6420,-0.3391,0.3264,-1.8425,-0.4101,0.0000,-1.0000,-0.1310,-0.0747,-1.4165,-0.3022,-0.1283,-1.6817,-0.4300,-0.1838,-1.8955,-0.4998,-0.2570,-0.8474,-0.1946,-0.3524,-1.1058,-0.4869,-0.2076,-0.9279,-0.5727,-0.1020,-0.7663,-0.5505,-0.4633,-0.6203,-0.2722,-0.4221,-0.7420,-0.5457,-0.2322,-0.6069,-0.5954,-0.0915,-0.4742,-0.5688'
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
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
  is_admin INTEGER NOT NULL DEFAULT 0,
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
  cultural_note TEXT,
  card_image_path TEXT,
  show_on_culture_card INTEGER NOT NULL DEFAULT 0,
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

    await db.execute('''
CREATE TABLE sign_templates (
  sign_id TEXT NOT NULL PRIMARY KEY,
  coordinates TEXT NOT NULL
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
    final batch = db.batch();

    for (var i = 0; i < app.categories.length; i++) {
      final c = app.categories[i];
      batch.insert('categories', {
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
        batch.insert('lessons', {
          'id': l.id,
          'category_id': categoryId,
          'sign_en': l.sign,
          'sign_am': l.signAm,
          'thumbnail_emoji': l.thumbnail,
          'video_url': l.videoUrl,
          'video_local_path': null,
          'locked': locked,
          'order_index': i,
        });

        batch.insert('dictionary_signs', {
          'id': 'dict_${l.id}',
          'sign_en': l.sign,
          'sign_am': l.signAm,
          'thumbnail_emoji': l.thumbnail,
          'video_url': l.videoUrl,
          'video_local_path': null,
        });
      }
    }

    // Preseed the sign 'three' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'three',
      'coordinates': '0.0,0.0,0.0,0.2082,-0.1467,-0.0924,0.3498,-0.4279,-0.1198,0.2573,-0.6575,-0.1373,0.0932,-0.7832,-0.1597,0.2794,-0.9444,-0.0513,0.3541,-1.2841,-0.092,0.4008,-1.4843,-0.1326,0.4288,-1.671,-0.1656,0.1092,-0.9862,-0.0691,0.1407,-1.4013,-0.1055,0.1563,-1.6445,-0.1588,0.1661,-1.8622,-0.1956,-0.0496,-0.9128,-0.0982,-0.0701,-1.2798,-0.1924,-0.063,-1.5256,-0.2846,-0.0647,-1.7461,-0.3433,-0.2024,-0.7479,-0.1299,-0.1474,-0.9453,-0.2362,-0.0701,-0.8195,-0.2595,-0.017,-0.6689,-0.2651'
    });

    // Preseed the sign 'two' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'two',
      'coordinates': '0.0000,0.0000,0.0000,0.3447,-0.2075,-0.2052,0.5021,-0.5020,-0.2912,0.3141,-0.6513,-0.3822,0.0490,-0.7276,-0.4611,0.3087,-1.0378,-0.0962,0.3484,-1.4078,-0.2372,0.3498,-1.6420,-0.3391,0.3264,-1.8425,-0.4101,0.0000,-1.0000,-0.1310,-0.0747,-1.4165,-0.3022,-0.1283,-1.6817,-0.4300,-0.1838,-1.8955,-0.4998,-0.2570,-0.8474,-0.1946,-0.3524,-1.1058,-0.4869,-0.2076,-0.9279,-0.5727,-0.1020,-0.7663,-0.5505,-0.4633,-0.6203,-0.2722,-0.4221,-0.7420,-0.5457,-0.2322,-0.6069,-0.5954,-0.0915,-0.4742,-0.5688'
    });

    await batch.commit(noResult: true);
  }

  Future<void> saveSignTemplate(String signId, List<double> coordinates) async {
    final db = await database;
    final coordString = coordinates.map((c) => c.toStringAsFixed(4)).join(',');
    await db.insert(
      'sign_templates',
      {
        'sign_id': signId.toLowerCase().trim(),
        'coordinates': coordString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<double>?> getSignTemplate(String signId) async {
    final db = await database;
    final maps = await db.query(
      'sign_templates',
      columns: ['coordinates'],
      where: 'sign_id = ?',
      whereArgs: [signId.toLowerCase().trim()],
    );
    if (maps.isEmpty) return null;
    
    final String coordString = maps.first['coordinates'] as String;
    return coordString.split(',').map((s) => double.tryParse(s) ?? 0.0).toList();
  }

  Future<List<Map<String, Object?>>> allSignTemplates() async {
    final db = await database;
    return db.query('sign_templates', orderBy: 'sign_id ASC');
  }

  Future<int> deleteSignTemplate(String signId) async {
    final db = await database;
    return db.delete(
      'sign_templates',
      where: 'sign_id = ?',
      whereArgs: [signId.toLowerCase().trim()],
    );
  }
}

int _colorToArgb32(Color c) {
  final a = (c.a * 255).round();
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return (a << 24) | (r << 16) | (g << 8) | b;
}
