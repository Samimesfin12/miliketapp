import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/models/curriculum_data.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.language,
    required this.curriculum,
    required this.completedLessonIds,
    required this.onOpenCategory,
    required this.onOpenQuiz,
    required this.onOpenMenu,
    required this.onViewAll,
    required this.onOpenLesson,
  });
  final String language;
  final CurriculumData curriculum;
  final Set<String> completedLessonIds;
  final ValueChanged<Category> onOpenCategory;
  final ValueChanged<String> onOpenQuiz;
  final VoidCallback onOpenMenu;
  final VoidCallback onViewAll;
  final ValueChanged<LessonItem> onOpenLesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cultureSignsAsync = ref.watch(cultureCardSignsProvider);

    final mappedCategories = curriculum.categories.take(6).map((c) {
      return _QuickCategory(
        category: c,
        icon: _iconForCategory(c.id),
        lessonCount: curriculum.lessonsByCategory[c.id]?.length ?? 0,
        completedCount: curriculum.countCompletedInCategory(
          c.id,
          completedLessonIds,
        ),
        backgroundColor: c.color.withValues(alpha: 0.08),
      );
    }).toList();

    final progress = curriculum.progressFraction(completedLessonIds);
    final progressPercent = (progress * 100).round();
    final nextLesson = curriculum.firstIncompleteLesson(completedLessonIds);
    final continueCategory = nextLesson != null
        ? curriculum.categoryForLesson(nextLesson)
        : (curriculum.categories.isNotEmpty
              ? curriculum.categories.first
              : null);
    final chipLabel = nextLesson != null
        ? curriculum.continueLessonChipLabel(language, nextLesson)
        : (language == 'en' ? 'All lessons complete!' : 'ሁሉንም ትምህርቶች አጠናቀዋል!');
    final subtitleLine = nextLesson != null
        ? (language == 'en' ? nextLesson.sign : nextLesson.signAm)
        : (language == 'en'
              ? 'Review categories or take a quiz'
              : 'ምድቦችን ይገምግሙ ወይም ጥያቄ ይውሰዱ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              onPressed: onOpenMenu,
              icon: const Icon(Icons.menu, color: kPrimaryDark, size: 22),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            const Text(
              'Miliketapp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: kPrimaryDark,
                letterSpacing: -0.6,
              ),
            ),
            const Spacer(),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E2E1)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Text(
                    language == 'am' ? 'አማ' : 'EN',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hello! 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      height: 0.92,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Learn Ethiopian Sign\nLanguage!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: const Color(0xFFF6F3F2),
                    valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                  ),
                  Center(
                    child: Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          icon: Icons.play_circle_outline,
          title: 'Continue Learning',
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            if (nextLesson != null) {
              onOpenLesson(nextLesson);
            } else if (continueCategory != null) {
              onOpenCategory(continueCategory);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [kPrimary, kPrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Continue Your Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleLine,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.white70, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Resume Now',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onViewAll,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const Text(
                'View All',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: mappedCategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.32,
          ),
          itemBuilder: (context, index) {
            final item = mappedCategories[index];
            return GestureDetector(
              onTap: () => onOpenCategory(item.category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: index.isEven
                      ? const Color(0xFFF6F3F2)
                      : const Color(0xFFF0EDED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E2E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, size: 18, color: kPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.category.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      language == 'en'
                          ? '${item.completedCount}/${item.lessonCount} done'
                          : '${item.completedCount}/${item.lessonCount} ተጠናቋል',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => onOpenQuiz('greetings'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: kAccent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFF7D95E),
                  child: Icon(Icons.light_mode_outlined, color: Colors.black87, size: 18),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice Quiz of the Day',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Test Your Daily Goals!',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ethiopian Culture',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        cultureSignsAsync.when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Could not load cultural signs: $e'),
          data: (signs) {
            if (signs.isEmpty) {
              return _CulturePlaceholderCard(language: language);
            }
            if (signs.length == 1) {
              return _CultureSignCard(
                lesson: signs.first,
                language: language,
                onTap: () => onOpenLesson(signs.first),
              );
            }
            return SizedBox(
              height: 268,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: signs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.82,
                  child: _CultureSignCard(
                    lesson: signs[i],
                    language: language,
                    compact: true,
                    onTap: () => onOpenLesson(signs[i]),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'greetings':
        return Icons.front_hand_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'emergency':
        return Icons.emergency_outlined;
      case 'numbers':
        return Icons.onetwothree;
      default:
        return Icons.category_outlined;
    }
  }
}

class _CultureSignCard extends StatelessWidget {
  const _CultureSignCard({
    required this.lesson,
    required this.language,
    required this.onTap,
    this.compact = false,
  });

  final LessonItem lesson;
  final String language;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = language == 'en' ? lesson.sign : lesson.signAm;
    final subtitle = language == 'en' ? lesson.signAm : lesson.sign;
    final note = lesson.culturalNote?.trim();
    final imageHeight = compact ? 148.0 : 160.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: _CultureCardImage(lesson: lesson),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A6D40),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'CULTURAL SIGN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Text(
                      lesson.thumbnail,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 14, compact ? 12 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (note != null && note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 2),
                    child: Icon(Icons.play_circle_outline, color: kPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CultureCardImage extends StatelessWidget {
  const _CultureCardImage({required this.lesson});

  final LessonItem lesson;

  @override
  Widget build(BuildContext context) {
    final path = lesson.cardImagePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D200F), Color(0xFF8F4A16)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Text(lesson.thumbnail, style: const TextStyle(fontSize: 84)),
    );
  }
}

class _CulturePlaceholderCard extends StatelessWidget {
  const _CulturePlaceholderCard({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E2E1)),
      ),
      child: Row(
        children: [
          const Text('🇪🇹', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              language == 'en'
                  ? 'Cultural signs will appear here when an admin adds them with a home card image.'
                  : 'አስተዳዳሪ ባህላዊ ምልክቶችን ከምስል ሲጨምሩ እዚህ ይታያሉ።',
              style: TextStyle(color: Colors.grey[700], height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }
}

class _QuickCategory {
  const _QuickCategory({
    required this.category,
    required this.icon,
    required this.lessonCount,
    required this.completedCount,
    required this.backgroundColor,
  });

  final Category category;
  final IconData icon;
  final int lessonCount;
  final int completedCount;
  final Color backgroundColor;
}
