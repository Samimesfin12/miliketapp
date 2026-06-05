import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';
import 'package:esl_learning_flutter/models/app_models.dart';

/// CRUD on [categories] table.
final class CategoryRepository {
  CategoryRepository(this._helper);
  final SQLiteHelper _helper;

  Future<List<Category>> allCategories() async {
    final db = await _helper.database;
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(_categoryFromRow).toList();
  }

  Future<int> insertCategory({
    required String id,
    required String title,
    required String titleAm,
    required String icon,
    required int colorArgb,
    required String description,
    required int sortOrder,
  }) async {
    final db = await _helper.database;
    return db.insert('categories', {
      'id': id,
      'title': title,
      'title_am': titleAm,
      'icon': icon,
      'color_argb': colorArgb,
      'description': description,
      'sort_order': sortOrder,
    });
  }

  Future<int> updateCategory({
    required String id,
    required String title,
    required String titleAm,
    required String icon,
    required int colorArgb,
    required String description,
    required int sortOrder,
  }) async {
    final db = await _helper.database;
    return db.update(
      'categories',
      {
        'title': title,
        'title_am': titleAm,
        'icon': icon,
        'color_argb': colorArgb,
        'description': description,
        'sort_order': sortOrder,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await _helper.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> sortOrderFor(String id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'categories',
      columns: ['sort_order'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['sort_order'] as int? ?? 0;
  }

  Future<Category?> categoryById(String id) async {
    final db = await _helper.database;
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _categoryFromRow(rows.first);
  }

  Future<int> nextSortOrder() async {
    final db = await _helper.database;
    final result =
        await db.rawQuery('SELECT MAX(sort_order) AS m FROM categories');
    final max = result.first['m'] as int?;
    return (max ?? -1) + 1;
  }

  Future<String> generateUniqueCategoryId(String titleEn) async {
    var slug = titleEn
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    if (slug.isEmpty) slug = 'category';

    final db = await _helper.database;
    var candidate = slug;
    var suffix = 1;
    while (true) {
      final rows = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (rows.isEmpty) return candidate;
      suffix++;
      candidate = '${slug}_$suffix';
    }
  }

  Future<int> countCategories() async {
    final db = await _helper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM categories');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Category categoryFromRow(Map<String, Object?> row) =>
      _categoryFromRow(row);

  static Category _categoryFromRow(Map<String, Object?> row) {
    return Category(
      id: row['id']! as String,
      title: row['title']! as String,
      titleAm: row['title_am']! as String,
      icon: row['icon']! as String,
      color: Color(row['color_argb']! as int),
      description: row['description']! as String,
    );
  }
}
