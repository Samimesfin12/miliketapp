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
        if (oldVersion < 11) {
          await db.insert(
            'sign_templates',
            {
              'sign_id': 'zero',
              'coordinates': '0.0000,0.0000,0.0000,0.4773,-0.3232,0.1950,0.6753,-0.6703,0.2473,0.8544,-0.9261,0.2018,0.9947,-1.1707,0.1602,0.1180,-0.9991,0.4617,0.3375,-1.3423,0.3902,0.6829,-1.3729,0.2642,0.9117,-1.3096,0.1855,-0.0000,-1.0000,0.2682,0.2761,-1.4327,0.1862,0.6718,-1.4477,0.0544,0.9159,-1.3319,-0.0188,-0.0643,-0.9710,0.0536,0.2164,-1.4165,-0.0100,0.6269,-1.4386,-0.0655,0.8801,-1.3319,-0.0888,-0.0450,-0.9142,-0.1591,0.2477,-1.2647,-0.1991,0.5779,-1.3263,-0.1989,0.8166,-1.2833,-0.1883'
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (oldVersion < 12) {
          for (final entry in {
            'one': '0.0000,0.0000,0.0000,0.4132,-0.2795,-0.0701,0.6774,-0.5812,-0.1715,0.8573,-0.8155,-0.3039,0.9031,-1.0574,-0.4281,0.2272,-1.0517,-0.0955,0.3382,-1.4067,-0.2586,0.4114,-1.6420,-0.3569,0.4362,-1.8445,-0.4246,0.0000,-1.0000,-0.1876,0.4246,-1.2541,-0.4457,0.6668,-1.0304,-0.5040,0.6951,-0.8225,-0.4828,-0.1462,-0.8765,-0.2926,0.3663,-1.0122,-0.5471,0.5525,-0.7608,-0.4879,0.5404,-0.5755,-0.3789,-0.2234,-0.7017,-0.4074,0.2240,-0.8180,-0.5704,0.3830,-0.6504,-0.5100,0.3616,-0.5004,-0.4201',
            'three': '0.0000,0.0000,0.0000,0.4358,-0.2650,-0.2083,0.6637,-0.6737,-0.2608,0.7673,-1.0155,-0.3177,0.9538,-1.2675,-0.3639,0.2900,-1.0497,-0.0618,0.3305,-1.4213,-0.1901,0.3210,-1.6563,-0.2790,0.3023,-1.8604,-0.3416,-0.0000,-1.0000,-0.0748,-0.0949,-1.3921,-0.2597,-0.1508,-1.6584,-0.3848,-0.2004,-1.8815,-0.4487,-0.2633,-0.8519,-0.1193,-0.3239,-1.0691,-0.4227,-0.1540,-0.8567,-0.4667,-0.0373,-0.6839,-0.4056,-0.5085,-0.6537,-0.1791,-0.5356,-0.8207,-0.4276,-0.3803,-0.6894,-0.4396,-0.2647,-0.5692,-0.3869',
            'four': '0.0000,0.0000,0.0000,0.2958,-0.2461,-0.1807,0.4929,-0.5726,-0.2680,0.2880,-0.6997,-0.3492,0.0176,-0.6577,-0.4339,0.2866,-1.0281,-0.1570,0.3502,-1.3948,-0.2951,0.3632,-1.6289,-0.4110,0.3520,-1.8313,-0.4999,0.0000,-1.0000,-0.1876,-0.0195,-1.4024,-0.3020,-0.0485,-1.6662,-0.4119,-0.0948,-1.8796,-0.4939,-0.2379,-0.8689,-0.2422,-0.3820,-1.1978,-0.3617,-0.4769,-1.4198,-0.4744,-0.5591,-1.6118,-0.5530,-0.4521,-0.6502,-0.3157,-0.6356,-0.8601,-0.4277,-0.7605,-1.0066,-0.4918,-0.8696,-1.1510,-0.5364',
            'five': '0.0000,0.0000,0.0000,0.3787,-0.2649,-0.1966,0.6481,-0.6202,-0.2764,0.8260,-0.9342,-0.3448,0.9938,-1.1784,-0.4071,0.2670,-1.0234,-0.0928,0.3199,-1.3699,-0.2021,0.3250,-1.5832,-0.3089,0.3140,-1.7719,-0.3928,0.0000,-1.0000,-0.0932,-0.0075,-1.3817,-0.1866,-0.0213,-1.6209,-0.2856,-0.0498,-1.8202,-0.3615,-0.2463,-0.8919,-0.1250,-0.3514,-1.2186,-0.2300,-0.4068,-1.4367,-0.3183,-0.4508,-1.6346,-0.3816,-0.4792,-0.7159,-0.1784,-0.6332,-0.9401,-0.2842,-0.7230,-1.0979,-0.3391,-0.7895,-1.2624,-0.3747',
          }.entries) {
            await db.insert(
              'sign_templates',
              {
                'sign_id': entry.key,
                'coordinates': entry.value,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        if (oldVersion < 13) {
          for (final entry in {
            'fd1':
                'Injera is Ethiopia\'s staple flatbread made from teff. Meals are shared on a large injera laid on a communal plate.',
            'fd4':
                'Ethiopian porridge (genfo) is a warm, nourishing breakfast food enjoyed by families across the country.',
            'fd5':
                'Ambasha is a lightly sweet Ethiopian celebration bread, often served during holidays and family gatherings.',
            'fd6':
                'Shiro is a creamy stew made from powdered chickpeas or broad beans, a beloved fasting and everyday dish.',
            'fd8':
                'Kitfo and tere siga are treasured Ethiopian dishes of seasoned raw meat, often served at special gatherings.',
          }.entries) {
            await db.update(
              'lessons',
              {
                'cultural_note': entry.value,
                'show_on_culture_card': 1,
              },
              where: 'id = ?',
              whereArgs: [entry.key],
            );
          }
        }
        if (oldVersion < 14) {
          for (final entry in {
            'six': '0.0000,0.0000,0.0000,0.3197,-0.2427,-0.1698,0.5133,-0.5817,-0.2136,0.3856,-0.8210,-0.2484,0.1577,-0.9517,-0.2799,0.2587,-1.0173,-0.0174,0.3367,-1.3643,-0.0705,0.3692,-1.5800,-0.1379,0.3844,-1.7712,-0.1971,0.0000,-1.0000,-0.0317,-0.0375,-1.3907,-0.0681,-0.0568,-1.6206,-0.1387,-0.0657,-1.8191,-0.2000,-0.2219,-0.8959,-0.0763,-0.2735,-1.2463,-0.1897,-0.2314,-1.4774,-0.3036,-0.1954,-1.6621,-0.3848,-0.4299,-0.7205,-0.1362,-0.3887,-0.9962,-0.2790,-0.2063,-1.0285,-0.3219,-0.0413,-0.9972,-0.3427',
            'seven': '0.0000,0.0000,0.0000,0.3197,-0.2427,-0.1698,0.5133,-0.5817,-0.2136,0.3856,-0.8210,-0.2484,0.1577,-0.9517,-0.2799,0.2587,-1.0173,-0.0174,0.3367,-1.3643,-0.0705,0.3692,-1.5800,-0.1379,0.3844,-1.7712,-0.1971,0.0000,-1.0000,-0.0317,-0.0375,-1.3907,-0.0681,-0.0568,-1.6206,-0.1387,-0.0657,-1.8191,-0.2000,-0.2219,-0.8959,-0.0763,-0.2735,-1.2463,-0.1897,-0.2314,-1.4774,-0.3036,-0.1954,-1.6621,-0.3848,-0.4299,-0.7205,-0.1362,-0.3887,-0.9962,-0.2790,-0.2063,-1.0285,-0.3219,-0.0413,-0.9972,-0.3427',
            'zero': '0.0000,0.0000,0.0000,0.4160,-0.3242,0.0640,0.5934,-0.6948,0.0872,0.7377,-0.9801,0.0418,0.8311,-1.2584,0.0037,0.1291,-0.9927,0.3545,0.2278,-1.3121,0.2602,0.5136,-1.3956,0.1259,0.7250,-1.3872,0.0450,-0.0000,-1.0000,0.2291,0.0774,-1.4091,0.1020,0.4290,-1.4861,-0.0526,0.6926,-1.4176,-0.1322,-0.1323,-0.9739,0.0715,-0.0460,-1.4052,-0.0546,0.3447,-1.4811,-0.1596,0.6390,-1.4099,-0.1992,-0.2258,-0.9232,-0.0901,-0.0637,-1.2858,-0.1933,0.2558,-1.3875,-0.2422,0.5306,-1.3674,-0.2551',
            'eight': '0.0000,0.0000,0.0000,0.3856,-0.2950,0.0160,0.5607,-0.6660,0.0434,0.6670,-0.9451,0.0128,0.7046,-1.2216,-0.0131,0.1329,-0.9901,0.3951,0.1514,-1.3088,0.3689,0.2496,-1.5021,0.2836,0.3253,-1.6316,0.2198,-0.0000,-1.0000,0.2819,0.0168,-1.3634,0.1562,0.2636,-1.4798,-0.0203,0.4713,-1.4527,-0.1041,-0.1502,-0.9771,0.1350,-0.1278,-1.3412,0.0418,0.1358,-1.4670,-0.0634,0.3660,-1.4792,-0.1080,-0.2962,-0.9150,-0.0241,-0.3624,-1.2297,-0.0645,-0.2777,-1.4562,-0.1034,-0.1543,-1.6199,-0.1277',
            'nine': '0.0000,0.0000,0.0000,0.3950,-0.2616,-0.0183,0.6031,-0.6062,-0.0101,0.7479,-0.8795,-0.0470,0.7803,-1.1515,-0.0686,0.1553,-0.9497,0.3024,0.2875,-1.2423,0.1596,0.4994,-1.2908,-0.0090,0.6727,-1.2642,-0.0950,0.0000,-1.0000,0.2176,0.0865,-1.3547,0.1681,0.2745,-1.5685,0.0733,0.4619,-1.7164,0.0087,-0.1744,-0.9825,0.0787,-0.1196,-1.3452,0.0366,0.0184,-1.5845,-0.0017,0.1747,-1.7686,-0.0253,-0.3460,-0.9103,-0.0819,-0.3324,-1.2228,-0.1033,-0.2716,-1.4436,-0.0901,-0.1713,-1.6267,-0.0776',
          }.entries) {
            await db.insert(
              'sign_templates',
              {
                'sign_id': entry.key,
                'coordinates': entry.value,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
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
          'cultural_note': l.culturalNote,
          'card_image_path': l.cardImagePath,
          'show_on_culture_card': l.showOnCultureCard ? 1 : 0,
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
      'coordinates': '0.0000,0.0000,0.0000,0.4358,-0.2650,-0.2083,0.6637,-0.6737,-0.2608,0.7673,-1.0155,-0.3177,0.9538,-1.2675,-0.3639,0.2900,-1.0497,-0.0618,0.3305,-1.4213,-0.1901,0.3210,-1.6563,-0.2790,0.3023,-1.8604,-0.3416,-0.0000,-1.0000,-0.0748,-0.0949,-1.3921,-0.2597,-0.1508,-1.6584,-0.3848,-0.2004,-1.8815,-0.4487,-0.2633,-0.8519,-0.1193,-0.3239,-1.0691,-0.4227,-0.1540,-0.8567,-0.4667,-0.0373,-0.6839,-0.4056,-0.5085,-0.6537,-0.1791,-0.5356,-0.8207,-0.4276,-0.3803,-0.6894,-0.4396,-0.2647,-0.5692,-0.3869'
    });

    // Preseed the sign 'two' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'two',
      'coordinates': '0.0000,0.0000,0.0000,0.3447,-0.2075,-0.2052,0.5021,-0.5020,-0.2912,0.3141,-0.6513,-0.3822,0.0490,-0.7276,-0.4611,0.3087,-1.0378,-0.0962,0.3484,-1.4078,-0.2372,0.3498,-1.6420,-0.3391,0.3264,-1.8425,-0.4101,0.0000,-1.0000,-0.1310,-0.0747,-1.4165,-0.3022,-0.1283,-1.6817,-0.4300,-0.1838,-1.8955,-0.4998,-0.2570,-0.8474,-0.1946,-0.3524,-1.1058,-0.4869,-0.2076,-0.9279,-0.5727,-0.1020,-0.7663,-0.5505,-0.4633,-0.6203,-0.2722,-0.4221,-0.7420,-0.5457,-0.2322,-0.6069,-0.5954,-0.0915,-0.4742,-0.5688'
    });

    // Preseed the sign 'zero' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'zero',
      'coordinates': '0.0000,0.0000,0.0000,0.4160,-0.3242,0.0640,0.5934,-0.6948,0.0872,0.7377,-0.9801,0.0418,0.8311,-1.2584,0.0037,0.1291,-0.9927,0.3545,0.2278,-1.3121,0.2602,0.5136,-1.3956,0.1259,0.7250,-1.3872,0.0450,-0.0000,-1.0000,0.2291,0.0774,-1.4091,0.1020,0.4290,-1.4861,-0.0526,0.6926,-1.4176,-0.1322,-0.1323,-0.9739,0.0715,-0.0460,-1.4052,-0.0546,0.3447,-1.4811,-0.1596,0.6390,-1.4099,-0.1992,-0.2258,-0.9232,-0.0901,-0.0637,-1.2858,-0.1933,0.2558,-1.3875,-0.2422,0.5306,-1.3674,-0.2551'
    });

    // Preseed the sign 'one' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'one',
      'coordinates': '0.0000,0.0000,0.0000,0.4132,-0.2795,-0.0701,0.6774,-0.5812,-0.1715,0.8573,-0.8155,-0.3039,0.9031,-1.0574,-0.4281,0.2272,-1.0517,-0.0955,0.3382,-1.4067,-0.2586,0.4114,-1.6420,-0.3569,0.4362,-1.8445,-0.4246,0.0000,-1.0000,-0.1876,0.4246,-1.2541,-0.4457,0.6668,-1.0304,-0.5040,0.6951,-0.8225,-0.4828,-0.1462,-0.8765,-0.2926,0.3663,-1.0122,-0.5471,0.5525,-0.7608,-0.4879,0.5404,-0.5755,-0.3789,-0.2234,-0.7017,-0.4074,0.2240,-0.8180,-0.5704,0.3830,-0.6504,-0.5100,0.3616,-0.5004,-0.4201'
    });

    // Preseed the sign 'four' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'four',
      'coordinates': '0.0000,0.0000,0.0000,0.2958,-0.2461,-0.1807,0.4929,-0.5726,-0.2680,0.2880,-0.6997,-0.3492,0.0176,-0.6577,-0.4339,0.2866,-1.0281,-0.1570,0.3502,-1.3948,-0.2951,0.3632,-1.6289,-0.4110,0.3520,-1.8313,-0.4999,0.0000,-1.0000,-0.1876,-0.0195,-1.4024,-0.3020,-0.0485,-1.6662,-0.4119,-0.0948,-1.8796,-0.4939,-0.2379,-0.8689,-0.2422,-0.3820,-1.1978,-0.3617,-0.4769,-1.4198,-0.4744,-0.5591,-1.6118,-0.5530,-0.4521,-0.6502,-0.3157,-0.6356,-0.8601,-0.4277,-0.7605,-1.0066,-0.4918,-0.8696,-1.1510,-0.5364'
    });

    // Preseed the sign 'five' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'five',
      'coordinates': '0.0000,0.0000,0.0000,0.3787,-0.2649,-0.1966,0.6481,-0.6202,-0.2764,0.8260,-0.9342,-0.3448,0.9938,-1.1784,-0.4071,0.2670,-1.0234,-0.0928,0.3199,-1.3699,-0.2021,0.3250,-1.5832,-0.3089,0.3140,-1.7719,-0.3928,0.0000,-1.0000,-0.0932,-0.0075,-1.3817,-0.1866,-0.0213,-1.6209,-0.2856,-0.0498,-1.8202,-0.3615,-0.2463,-0.8919,-0.1250,-0.3514,-1.2186,-0.2300,-0.4068,-1.4367,-0.3183,-0.4508,-1.6346,-0.3816,-0.4792,-0.7159,-0.1784,-0.6332,-0.9401,-0.2842,-0.7230,-1.0979,-0.3391,-0.7895,-1.2624,-0.3747'
    });

    // Preseed the sign 'six' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'six',
      'coordinates': '0.0000,0.0000,0.0000,0.3197,-0.2427,-0.1698,0.5133,-0.5817,-0.2136,0.3856,-0.8210,-0.2484,0.1577,-0.9517,-0.2799,0.2587,-1.0173,-0.0174,0.3367,-1.3643,-0.0705,0.3692,-1.5800,-0.1379,0.3844,-1.7712,-0.1971,0.0000,-1.0000,-0.0317,-0.0375,-1.3907,-0.0681,-0.0568,-1.6206,-0.1387,-0.0657,-1.8191,-0.2000,-0.2219,-0.8959,-0.0763,-0.2735,-1.2463,-0.1897,-0.2314,-1.4774,-0.3036,-0.1954,-1.6621,-0.3848,-0.4299,-0.7205,-0.1362,-0.3887,-0.9962,-0.2790,-0.2063,-1.0285,-0.3219,-0.0413,-0.9972,-0.3427'
    });

    // Preseed the sign 'seven' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'seven',
      'coordinates': '0.0000,0.0000,0.0000,0.3197,-0.2427,-0.1698,0.5133,-0.5817,-0.2136,0.3856,-0.8210,-0.2484,0.1577,-0.9517,-0.2799,0.2587,-1.0173,-0.0174,0.3367,-1.3643,-0.0705,0.3692,-1.5800,-0.1379,0.3844,-1.7712,-0.1971,0.0000,-1.0000,-0.0317,-0.0375,-1.3907,-0.0681,-0.0568,-1.6206,-0.1387,-0.0657,-1.8191,-0.2000,-0.2219,-0.8959,-0.0763,-0.2735,-1.2463,-0.1897,-0.2314,-1.4774,-0.3036,-0.1954,-1.6621,-0.3848,-0.4299,-0.7205,-0.1362,-0.3887,-0.9962,-0.2790,-0.2063,-1.0285,-0.3219,-0.0413,-0.9972,-0.3427'
    });

    // Preseed the sign 'eight' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'eight',
      'coordinates': '0.0000,0.0000,0.0000,0.3856,-0.2950,0.0160,0.5607,-0.6660,0.0434,0.6670,-0.9451,0.0128,0.7046,-1.2216,-0.0131,0.1329,-0.9901,0.3951,0.1514,-1.3088,0.3689,0.2496,-1.5021,0.2836,0.3253,-1.6316,0.2198,-0.0000,-1.0000,0.2819,0.0168,-1.3634,0.1562,0.2636,-1.4798,-0.0203,0.4713,-1.4527,-0.1041,-0.1502,-0.9771,0.1350,-0.1278,-1.3412,0.0418,0.1358,-1.4670,-0.0634,0.3660,-1.4792,-0.1080,-0.2962,-0.9150,-0.0241,-0.3624,-1.2297,-0.0645,-0.2777,-1.4562,-0.1034,-0.1543,-1.6199,-0.1277'
    });

    // Preseed the sign 'nine' coordinates template
    batch.insert('sign_templates', {
      'sign_id': 'nine',
      'coordinates': '0.0000,0.0000,0.0000,0.3950,-0.2616,-0.0183,0.6031,-0.6062,-0.0101,0.7479,-0.8795,-0.0470,0.7803,-1.1515,-0.0686,0.1553,-0.9497,0.3024,0.2875,-1.2423,0.1596,0.4994,-1.2908,-0.0090,0.6727,-1.2642,-0.0950,0.0000,-1.0000,0.2176,0.0865,-1.3547,0.1681,0.2745,-1.5685,0.0733,0.4619,-1.7164,0.0087,-0.1744,-0.9825,0.0787,-0.1196,-1.3452,0.0366,0.0184,-1.5845,-0.0017,0.1747,-1.7686,-0.0253,-0.3460,-0.9103,-0.0819,-0.3324,-1.2228,-0.1033,-0.2716,-1.4436,-0.0901,-0.1713,-1.6267,-0.0776'
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
