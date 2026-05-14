import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.initialLanguage, required this.onDone});
  final String initialLanguage;
  final ValueChanged<String> onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int index = 0;
  late String language = widget.initialLanguage;

  final slides = const [
    ('✋', 'Learn Ethiopian Sign Language for free', 'የኢትዮጵያ የምልክት ቋንቋ በነጻ ይማሩ'),
    ('📱', 'Works offline - download lessons once', 'ከመስመር ውጭ ይሰራል - አንዴ ያውርዱ'),
    ('🇪🇹', 'Culturally relevant content', 'ባህላዊ ተገቢ ይዘት'),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = slides[index];
    final isLast = index == slides.length - 1;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'am', label: Text('አማርኛ'))],
              selected: {language},
              onSelectionChanged: (selection) => setState(() => language = selection.first),
            )
          ]),
          const Spacer(),
          Text(slide.$1, style: const TextStyle(fontSize: 92)),
          const SizedBox(height: 14),
          Text(language == 'en' ? slide.$2 : slide.$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: i == index ? 28 : 8, height: 8, decoration: BoxDecoration(color: i == index ? kPrimary : Colors.grey.shade400, borderRadius: BorderRadius.circular(100)))),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => isLast ? widget.onDone(language) : setState(() => index += 1),
            style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(52)),
            child: Text(isLast ? (language == 'en' ? 'Get Started' : 'ይጀምሩ') : (language == 'en' ? 'Next' : 'ቀጣይ')),
          ),
          if (!isLast) TextButton(onPressed: () => widget.onDone(language), child: Text(language == 'en' ? 'Skip' : 'ዝለል')),
        ]),
      ),
    );
  }
}
