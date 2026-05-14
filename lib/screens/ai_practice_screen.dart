import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class AIPracticeScreen extends StatefulWidget {
  const AIPracticeScreen({super.key, required this.language, required this.lesson, required this.onBack});
  final String language;
  final LessonItem lesson;
  final VoidCallback onBack;

  @override
  State<AIPracticeScreen> createState() => _AIPracticeScreenState();
}

class _AIPracticeScreenState extends State<AIPracticeScreen> {
  int countdown = 3;
  bool running = false;
  int elapsed = 0;
  double accuracy = 0;
  Timer? timer;
  Timer? countdownTimer;

  void start() {
    countdown = 3;
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 1) {
        t.cancel();
        setState(() {
          running = true;
          countdown = 0;
        });
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            elapsed += 1;
            accuracy = (50 + math.Random().nextInt(50)).toDouble();
          });
        });
      } else {
        setState(() => countdown -= 1);
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppBar(backgroundColor: kPrimary, foregroundColor: Colors.white, title: const Text('AI Practice Mode'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)),
      Expanded(
        child: Stack(children: [
          Container(color: Colors.black, width: double.infinity, child: Center(child: Text(widget.lesson.thumbnail, style: const TextStyle(fontSize: 130)))),
          if (countdown > 0 && !running) Center(child: Text('$countdown', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold))),
          if (running) Positioned(top: 12, left: 12, right: 12, child: Card(child: ListTile(title: Text('Accuracy ${accuracy.toStringAsFixed(0)}%'), subtitle: Text('Time: ${elapsed}s')))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: running
            ? FilledButton(onPressed: () => setState(() => running = false), style: FilledButton.styleFrom(backgroundColor: kDanger, minimumSize: const Size.fromHeight(50)), child: const Text('Stop Practice'))
            : FilledButton(onPressed: start, style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(50)), child: const Text('Start Practice')),
      ),
    ]);
  }
}
