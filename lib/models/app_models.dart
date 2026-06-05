import 'package:flutter/material.dart';

enum AppScreen { home, lessons, dictionary, profile }
enum AppOverlay {
  none,
  lessonDetail,
  video,
  quiz,
  aiPractice,
  adminDashboard,
  adminCategories,
  adminCategoryForm,
  adminLessons,
  adminLessonForm,
  adminUsers,
}
enum QuizType { watchAndChoose, chooseVideo }

class Category {
  const Category({
    required this.id,
    required this.title,
    required this.titleAm,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String id;
  final String title;
  final String titleAm;
  final String icon;
  final Color color;
  final String description;
}

class LessonItem {
  const LessonItem({
    required this.id,
    required this.categoryId,
    required this.sign,
    required this.signAm,
    required this.thumbnail,
    this.videoUrl,
    this.videoLocalPath,
    this.culturalNote,
    this.cardImagePath,
    this.showOnCultureCard = false,
  });

  final String id;
  final String categoryId;
  final String sign;
  final String signAm;
  final String thumbnail;

  /// Remote stream URL (e.g. direct .mp4) or Drive hint `drive:FILE_ID`.
  final String? videoUrl;

  /// Cached file on device after [VideoDownloader] completes.
  final String? videoLocalPath;

  /// Optional note on Ethiopian cultural context for this sign.
  final String? culturalNote;

  /// Local image path for the Ethiopian Culture home card.
  final String? cardImagePath;

  /// When true, this sign appears on the home Ethiopian Culture card.
  final bool showOnCultureCard;

  LessonItem copyWith({
    String? id,
    String? categoryId,
    String? sign,
    String? signAm,
    String? thumbnail,
    String? videoUrl,
    String? videoLocalPath,
    String? culturalNote,
    String? cardImagePath,
    bool? showOnCultureCard,
    bool clearVideoUrl = false,
    bool clearVideoLocalPath = false,
    bool clearCulturalNote = false,
    bool clearCardImagePath = false,
  }) {
    return LessonItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      sign: sign ?? this.sign,
      signAm: signAm ?? this.signAm,
      thumbnail: thumbnail ?? this.thumbnail,
      videoUrl: clearVideoUrl ? null : (videoUrl ?? this.videoUrl),
      videoLocalPath: clearVideoLocalPath
          ? null
          : (videoLocalPath ?? this.videoLocalPath),
      culturalNote: clearCulturalNote
          ? null
          : (culturalNote ?? this.culturalNote),
      cardImagePath: clearCardImagePath
          ? null
          : (cardImagePath ?? this.cardImagePath),
      showOnCultureCard: showOnCultureCard ?? this.showOnCultureCard,
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.type,
    required this.question,
    required this.questionAm,
    required this.correctAnswer,
    required this.options,
  });

  final QuizType type;
  final String question;
  final String questionAm;
  final String correctAnswer;
  final List<String> options;
}
