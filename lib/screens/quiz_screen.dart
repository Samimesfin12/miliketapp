import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/backend/models/daily_quiz_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/widgets/lesson_video_player_card.dart';
import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
import 'package:esl_learning_flutter/backend/services/localisation_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.language,
    required this.categoryId,
    required this.categoryLessons,
    this.dailyQuestions = const [],
    required this.onBack,
    this.onQuizComplete,
    this.onCorrectAnswer,
  });
  final String language;
  final String categoryId;
  final List<LessonItem> categoryLessons;
  final List<QuizQuestion> dailyQuestions;
  final VoidCallback onBack;
  final Future<void> Function(int score, int totalQuestions)? onQuizComplete;
  final void Function(LessonItem lesson)? onCorrectAnswer;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  int score = 0;
  String? selectedOption;
  bool _completionRecorded = false;
  VideoPlayerController? _prewarmedController;
  bool _prewarming = false;

  @override
  void initState() {
    super.initState();
    _prewarmNextVideo();
  }

  /// Returns the list of [QuizQuestion]s for the current quiz.
  List<QuizQuestion> _questions() {
    if (widget.categoryId == dailyQuizCategoryId) return widget.dailyQuestions;
    return quizByCategory[widget.categoryId] ?? quizByCategory['greetings']!;
  }

  @override
  void dispose() {
    _prewarmedController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        (widget.categoryId == dailyQuizCategoryId &&
            oldWidget.dailyQuestions != widget.dailyQuestions)) {
      index = 0;
      score = 0;
      selectedOption = null;
      _completionRecorded = false;
      _prewarmedController?.dispose();
      _prewarmedController = null;
      _prewarming = false;
      _prewarmNextVideo();
    }
  }

  Future<void> _prewarmNextVideo() async {
    final questions = _questions();
    final nextIdx = index + 1;
    if (nextIdx >= questions.length) return;
    if (_prewarming) return;
    _prewarming = true;
    if (mounted) setState(() {});
    final nextQ = questions[nextIdx];
    final nextLesson = _lessonForQuizQuestion(nextQ);
    final nextUrl = nextLesson.videoUrl?.trim();
    final nextLocal = nextLesson.videoLocalPath?.trim();
    try {
      VideoPlayerController? ctrl;
      if (nextLocal != null && nextLocal.isNotEmpty) {
        final f = File(nextLocal);
        if (await f.exists()) {
          ctrl = VideoPlayerController.file(
            f,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
      }
      if (ctrl == null && nextUrl != null && nextUrl.isNotEmpty) {
        final driveId = VideoDownloader.parseDriveFileId(nextUrl);
        if (driveId != null) {
          final cacheDir = await getTemporaryDirectory();
          final cachePath = VideoDownloader.drivePlaybackCachePath(
            cacheDir,
            driveId,
          );
          final cacheFile = File(cachePath);
          if (await cacheFile.exists()) {
            ctrl = VideoPlayerController.file(
              cacheFile,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );
          } else {
            // Warm DNS / redirect even if file not cached yet
            try {
              await VideoDownloader().resolvePlaybackSource(
                nextUrl,
                cacheDir: cacheDir,
              );
            } catch (_) {}
          }
        }
      }
      if (ctrl != null && mounted) {
        try {
          await ctrl.initialize().timeout(const Duration(seconds: 20));
          await ctrl.pause();
          if (mounted) {
            await _prewarmedController?.dispose();
            _prewarmedController = ctrl;
          } else {
            await ctrl.dispose();
          }
        } catch (_) {
          await ctrl.dispose();
        }
      }
    } catch (e) {
      debugPrint('Quiz prewarm failed: $e');
    } finally {
      _prewarming = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions();
    if (questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Complete a lesson to unlock your daily quiz!'.tr(
                widget.language,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.onBack,
              child: Text('Continue Learning'.tr(widget.language)),
            ),
          ],
        ),
      );
    }
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
                child: Text('Continue Learning'.tr(widget.language)),
              ),
            ],
          ),
        ),
      );
    }
    final q = questions[index];
    final progress = (index + 1) / questions.length;
    final progressLabel =
        '${(progress * 100).round()}% ${'Complete'.tr(widget.language)}';

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
                Expanded(
                  child: Text(
                    'Ethiopian Sign Language'.tr(widget.language),
                    style: const TextStyle(
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
                        '${'Question'.tr(widget.language)} ${index + 1} ${'of'.tr(widget.language)} ${questions.length}',
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
                  key: ValueKey('quiz_video_${widget.categoryId}_$index'),
                  lesson: _lessonForQuizQuestion(q),
                  showEthBadge: true,
                  borderRadius: 14,
                  hideTitle: true,
                ),
                // Animated 'loading next video' status row
                AnimatedOpacity(
                  opacity: _prewarming ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0B9F5D),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Loading next question\u2026',
                          style: TextStyle(
                            color: Color(0xFF5A5A5A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'What sign is being shown?'.tr(widget.language),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Watch the video carefully and select the\ncorrect meaning of the gesture performed.'
                      .tr(widget.language),
                  style: const TextStyle(
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
                            final questions = _questions();
                            final newScore =
                                score +
                                (selectedOption == q.correctAnswer ? 1 : 0);
                            final nextIndex = index + 1;
                            setState(() {
                              if (selectedOption == q.correctAnswer) {
                                score += 1;
                                final lesson = _lessonForQuizQuestion(q);
                                widget.onCorrectAnswer?.call(lesson);
                              }
                              index = nextIndex;
                              selectedOption = null;
                            });
                            unawaited(_prewarmNextVideo());
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next Question'.tr(widget.language),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward, color: Colors.white),
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
    if (widget.categoryId == dailyQuizCategoryId) {
      final questionIndex = _questions().indexOf(q);
      if (questionIndex >= 0 && questionIndex < widget.categoryLessons.length) {
        return widget.categoryLessons[questionIndex];
      }
    }
    final parts = q.correctAnswer.split('/');
    final en = parts.first.trim();
    final am = parts.length > 1 ? parts.sublist(1).join('/').trim() : en;
    final list = widget.categoryLessons;
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
