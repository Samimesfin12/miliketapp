import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

const _signPresets = <({String en, String am, String icon, String note})>[
  (
    en: 'Buna (Coffee)',
    am: 'ቡና',
    icon: '☕',
    note: 'Central to Ethiopian hospitality and the coffee ceremony',
  ),
  (
    en: 'Injera',
    am: 'እንጀራ',
    icon: '🫓',
    note: 'Traditional sourdough flatbread served with wot',
  ),
  (
    en: 'Timket',
    am: 'ጥምቀት',
    icon: '✝️',
    note: 'Ethiopian Orthodox Epiphany celebration',
  ),
  (
    en: 'Netela',
    am: 'ነቲላ',
    icon: '🧣',
    note: 'Traditional white cotton shawl worn on holidays',
  ),
];

class AdminLessonFormScreen extends ConsumerStatefulWidget {
  const AdminLessonFormScreen({
    super.key,
    required this.existingLesson,
    this.initialCategoryId,
    required this.onBack,
    required this.onSaved,
  });

  final LessonItem? existingLesson;
  final String? initialCategoryId;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  ConsumerState<AdminLessonFormScreen> createState() =>
      _AdminLessonFormScreenState();
}

class _AdminLessonFormScreenState extends ConsumerState<AdminLessonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameAmCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _culturalCtrl;
  String? _selectedCategoryId;
  String? _cardImagePath;
  bool _showOnCultureCard = false;
  bool _removeCardImage = false;
  bool _saving = false;
  bool _pickingImage = false;

  bool get _isEdit => widget.existingLesson != null;

  @override
  void initState() {
    super.initState();
    final lesson = widget.existingLesson;
    _nameEnCtrl = TextEditingController(text: lesson?.sign ?? '');
    _nameAmCtrl = TextEditingController(text: lesson?.signAm ?? '');
    _videoCtrl = TextEditingController(text: lesson?.videoUrl ?? '');
    _emojiCtrl = TextEditingController(text: lesson?.thumbnail ?? '👋');
    _culturalCtrl = TextEditingController(text: lesson?.culturalNote ?? '');
    _selectedCategoryId = lesson?.categoryId ?? widget.initialCategoryId;
    _cardImagePath = lesson?.cardImagePath;
    _showOnCultureCard = lesson?.showOnCultureCard ?? false;
  }

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameAmCtrl.dispose();
    _videoCtrl.dispose();
    _emojiCtrl.dispose();
    _culturalCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(({String en, String am, String icon, String note}) preset) {
    setState(() {
      _nameEnCtrl.text = preset.en;
      _nameAmCtrl.text = preset.am;
      _emojiCtrl.text = preset.icon;
      _culturalCtrl.text = preset.note;
    });
  }

  String _normalizeVideoUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('drive:')) return trimmed;
    final driveMatch = RegExp(
      r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(trimmed);
    if (driveMatch != null) {
      return 'drive:${driveMatch.group(1)}';
    }
    return trimmed;
  }

  Future<void> _pickCardImage() async {
    setState(() => _pickingImage = true);
    try {
      final path =
          await ref.read(culturalImageServiceProvider).pickAndSaveImage();
      if (path == null) return;
      if (!mounted) return;
      setState(() {
        _cardImagePath = path;
        _removeCardImage = false;
        _showOnCultureCard = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_showOnCultureCard && (_cardImagePath == null || _removeCardImage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a card image to show this sign on the Ethiopian Culture home card.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final lessonRepo = ref.read(lessonRepositoryProvider);
      final dictRepo = ref.read(dictionaryRepositoryProvider);
      final imageService = ref.read(culturalImageServiceProvider);
      final signEn = _nameEnCtrl.text.trim();
      final signAm = _nameAmCtrl.text.trim();
      final emoji =
          _emojiCtrl.text.trim().isEmpty ? '👋' : _emojiCtrl.text.trim();
      final videoUrl = _normalizeVideoUrl(_videoCtrl.text);
      final culturalNote = _culturalCtrl.text.trim();
      final categoryId = _selectedCategoryId!;

      if (_isEdit) {
        final id = widget.existingLesson!.id;
        final oldImage = widget.existingLesson!.cardImagePath;
        if (_removeCardImage && oldImage != null) {
          await imageService.deleteIfExists(oldImage);
        }
        await lessonRepo.updateLesson(
          id: id,
          signEn: signEn,
          signAm: signAm,
          thumbnailEmoji: emoji,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
          culturalNote: culturalNote.isEmpty ? null : culturalNote,
          cardImagePath: _removeCardImage ? null : _cardImagePath,
          clearCardImagePath: _removeCardImage,
          showOnCultureCard: _showOnCultureCard,
          categoryId: categoryId,
        );
        await dictRepo.upsertForLesson(
          lessonId: id,
          signEn: signEn,
          signAm: signAm,
          thumbnailEmoji: emoji,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
        );
      } else {
        final id = await lessonRepo.generateLessonId(categoryId);
        final orderIndex = await lessonRepo.nextOrderIndex(categoryId);
        await lessonRepo.insertLesson(
          id: id,
          categoryId: categoryId,
          signEn: signEn,
          signAm: signAm,
          thumbnailEmoji: emoji,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
          culturalNote: culturalNote.isEmpty ? null : culturalNote,
          cardImagePath: _cardImagePath,
          showOnCultureCard: _showOnCultureCard,
          locked: true,
          orderIndex: orderIndex,
        );
        await dictRepo.upsertForLesson(
          lessonId: id,
          signEn: signEn,
          signAm: signAm,
          thumbnailEmoji: emoji,
          videoUrl: videoUrl.isEmpty ? null : videoUrl,
        );
      }

      ref.invalidate(curriculumProvider);
      ref.invalidate(cultureCardSignsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Sign updated' : 'Cultural sign added'),
          backgroundColor: kPrimary,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final curriculumAsync = ref.watch(curriculumProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text(_isEdit ? 'Edit Cultural Sign' : 'Add Cultural Sign'),
      ),
      body: curriculumAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (curriculum) {
          if (curriculum.categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Create a category first before adding signs.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: widget.onBack,
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            );
          }

          _selectedCategoryId ??= widget.initialCategoryId ??
              (curriculum.categories.isNotEmpty
                  ? curriculum.categories.first.id
                  : null);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isEdit) ...[
                  const Text(
                    'Example cultural signs',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _signPresets
                        .map(
                          (p) => ActionChip(
                            label: Text('${p.icon} ${p.en}'),
                            onPressed: () => _applyPreset(p),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameEnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sign Name (English)',
                    hintText: 'e.g. Buna (Coffee)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameAmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sign Name (Amharic)',
                    hintText: 'e.g. ቡና',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emojiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Thumbnail emoji',
                    hintText: '☕',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: curriculum.categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.icon} ${c.title}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                  validator: (v) => v == null ? 'Select category' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _culturalCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Cultural context (optional)',
                    hintText:
                        'Why is this sign important in Ethiopian culture?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ethiopian Culture home card',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload an image for the home screen Ethiopian Culture card.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on Ethiopian Culture card'),
                  subtitle: const Text('Appears on the home screen culture section'),
                  value: _showOnCultureCard,
                  activeThumbColor: kPrimary,
                  onChanged: (v) => setState(() => _showOnCultureCard = v),
                ),
                if (_cardImagePath != null && !_removeCardImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.file(
                        File(_cardImagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _pickingImage ? null : _pickCardImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Change image'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _removeCardImage = true;
                          _cardImagePath = null;
                        }),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _pickingImage ? null : _pickCardImage,
                    icon: _pickingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _pickingImage ? 'Opening gallery...' : 'Pick card image',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _videoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Video (drive:ID or Google Drive URL)',
                    hintText: 'drive:1wQoueUDZVv_HBqmmcOmSIST3GqPtW9td',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload the sign video to Google Drive and paste the link.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save Sign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
