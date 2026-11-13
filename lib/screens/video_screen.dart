import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/widgets/lesson_video_player_card.dart';
import 'package:esl_learning_flutter/backend/services/localisation_service.dart';

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
    required this.categoryLessons,
  });
  final String language;
  final LessonItem lesson;
  final List<LessonItem> categoryLessons;
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

  @override
  void initState() {
    super.initState();
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
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$title ($subtitle)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                LessonVideoPlayerCard(
                  lesson: widget.lesson,
                  onProgressLearned: () {
                    widget.onLearned();
                    if (mounted) setState(() => _watched = true);
                  },
                ),
                if (widget.lesson.culturalNote != null &&
                    widget.lesson.culturalNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE8E0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.public,
                          color: kPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cultural context'.tr(widget.language),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.lesson.culturalNote!,
                                style: const TextStyle(
                                  height: 1.35,
                                  color: Color(0xFF3F4941),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.showDownloadButton) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final localPath = widget.lesson.videoLocalPath;
                      final isDownloaded =
                          localPath != null &&
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
                            'Downloaded (Offline)'.tr(widget.language),
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
                          'Download for offline'.tr(widget.language),
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
                const SizedBox(height: 24),
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$title ',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: subtitle,
                          style: const TextStyle(
                            color: Color(0xFF6E6D3F),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: widget.onStartAI,
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam_outlined, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI Practice'.tr(widget.language),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_watched)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7EDB8),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFF506240),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sign learned! +1 to your\nprogress'.tr(widget.language),
                            style: const TextStyle(
                              color: Color(0xFF58624A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const Icon(Icons.close, color: Color(0xFF58624A), size: 24),
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
        return 'Greetings'.tr(widget.language);
      case 'family':
        return 'Family'.tr(widget.language);
      case 'food':
        return 'Food'.tr(widget.language);
      case 'shopping':
        return 'Shopping'.tr(widget.language);
      case 'emergency':
        return 'Emergency'.tr(widget.language);
      case 'numbers':
        return 'Numbers'.tr(widget.language);
      default:
        return 'Lesson'.tr(widget.language);
    }
  }
}
