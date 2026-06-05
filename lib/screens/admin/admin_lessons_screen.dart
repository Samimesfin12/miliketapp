import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class AdminLessonsScreen extends ConsumerWidget {
  const AdminLessonsScreen({
    super.key,
    required this.onBack,
    required this.onAddLesson,
    required this.onEditLesson,
  });

  final VoidCallback onBack;
  final VoidCallback onAddLesson;
  final ValueChanged<LessonItem> onEditLesson;

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
        title: const Text('Cultural Signs'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: onAddLesson,
        icon: const Icon(Icons.add),
        label: const Text('Add Cultural Sign'),
      ),
      body: curriculumAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (curriculum) {
          if (curriculum.categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: curriculum.categories.length,
            itemBuilder: (context, catIndex) {
              final cat = curriculum.categories[catIndex];
              final lessons = curriculum.lessonsByCategory[cat.id] ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      '${cat.icon} ${cat.title}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (lessons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No lessons in this category.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ...lessons.map(
                    (lesson) => _LessonTile(
                      lesson: lesson,
                      onEdit: () => onEditLesson(lesson),
                      onDelete: () => _confirmDelete(context, ref, lesson),
                      onToggleLock: () =>
                          _toggleLock(context, ref, lesson),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    LessonItem lesson,
  ) async {
    final repo = ref.read(lessonRepositoryProvider);
    final row = await repo.lessonById(lesson.id);
    final locked = (row?['locked'] as int? ?? 1) == 1;
    await repo.setLocked(lesson.id, !locked);
    ref.invalidate(curriculumProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locked ? 'Lesson unlocked' : 'Lesson locked'),
          backgroundColor: kPrimary,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonItem lesson,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text('Remove "${lesson.sign}" from lessons and dictionary?'),
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
    await ref
        .read(culturalImageServiceProvider)
        .deleteIfExists(lesson.cardImagePath);
    await ref.read(lessonRepositoryProvider).deleteLesson(lesson.id);
    await ref.read(dictionaryRepositoryProvider).deleteForLesson(lesson.id);
    ref.invalidate(curriculumProvider);
    ref.invalidate(cultureCardSignsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson deleted'),
          backgroundColor: kPrimary,
        ),
      );
    }
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleLock,
  });

  final LessonItem lesson;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(lesson.thumbnail, style: const TextStyle(fontSize: 28)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                lesson.sign,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (lesson.showOnCultureCard)
              const Icon(Icons.home_outlined, size: 18, color: kPrimary),
          ],
        ),
                  subtitle: Text(
                    [
                      lesson.signAm,
                      if (lesson.culturalNote != null &&
                          lesson.culturalNote!.isNotEmpty)
                        lesson.culturalNote!,
                      lesson.videoUrl ?? 'No video',
                    ].join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'lock':
                onToggleLock();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'lock', child: Text('Lock / Unlock')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
