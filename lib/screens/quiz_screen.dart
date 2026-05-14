import 'dart:async';

import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/widgets/lesson_video_player_card.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.language,
    required this.categoryId,
    required this.onBack,
    this.onQuizComplete,
  });
  final String language;
  final String categoryId;
  final VoidCallback onBack;
  final Future<void> Function(int score, int totalQuestions)? onQuizComplete;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  int score = 0;
  String? selectedOption;
  bool _completionRecorded = false;

  @override
  void didUpdateWidget(covariant QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      index = 0;
      score = 0;
      selectedOption = null;
      _completionRecorded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions =
        quizByCategory[widget.categoryId] ?? quizByCategory['greetings']!;
    if (index >= questions.length) {
      final pct = (score / questions.length) * 100;
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kPrimary, kPrimaryDark]),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pct >= 80 ? '🎉' : '💪',
                style: const TextStyle(fontSize: 90),
              ),
              Text(
                '${pct.round()}%',
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: widget.onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimary,
                ),
                child: const Text('Continue Learning'),
              ),
            ],
          ),
        ),
      );
    }
    final q = questions[index];
    final progress = (index + 1) / questions.length;
    final progressLabel = '${(progress * 100).round()}% Complete';

    return Container(
      color: const Color(0xFFF7F5F5),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F5F5),
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: kPrimary,
                    size: 24,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Ethiopian Sign Language',
                    style: TextStyle(
                      color: Color(0xFF114F34),
                      fontSize: 31 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9E6E6)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Question ${index + 1} of ${questions.length}',
                        style: const TextStyle(
                          fontSize: 28 / 2,
                          color: Color(0xFF2B2B2B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: const TextStyle(
                        color: Color(0xFF0E7A3D),
                        fontSize: 28 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFDFDDDD),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0B9F5D),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                LessonVideoPlayerCard(
                  key: ValueKey('${q.correctAnswer}_$index'),
                  lesson: _lessonForQuizQuestion(q),
                  showEthBadge: true,
                  borderRadius: 14,
                ),
                const SizedBox(height: 18),
                const Text(
                  'What sign is being shown?',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Watch the video carefully and select the\ncorrect meaning of the gesture performed.',
                  style: TextStyle(
                    fontSize: 30 / 2,
                    height: 1.4,
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ...q.options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuizOptionTile(
                      label: _optionLabel(option),
                      selected: selectedOption == option,
                      onTap: () => setState(() => selectedOption = option),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 62,
                  child: FilledButton(
                    onPressed: selectedOption == null
                        ? null
                        : () {
                            final questions = quizByCategory[widget.categoryId] ??
                                quizByCategory['greetings']!;
                            final newScore =
                                score + (selectedOption == q.correctAnswer ? 1 : 0);
                            final nextIndex = index + 1;
                            setState(() {
                              if (selectedOption == q.correctAnswer) {
                                score += 1;
                              }
                              index = nextIndex;
                              selectedOption = null;
                            });
                            if (nextIndex >= questions.length &&
                                !_completionRecorded) {
                              _completionRecorded = true;
                              unawaited(
                                widget.onQuizComplete?.call(
                                      newScore,
                                      questions.length,
                                    ) ??
                                    Future.value(),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF045E30),
                      disabledBackgroundColor: const Color(0xFF92B8A3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next Question',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LessonItem _lessonForQuizQuestion(QuizQuestion q) {
    final parts = q.correctAnswer.split('/');
    final en = parts.first.trim();
    final am = parts.length > 1 ? parts.sublist(1).join('/').trim() : en;
    final list = lessonsByCategory[widget.categoryId] ?? const <LessonItem>[];
    for (final l in list) {
      if (l.sign.trim() == en) return l;
    }
    return LessonItem(
      id: 'quiz_${widget.categoryId}_${en.hashCode}',
      categoryId: widget.categoryId,
      sign: en,
      signAm: am,
      thumbnail: '✋',
    );
  }

  String _optionLabel(String raw) {
    final parts = raw.split('/');
    if (parts.length < 2) return raw.trim();
    return widget.language == 'en'
        ? parts.first.trim()
        : parts.sublist(1).join('/').trim();
  }
}

class _QuizOptionTile extends StatelessWidget {
  const _QuizOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF0B8D54)
        : const Color(0xFFD1D1D1);
    final tileColor = selected
        ? const Color(0xFF7FE8A8)
        : const Color(0xFFF9F9F9);
    final textColor = selected
        ? const Color(0xFF11643A)
        : const Color(0xFF1F1F1F);

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 2 : 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32 / 2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF0B8D54)
                        : const Color(0xFF777777),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_circle,
                        size: 22,
                        color: Color(0xFF0B8D54),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
