import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/widgets/lesson_video_player_card.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({
    super.key,
    required this.language,
    required this.lesson,
    required this.downloadInProgress,
    required this.downloadProgress,
    required this.showDownloadButton,
    required this.onDownloadVideo,
    required this.onBack,
    required this.onLessonChanged,
    required this.onStartQuiz,
    required this.onStartAI,
    required this.onLearned,
  });
  final String language;
  final LessonItem lesson;
  final bool downloadInProgress;
  final double? downloadProgress;
  final bool showDownloadButton;
  final Future<void> Function() onDownloadVideo;
  final VoidCallback onBack;
  final ValueChanged<LessonItem> onLessonChanged;
  final VoidCallback onStartQuiz;
  final VoidCallback onStartAI;
  final VoidCallback onLearned;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  bool _watched = false;

  List<LessonItem> _lessonsInCategory() =>
      lessonsByCategory[widget.lesson.categoryId] ?? const <LessonItem>[];

  int _lessonIndex() {
    final list = _lessonsInCategory();
    final i = list.indexWhere((l) => l.id == widget.lesson.id);
    return i;
  }

  void _goPrevious() {
    final list = _lessonsInCategory();
    final i = _lessonIndex();
    if (i <= 0) return;
    widget.onLessonChanged(list[i - 1]);
  }

  void _goNext() {
    final list = _lessonsInCategory();
    final i = _lessonIndex();
    if (i < 0 || i >= list.length - 1) return;
    widget.onLessonChanged(list[i + 1]);
  }

  @override
  void didUpdateWidget(VideoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id) {
      setState(() => _watched = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson.sign;
    final subtitle = widget.lesson.signAm;
    final categoryLabel = _categoryLabel(widget.lesson.categoryId);

    return Container(
      color: kBackground,
      child: Column(
        children: [
          Container(
            color: kPrimaryDark,
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$title ($subtitle)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              children: [
                LessonVideoPlayerCard(
                  lesson: widget.lesson,
                  onProgressLearned: () {
                    widget.onLearned();
                    if (mounted) setState(() => _watched = true);
                  },
                ),
                if (widget.showDownloadButton) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final localPath = widget.lesson.videoLocalPath;
                      final isDownloaded = localPath != null &&
                          localPath.isNotEmpty &&
                          File(localPath).existsSync();

                      if (isDownloaded) {
                        return OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          label: Text(
                            widget.language == 'en'
                                ? 'Downloaded (Offline)'
                                : 'ወርዷል (ከመስመር ውጭ)',
                            style: const TextStyle(color: Colors.green),
                          ),
                        );
                      }

                      return OutlinedButton.icon(
                        onPressed: widget.downloadInProgress
                            ? null
                            : () => unawaited(widget.onDownloadVideo()),
                        icon: widget.downloadInProgress
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          widget.language == 'en'
                              ? 'Download for offline'
                              : 'ከመስመር ውጭ ያውርዱ',
                        ),
                      );
                    },
                  ),
                  if (widget.downloadInProgress &&
                      widget.downloadProgress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: widget.downloadProgress!.clamp(0.0, 1.0),
                    ),
                  ],
                ],
                const SizedBox(height: 30),
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$title ',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: subtitle,
                          style: const TextStyle(
                            color: Color(0xFF6E6D3F),
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDEFC0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      categoryLabel,
                      style: const TextStyle(
                        color: Color(0xFF5C6A39),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 42),
                SizedBox(
                  height: 84,
                  child: ElevatedButton(
                    onPressed: widget.onStartQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE09A),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Practice Quiz',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.quiz_outlined, size: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final list = _lessonsInCategory();
                    final i = _lessonIndex();
                    final canPrev = i > 0;
                    final canNext = i >= 0 && i < list.length - 1;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: canPrev ? _goPrevious : null,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(70),
                                  side: const BorderSide(
                                    color: Color(0xFFD2CED9),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.black,
                                ),
                                label: const Text(
                                  'Previous',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: FilledButton(
                                onPressed: canNext ? _goNext : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(70),
                                  backgroundColor: kPrimaryDark,
                                  disabledBackgroundColor: const Color(
                                    0xFFB8C4BE,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: widget.onStartAI,
                          icon: const Icon(
                            Icons.videocam_outlined,
                            color: kPrimaryDark,
                          ),
                          label: const Text(
                            'AI Practice',
                            style: TextStyle(
                              color: kPrimaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 138),
                if (_watched)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7EDB8),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF506240),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Sign learned! +1 to your\nprogress',
                            style: TextStyle(
                              color: Color(0xFF58624A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        Icon(Icons.close, color: Color(0xFF58624A), size: 28),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String categoryId) {
    switch (categoryId) {
      case 'greetings':
        return 'Greetings';
      case 'family':
        return 'Family';
      case 'food':
        return 'Food';
      case 'shopping':
        return 'Shopping';
      case 'emergency':
        return 'Emergency';
      case 'numbers':
        return 'Numbers';
      default:
        return 'Lesson';
    }
  }
}
