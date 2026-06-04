import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({
    super.key,
    required this.language,
    required this.category,
    required this.completedLessonIds,
    required this.onBack,
    required this.onOpenLesson,
  });
  final String language;
  final Category category;
  final Set<String> completedLessonIds;
  final VoidCallback onBack;
  final ValueChanged<LessonItem> onOpenLesson;

  @override
  Widget build(BuildContext context) {
    final list = lessonsByCategory[category.id] ?? [];
    final title = language == 'en' ? category.title : category.titleAm;
    final completedCount = list
        .where((lesson) => completedLessonIds.contains(lesson.id))
        .length;

    return Container(
      color: const Color(0xFFF6F6F6),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: kPrimary,
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E7A3D),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _accentForCategory(
                          category.id,
                        ).withValues(alpha: 0.24),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForCategory(category.id),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  category.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.library_books_outlined,
                        label: 'LESSONS',
                        value: list.length.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle_outline,
                        label: 'COMPLETED',
                        value: completedCount.toString(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F6F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 26),
                itemCount: list.length + 1,
                itemBuilder: (_, i) {
                  if (i == list.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: _PromoCard(),
                    );
                  }
                  final lesson = list[i];
                  final isCompleted = completedLessonIds.contains(lesson.id);
                  final isLocked =
                      i > 0 && !completedLessonIds.contains(list[i - 1].id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LessonTile(
                      lesson: lesson,
                      language: language,
                      isLocked: isLocked,
                      isCompleted: isCompleted,
                      onTap: isLocked ? null : () => onOpenLesson(lesson),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'greetings':
        return Icons.front_hand_outlined;
      case 'family':
        return Icons.device_hub_outlined;
      case 'food':
        return Icons.restaurant_menu;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'emergency':
        return Icons.warning_amber_outlined;
      case 'numbers':
        return Icons.format_list_numbered;
      default:
        return Icons.category_outlined;
    }
  }

  Color _accentForCategory(String id) {
    switch (id) {
      case 'greetings':
        return const Color(0xFF3F51B5);
      case 'family':
        return const Color(0xFFE91E63);
      case 'food':
        return const Color(0xFFFF9800);
      case 'shopping':
        return const Color(0xFF00BCD4);
      case 'emergency':
        return const Color(0xFFF44336);
      case 'numbers':
        return const Color(0xFF9C27B0);
      default:
        return kPrimary;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.language,
    required this.isLocked,
    required this.isCompleted,
    required this.onTap,
  });

  final LessonItem lesson;
  final String language;
  final bool isLocked;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = language == 'en' ? lesson.sign : lesson.signAm;
    final subtitle = language == 'en' ? lesson.signAm : lesson.sign;

    return Material(
      color: isLocked ? const Color(0xFFF2F2F2) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isLocked
                      ? const Color(0xFFE6E6E6)
                      : const Color(0xFFDDF7E7),
                  shape: BoxShape.circle,
                ),
                child: isLocked
                    ? Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: const Color(0xFF8D8D8D),
                      )
                    : Center(
                        child: Text(
                          lesson.thumbnail,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isLocked
                            ? const Color(0xFF4E4E4E)
                            : const Color(0xFF202020),
                        fontSize: 30 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF878787),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E7E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Locked',
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E874E),
                      width: 1.6,
                    ),
                    color: isCompleted
                        ? const Color(0xFF1E874E)
                        : const Color(0xFFEAF7EE),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1E874E),
                            ),
                            child: SizedBox(width: 9, height: 9),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2F2F2), Color(0xFF58B798)],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.accessibility_new_rounded,
                color: Color(0xFF0F3250),
                size: 92,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Master 50+ basic gestures through\ninteractive video lessons.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1D1D1D),
              fontSize: 17 / 1.3,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
