import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({
    super.key,
    required this.language,
    required this.completedLessonIds,
    required this.onOpenCategory,
    required this.onOpenAIPractice,
  });

  final String language;
  final Set<String> completedLessonIds;
  final ValueChanged<Category> onOpenCategory;
  final VoidCallback onOpenAIPractice;

  @override
  Widget build(BuildContext context) {
    final totalLessons = totalCurriculumLessons();
    final completedOverall = countCompletedInCurriculum(completedLessonIds);
    final overallFraction = curriculumProgressFraction(completedLessonIds);
    final overallPercent = (overallFraction * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      children: [
        Container(
          width: double.infinity,
          color: kPrimary,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: const Row(
            children: [
              Icon(Icons.school_outlined, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lessons',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Choose a category to start learning',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF075D33), Color(0xFF0F6A3C)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Stack(
              children: [
                Positioned(
                  right: 8,
                  top: 4,
                  child: Icon(
                    Icons.school_outlined,
                    size: 54,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.white70,
                          size: 14,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'YOUR ACTIVITY',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Learning Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$completedOverall of $totalLessons lessons completed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$overallPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            FractionallySizedBox(
                              widthFactor: overallFraction.clamp(0.0, 1.0),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8CD9A1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            itemCount: categories.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, i) {
              final c = categories[i];
              final list = lessonsByCategory[c.id] ?? [];
              final completedCount = list
                  .where((l) => completedLessonIds.contains(l.id))
                  .length;
              final labelIcon = _iconForCategory(c.id);
              final progressLabel = '$completedCount/${list.length}';
              final showTitle = language == 'en' ? c.title : c.titleAm;

              return InkWell(
                onTap: () => onOpenCategory(c),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE7E7E7)),
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _accentForCategory(c.id),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            labelIcon,
                            color: _accentForCategory(c.id),
                            size: 22,
                          ),
                          const Spacer(),
                          Text(
                            progressLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            _descriptionForCategory(c.id),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${((list.isEmpty ? 0 : completedCount / list.length) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          value: list.isEmpty
                              ? 0.0
                              : completedCount / list.length,
                          backgroundColor: const Color(0xFFF0F2F2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFDBE7DE),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => onOpenCategory(c),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Learn',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
        return Icons.ac_unit;
      case 'numbers':
        return Icons.onetwothree;
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

  String _descriptionForCategory(String id) {
    switch (id) {
      case 'greetings':
        return 'Essential signs for daily interactions';
      case 'family':
        return 'Learn signs for relatives and relationships';
      case 'food':
        return 'Common food and dining terminology';
      case 'shopping':
        return 'Vocabulary for markets and transactions';
      case 'emergency':
        return 'Crucial signs for urgent situations';
      case 'numbers':
        return 'Counting and numerical concepts';
      default:
        return 'Start learning this category';
    }
  }
}
