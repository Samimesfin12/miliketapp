import 'package:esl_learning_flutter/models/app_models.dart';

/// Runtime curriculum loaded from SQLite (categories + lessons).
class CurriculumData {
  const CurriculumData({
    required this.categories,
    required this.lessonsByCategory,
  });

  final List<Category> categories;
  final Map<String, List<LessonItem>> lessonsByCategory;

  int totalLessons() =>
      lessonsByCategory.values.fold<int>(0, (sum, list) => sum + list.length);

  int countCompletedInCurriculum(Set<String> completedLessonIds) {
    var n = 0;
    for (final list in lessonsByCategory.values) {
      for (final lesson in list) {
        if (completedLessonIds.contains(lesson.id)) n++;
      }
    }
    return n;
  }

  int countCompletedInCategory(
    String categoryId,
    Set<String> completedLessonIds,
  ) {
    final list = lessonsByCategory[categoryId];
    if (list == null) return 0;
    var n = 0;
    for (final lesson in list) {
      if (completedLessonIds.contains(lesson.id)) n++;
    }
    return n;
  }

  double progressFraction(Set<String> completedLessonIds) {
    final total = totalLessons();
    if (total == 0) return 0;
    return (countCompletedInCurriculum(completedLessonIds) / total).clamp(
      0.0,
      1.0,
    );
  }

  LessonItem? firstIncompleteLesson(Set<String> completedLessonIds) {
    for (final cat in categories) {
      final list = lessonsByCategory[cat.id] ?? const <LessonItem>[];
      for (final lesson in list) {
        if (!completedLessonIds.contains(lesson.id)) return lesson;
      }
    }
    return null;
  }

  Category categoryForLesson(LessonItem lesson) =>
      categories.firstWhere((c) => c.id == lesson.categoryId);

  String continueLessonChipLabel(String language, LessonItem lesson) {
    final cat = categoryForLesson(lesson);
    final list = lessonsByCategory[lesson.categoryId] ?? const <LessonItem>[];
    final idx = list.indexWhere((l) => l.id == lesson.id);
    final n = idx < 0 ? 1 : idx + 1;
    final title = language == 'en' ? cat.title : cat.titleAm;
    return 'Lesson $n: $title';
  }

  List<LessonItem> allLessonsFlat() =>
      lessonsByCategory.values.expand((list) => list).toList();
}
