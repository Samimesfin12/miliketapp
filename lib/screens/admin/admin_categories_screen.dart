import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({
    super.key,
    required this.onBack,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onAddSignToCategory,
  });

  final VoidCallback onBack;
  final VoidCallback onAddCategory;
  final ValueChanged<Category> onEditCategory;
  final ValueChanged<Category> onAddSignToCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumAsync = ref.watch(curriculumProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('Manage Categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: onAddCategory,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
      ),
      body: curriculumAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (curriculum) {
          if (curriculum.categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No categories yet.\nTap "New Category" to add a cultural topic.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: curriculum.categories.length,
            itemBuilder: (context, i) {
              final cat = curriculum.categories[i];
              final lessonCount =
                  curriculum.lessonsByCategory[cat.id]?.length ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cat.color.withValues(alpha: 0.15),
                    child: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  title: Text(
                    cat.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${cat.titleAm}\n$lessonCount sign(s) · ${cat.description}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'sign':
                          onAddSignToCategory(cat);
                        case 'edit':
                          onEditCategory(cat);
                        case 'delete':
                          _confirmDelete(context, ref, cat);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'sign',
                        child: Text('Add cultural sign'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Remove "${cat.title}" and all its lessons? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(categoryRepositoryProvider).deleteCategory(cat.id);
    ref.invalidate(curriculumProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${cat.title}'),
          backgroundColor: kPrimary,
        ),
      );
    }
  }
}
