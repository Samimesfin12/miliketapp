import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.language,
    required this.completedLessonIds,
    required this.onOpenCategory,
    required this.onOpenQuiz,
    required this.onOpenMenu,
  });
  final String language;
  final Set<String> completedLessonIds;
  final ValueChanged<Category> onOpenCategory;
  final ValueChanged<String> onOpenQuiz;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final mappedCategories = <_QuickCategory>[
      _QuickCategory(
        category: categories.firstWhere((c) => c.id == 'greetings'),
        icon: Icons.front_hand_outlined,
        lessonCount: lessonsByCategory['greetings']?.length ?? 0,
        completedCount: countCompletedInCategory(
          'greetings',
          completedLessonIds,
        ),
        backgroundColor: const Color(0xFFF3F7F4),
      ),
      _QuickCategory(
        category: categories.firstWhere((c) => c.id == 'family'),
        icon: Icons.family_restroom_outlined,
        lessonCount: lessonsByCategory['family']?.length ?? 0,
        completedCount: countCompletedInCategory('family', completedLessonIds),
        backgroundColor: const Color(0xFFEFF8F2),
      ),
      _QuickCategory(
        category: categories.firstWhere((c) => c.id == 'food'),
        icon: Icons.restaurant_outlined,
        lessonCount: lessonsByCategory['food']?.length ?? 0,
        completedCount: countCompletedInCategory('food', completedLessonIds),
        backgroundColor: const Color(0xFFF5F8F5),
      ),
      _QuickCategory(
        category: categories.firstWhere((c) => c.id == 'shopping'),
        icon: Icons.shopping_bag_outlined,
        lessonCount: lessonsByCategory['shopping']?.length ?? 0,
        completedCount: countCompletedInCategory(
          'shopping',
          completedLessonIds,
        ),
        backgroundColor: const Color(0xFFF1F6F4),
      ),
    ];

    final progress = curriculumProgressFraction(completedLessonIds);
    final progressPercent = (progress * 100).round();
    final nextLesson = firstIncompleteLesson(completedLessonIds);
    final continueCategory = nextLesson != null
        ? categoryForLesson(nextLesson)
        : categories.first;
    final chipLabel = nextLesson != null
        ? continueLessonChipLabel(language, nextLesson)
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: kPrimaryDark,
                letterSpacing: -0.8,
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
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
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
              width: 72,
              height: 72,
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
                        fontSize: 17,
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
          onTap: () => onOpenCategory(continueCategory),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
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
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          'Resume Now',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
        Row(
          children: const [
            Expanded(
              child: Text(
                'Quick Categories',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
            Text(
              'View All',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ],
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
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: index.isEven
                      ? const Color(0xFFF6F3F2)
                      : const Color(0xFFF0EDED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E2E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, size: 22, color: kPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.category.title,
                      style: const TextStyle(
                        fontSize: 14,
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
                  radius: 20,
                  backgroundColor: Color(0xFFF7D95E),
                  child: Icon(Icons.light_mode_outlined, color: Colors.black87),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice Quiz of the Day',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Test Your Daily Goals!',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 28),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ethiopian Culture',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Ethiopian_coffee_ceremony.jpg/1280px-Ethiopian_coffee_ceremony.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF3D200F), Color(0xFF8F4A16)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: const Center(
                              child: Text('☕', style: TextStyle(fontSize: 84)),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          color: Colors.black.withValues(alpha: 0.15),
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
                          'NEW HERE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: const [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coffee Ceremony & Injera',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ቡና ሥነ-ሥርዓት እና እንጀራ ባህል',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.bookmark_border),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
        Icon(icon, size: 22),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
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
