import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';

class DictionaryScreen extends ConsumerStatefulWidget {
  const DictionaryScreen({
    super.key,
    required this.language,
    this.userId,
    required this.onOpenLesson,
  });
  final String language;
  final int? userId;
  final ValueChanged<LessonItem> onOpenLesson;

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  String query = '';
  String tab = 'all';
  final Set<String> favorites = {};

  static String _dictSignId(String lessonId) => 'dict_$lessonId';

  @override
  void initState() {
    super.initState();
    _reloadFavoritesFromAccount();
  }

  @override
  void didUpdateWidget(covariant DictionaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      favorites.clear();
      _reloadFavoritesFromAccount();
    }
  }

  Future<void> _reloadFavoritesFromAccount() async {
    final uid = widget.userId;
    if (uid == null) return;
    final ids = await ref.read(dictionaryRepositoryProvider).favouriteSignIds(uid);
    if (!mounted) return;
    setState(() {
      favorites.clear();
      for (final d in ids) {
        if (d.startsWith('dict_')) {
          favorites.add(d.substring(5));
        } else {
          favorites.add(d);
        }
      }
    });
  }

  Future<void> _toggleFavorite(LessonItem item) async {
    final uid = widget.userId;
    if (uid == null) {
      setState(() {
        if (favorites.contains(item.id)) {
          favorites.remove(item.id);
        } else {
          favorites.add(item.id);
        }
      });
      return;
    }
    final dictId = _dictSignId(item.id);
    final repo = ref.read(dictionaryRepositoryProvider);
    if (favorites.contains(item.id)) {
      await repo.removeFavourite(uid, dictId);
      if (!mounted) return;
      setState(() => favorites.remove(item.id));
    } else {
      await repo.addFavourite(uid, dictId);
      if (!mounted) return;
      setState(() => favorites.add(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = lessonsByCategory.values.expand((list) => list).toList()
      ..sort((a, b) => a.sign.toLowerCase().compareTo(b.sign.toLowerCase()));
    final filtered = all.where((item) {
      final matchesQuery =
          item.sign.toLowerCase().contains(query.toLowerCase()) ||
          item.signAm.contains(query);
      final matchesTab = tab == 'all' || favorites.contains(item.id);
      return matchesQuery && matchesTab;
    }).toList();

    final grouped = <String, List<LessonItem>>{};
    for (final item in filtered) {
      final key = item.sign.substring(0, 1).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final sectionKeys = grouped.keys.toList()..sort();

    return Container(
      color: const Color(0xFFF4F4F4),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0E7A3D),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.language == 'en' ? 'Dictionary' : 'መዝገበ ቃላት',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search signs...',
                    hintStyle: const TextStyle(color: Color(0xA6FFFFFF)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xA6FFFFFF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A8A56),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _TabPill(
                      label: 'All Signs (${all.length})',
                      selected: tab == 'all',
                      onTap: () => setState(() => tab = 'all'),
                    ),
                    const SizedBox(width: 10),
                    _TabPill(
                      label: 'Favorites (${favorites.length})',
                      selected: tab == 'favorites',
                      onTap: () => setState(() => tab = 'favorites'),
                      icon: Icons.favorite_border,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No signs found',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    children: [
                      for (final key in sectionKeys) ...[
                        Row(
                          children: [
                            Text(
                              key,
                              style: const TextStyle(
                                color: Color(0xFF0E7A3D),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFD5D5D5),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...grouped[key]!.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DictionaryCard(
                              item: item,
                              language: widget.language,
                              favorite: favorites.contains(item.id),
                              onFavoriteTap: () => _toggleFavorite(item),
                              onOpen: () => widget.onOpenLesson(item),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Showing ${filtered.length} signs',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7C7C7C),
                          fontSize: 16 / 1.2,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
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

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFF2A8A56),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? const Color(0xFF0E7A3D) : Colors.white70,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF0E7A3D) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  const _DictionaryCard({
    required this.item,
    required this.language,
    required this.favorite,
    required this.onFavoriteTap,
    required this.onOpen,
  });

  final LessonItem item;
  final String language;
  final bool favorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(item.thumbnail, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language == 'en' ? item.sign : item.signAm,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      language == 'en' ? item.signAm : item.sign,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  favorite ? Icons.favorite : Icons.favorite_border,
                  color: favorite ? const Color(0xFFE53935) : const Color(0xFF9E9E9E),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
            ],
          ),
        ),
      ),
    );
  }
}
