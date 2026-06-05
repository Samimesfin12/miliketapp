import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_usersListProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('Users'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users registered yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = users[i];
              final isAdmin = (u['is_admin'] as int? ?? 0) == 1;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isAdmin ? kPrimary : const Color(0xFFE5E7EB),
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: isAdmin ? Colors.white : Colors.black54,
                    ),
                  ),
                  title: Text(
                    u['full_name'] as String? ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${u['email']}\n'
                    'Signs: ${u['signs_learned']} · Streak: ${u['day_streak']} · '
                    'Practiced: ${u['total_practiced']}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final _usersListProvider = FutureProvider<List<Map<String, Object?>>>((ref) {
  return ref.watch(userRepositoryProvider).allUsers();
});
