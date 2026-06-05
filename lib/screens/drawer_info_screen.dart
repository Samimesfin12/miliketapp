import 'package:flutter/material.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

enum DrawerInfoPage { help, howToUse, contactEnad, appInfo, credits }

class DrawerInfoScreen extends StatelessWidget {
  const DrawerInfoScreen({super.key, required this.page});

  final DrawerInfoPage page;

  static const appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        children: _body,
      ),
    );
  }

  String get _title => switch (page) {
        DrawerInfoPage.help => 'Help',
        DrawerInfoPage.howToUse => 'How to use',
        DrawerInfoPage.contactEnad => 'Contact ENAD',
        DrawerInfoPage.appInfo => 'App Info',
        DrawerInfoPage.credits => 'Credits',
      };

  List<Widget> get _body => switch (page) {
        DrawerInfoPage.help => _helpContent,
        DrawerInfoPage.howToUse => _howToUseContent,
        DrawerInfoPage.contactEnad => _contactContent,
        DrawerInfoPage.appInfo => _appInfoContent,
        DrawerInfoPage.credits => _creditsContent,
      };

  static Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kPrimaryDark,
          ),
        ),
      );

  static Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: kOnSurface,
          ),
        ),
      );

  static Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kPrimaryDark,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: kOnSurface,
                ),
              ),
            ),
          ],
        ),
      );

  static Widget _infoCard({required String title, required String body}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSurfaceContainerHighest),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: kPrimaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: kOnSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  static List<Widget> get _helpContent => [
        _infoCard(
          title: 'Welcome to Miliketapp',
          body:
              'Miliketapp helps you learn Ethiopian Sign Language (EthSL) through '
              'video lessons, quizzes, a sign dictionary, and optional AI hand-practice.',
        ),
        _sectionTitle('Frequently asked questions'),
        _infoCard(
          title: 'Video will not play',
          body:
              'Sign videos are hosted on Google Drive. Use a stable internet connection, '
              'wait for “Preparing sign video…”, or tap Download for offline on the lesson screen. '
              'If a sign still fails, the file may need to be shared publicly by your teacher.',
        ),
        _infoCard(
          title: 'Progress and completed lessons',
          body:
              'Your progress is saved on this device. Watch most of a lesson video or pass a quiz '
              'to mark a sign as learned. Check the Lessons screen for category progress bars.',
        ),
        _infoCard(
          title: 'Dictionary',
          body:
              'Open Dictionary from the bottom bar to search signs in English or Amharic and '
              'jump straight to the lesson video.',
        ),
        _infoCard(
          title: 'AI practice',
          body:
              'AI practice uses your camera to compare hand shapes to a template. '
              'Use good lighting, keep your hand in frame, and hold the sign steady.',
        ),
        _infoCard(
          title: 'Account and language',
          body:
              'Sign in to sync progress when available. Change display language (English / Amharic) '
              'from Profile in the drawer or bottom navigation.',
        ),
      ];

  static List<Widget> get _howToUseContent => [
        _paragraph(
          'Follow these steps to get the most from Miliketapp. '
          'You can learn at your own pace—repeat videos as often as you need.',
        ),
        _sectionTitle('1. Start on Home'),
        _bullet('See your streak, signs learned, and quick links to categories.'),
        _bullet('Tap a category card to open lessons for that topic.'),
        _sectionTitle('2. Learn a sign'),
        _bullet('Open Lessons, pick a category (Greetings, Family, Food, etc.).'),
        _bullet('Tap a sign to watch the EthSL video with mirror and speed controls.'),
        _bullet('Use Download for offline if you will study without internet.'),
        _sectionTitle('3. Practice'),
        _bullet('Tap Practice Quiz after watching to test recognition.'),
        _bullet('Try AI Practice on supported signs for real-time hand feedback.'),
        _sectionTitle('4. Review'),
        _bullet('Use Dictionary to find a sign by name anytime.'),
        _bullet('Track completion on each category card (e.g. 3/19).'),
        _sectionTitle('Tips'),
        _bullet('Mirror mode flips the video—helpful when copying the signer.'),
        _bullet('Slow playback (0.5×–0.75×) helps with new or fast movements.'),
        _bullet('Use Previous / Next on the video screen to move through a category.'),
      ];

  static List<Widget> get _contactContent => [
        _infoCard(
          title: 'Ethiopian National Association of the Deaf (ENAD)',
          body:
              'ENAD advocates for Deaf rights, Ethiopian Sign Language, and accessible '
              'education across Ethiopia. Miliketapp is developed in support of EthSL learning.',
        ),
        _sectionTitle('Get in touch'),
        _infoCard(
          title: 'ENAD — Addis Ababa',
          body:
              'Visit or write to ENAD for programs, interpreter services, community events, '
              'and partnership opportunities related to Deaf education.',
        ),
        _paragraph(
          'Email: enad.ethiopia@example.org\n'
          'Phone: +251 11 000 0000\n'
          'Office hours: Monday–Friday, 8:30 AM – 5:00 PM',
        ),
        _sectionTitle('App support'),
        _paragraph(
          'For technical issues with Miliketapp (videos, login, crashes), contact your '
          'school or project coordinator first. Include your device model and a screenshot '
          'of any error message.',
        ),
        _infoCard(
          title: 'Learning feedback',
          body:
              'If a sign video is wrong or missing, tell your instructor so the correct '
              'Google Drive link can be added to the lesson.',
        ),
      ];

  static List<Widget> get _appInfoContent => [
        Center(
          child: Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: kPrimaryDark,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.sign_language_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const Center(
          child: Text(
            'Miliketapp',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kOnSurface,
            ),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              'Ethiopian Sign Language',
              style: TextStyle(fontSize: 14, color: kOnSurfaceVariant),
            ),
          ),
        ),
        _infoCard(
          title: 'Purpose',
          body:
              'Miliketapp is a mobile learning companion for Ethiopian Sign Language. '
              'It combines structured lessons, visual quizzes, a searchable dictionary, '
              'and practice tools designed for Deaf learners, hearing family members, '
              'teachers, and interpreters.',
        ),
        _infoCard(
          title: 'Version',
          body: 'Release $appVersion — local-first storage, video lessons, quizzes, and AI practice.',
        ),
        _infoCard(
          title: 'Privacy',
          body:
              'Lesson progress and account details are stored on your device. '
              'Sign-in uses a local account database; do not share your password.',
        ),
        _infoCard(
          title: 'Content',
          body:
              'Sign videos and lesson lists are curated for EthSL. Categories include '
              'greetings, family, food, shopping, emergency phrases, and numbers.',
        ),
      ];

  static List<Widget> get _creditsContent => [
        _paragraph(
          'Miliketapp is made possible through collaboration with the Deaf community, '
          'educators, and technology volunteers.',
        ),
        _sectionTitle('Organizations'),
        _bullet('Ethiopian National Association of the Deaf (ENAD) — community guidance.'),
        _sectionTitle('Sign content'),
        _bullet('EthSL signers and teachers who record and review lesson videos.'),
        _bullet('Lesson authors who prepare English and Amharic labels.'),
        _sectionTitle('Technology'),
        _bullet('Built with Flutter for Android (and supported platforms).'),
        _bullet('On-device AI hand templates powered by TensorFlow Lite.'),
        _bullet('Video hosting via Google Drive with offline download support.'),
        _sectionTitle('Acknowledgements'),
        _paragraph(
          'Thank you to every learner who provides feedback to improve lessons and accessibility. '
          'Special thanks to families and schools promoting Ethiopian Sign Language literacy.',
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '© 2026 Miliketapp',
            style: TextStyle(fontSize: 12, color: kOnSurfaceVariant),
          ),
        ),
      ];
}
