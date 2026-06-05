import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

const _categoryColorPresets = <Color>[
  kPrimary,
  kPrimaryDark,
  kAccent,
  kDanger,
  Color(0xFF1D4ED8),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
  Color(0xFFB45309),
];

const _culturalPresets = <({String en, String am, String icon, String desc})>[
  (
    en: 'Coffee Ceremony',
    am: 'የቡና ስነ-ልምድ',
    icon: '☕',
    desc: 'Traditional Ethiopian coffee ceremony signs',
  ),
  (
    en: 'Holidays & Festivals',
    am: 'በዓላት',
    icon: '🎉',
    desc: 'Timket, Meskel, Enkutatash and cultural celebrations',
  ),
  (
    en: 'Traditional Clothing',
    am: 'ባህላዊ ልብስ',
    icon: '👘',
    desc: 'Habesha kemis, netela, and cultural dress',
  ),
  (
    en: 'Ethiopian Food',
    am: 'የኢትዮጵያ ምግብ',
    icon: '🫓',
    desc: 'Injera, wot, coffee, and dining customs',
  ),
];

class AdminCategoryFormScreen extends ConsumerStatefulWidget {
  const AdminCategoryFormScreen({
    super.key,
    required this.existingCategory,
    required this.onBack,
    required this.onSaved,
  });

  final Category? existingCategory;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  ConsumerState<AdminCategoryFormScreen> createState() =>
      _AdminCategoryFormScreenState();
}

class _AdminCategoryFormScreenState extends ConsumerState<AdminCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleEnCtrl;
  late final TextEditingController _titleAmCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _descCtrl;
  Color _selectedColor = kPrimary;
  bool _saving = false;

  bool get _isEdit => widget.existingCategory != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _titleEnCtrl = TextEditingController(text: cat?.title ?? '');
    _titleAmCtrl = TextEditingController(text: cat?.titleAm ?? '');
    _iconCtrl = TextEditingController(text: cat?.icon ?? '🏛️');
    _descCtrl = TextEditingController(text: cat?.description ?? '');
    if (cat != null) _selectedColor = cat.color;
  }

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleAmCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(({String en, String am, String icon, String desc}) preset) {
    setState(() {
      _titleEnCtrl.text = preset.en;
      _titleAmCtrl.text = preset.am;
      _iconCtrl.text = preset.icon;
      _descCtrl.text = preset.desc;
    });
  }

  int _colorToArgb(Color c) {
    final a = (c.a * 255).round();
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final titleEn = _titleEnCtrl.text.trim();
      final titleAm = _titleAmCtrl.text.trim();
      final icon = _iconCtrl.text.trim().isEmpty ? '🏛️' : _iconCtrl.text.trim();
      final description = _descCtrl.text.trim();
      final colorArgb = _colorToArgb(_selectedColor);

      if (_isEdit) {
        final id = widget.existingCategory!.id;
        final sortOrder = await repo.sortOrderFor(id);
        await repo.updateCategory(
          id: id,
          title: titleEn,
          titleAm: titleAm.isEmpty ? titleEn : titleAm,
          icon: icon,
          colorArgb: colorArgb,
          description: description.isEmpty
              ? 'Cultural signs for Ethiopian Sign Language learners'
              : description,
          sortOrder: sortOrder,
        );
      } else {
        final id = await repo.generateUniqueCategoryId(titleEn);
        final sortOrder = await repo.nextSortOrder();
        await repo.insertCategory(
          id: id,
          title: titleEn,
          titleAm: titleAm.isEmpty ? titleEn : titleAm,
          icon: icon,
          colorArgb: colorArgb,
          description: description.isEmpty
              ? 'Cultural signs for Ethiopian Sign Language learners'
              : description,
          sortOrder: sortOrder,
        );
      }

      ref.invalidate(curriculumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Category updated' : 'Category created'),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text(_isEdit ? 'Edit Category' : 'New Cultural Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) ...[
              const Text(
                'Quick presets',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _culturalPresets
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
              controller: _titleEnCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name (English)',
                hintText: 'e.g. Coffee Ceremony',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleAmCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name (Amharic)',
                hintText: 'e.g. የቡና ስነ-ልምድ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _iconCtrl,
              decoration: const InputDecoration(
                labelText: 'Icon emoji',
                hintText: '☕',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cultural description',
                hintText:
                    'What Ethiopian culture or tradition does this category cover?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Category color',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _categoryColorPresets.map((color) {
                final selected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
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
                label: Text(_saving ? 'Saving...' : 'Save Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
