import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onOpenCategories,
    required this.onOpenLessons,
    required this.onOpenUsers,
    required this.onBack,
  });

  final VoidCallback onOpenCategories;
  final VoidCallback onOpenLessons;
  final VoidCallback onOpenUsers;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _StatChip(
                  label: 'Users',
                  value: '${stats.userCount}',
                  color: const Color(0xFF0F766E),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Lessons',
                  value: '${stats.lessonCount}',
                  color: const Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Quizzes',
                  value: '${stats.quizCount}',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _AdminCard(
              icon: Icons.category,
              title: 'Manage Categories',
              desc: 'Add cultural topics like coffee ceremony, holidays',
              color: const Color(0xFF1D4ED8),
              onTap: onOpenCategories,
            ),
            _AdminCard(
              icon: Icons.volunteer_activism,
              title: 'Cultural Signs',
              desc: 'Add Ethiopian cultural signs with videos',
              color: kPrimary,
              onTap: onOpenLessons,
            ),
            _AdminCard(
              icon: Icons.people,
              title: 'User Management',
              desc: 'View registered users and their progress',
              color: const Color(0xFF0F766E),
              onTap: onOpenUsers,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'Admin login: admin@miliketapp.com\n'
                'Changes apply on this device for all users.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStats {
  const _AdminStats({
    required this.userCount,
    required this.lessonCount,
    required this.quizCount,
  });

  final int userCount;
  final int lessonCount;
  final int quizCount;
}

final _adminStatsProvider = FutureProvider<_AdminStats>((ref) async {
  final users = await ref.watch(userRepositoryProvider).countUsers();
  final lessons = await ref.watch(lessonRepositoryProvider).countLessons();
  final quizzes = await ref.watch(adminRepositoryProvider).countQuizAttempts();
  return _AdminStats(
    userCount: users,
    lessonCount: lessons,
    quizCount: quizzes,
  );
});

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
