import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esl_learning_flutter/backend/auth/auth_session_notifier.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/services/video_downloader.dart';
import 'package:esl_learning_flutter/data/app_data.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/screens/splash_screen.dart';
import 'package:esl_learning_flutter/screens/authentication_screen.dart';
import 'package:esl_learning_flutter/screens/onboarding_screen.dart';
import 'package:esl_learning_flutter/screens/home_screen.dart';
import 'package:esl_learning_flutter/screens/lessons_screen.dart';
import 'package:esl_learning_flutter/screens/lesson_detail_screen.dart';
import 'package:esl_learning_flutter/screens/video_screen.dart';
import 'package:esl_learning_flutter/screens/dictionary_screen.dart';
import 'package:esl_learning_flutter/screens/profile_screen.dart';
import 'package:esl_learning_flutter/screens/quiz_screen.dart';
import 'package:esl_learning_flutter/screens/ai_practice_screen.dart';
import 'package:esl_learning_flutter/widgets/lesson_video_player_card.dart';

const bool _debugMode = false; // Set to true for verbose logging

void _log(String message) {
  if (_debugMode) debugPrint(message);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EthSLApp(),
    ),
  );
}

class EthSLApp extends StatelessWidget {
  const EthSLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'miliketapp',
      theme: buildAppTheme(),
      home: const RootApp(),
    );
  }
}

class RootApp extends ConsumerStatefulWidget {
  const RootApp({super.key});

  @override
  ConsumerState<RootApp> createState() => _RootAppState();
}

class _RootAppState extends ConsumerState<RootApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool showSplash = true;
  bool showOnboarding = false;
  String language = 'en';
  AppScreen current = AppScreen.home;
  AppOverlay overlay = AppOverlay.none;
  Category? selectedCategory;
  LessonItem? selectedLesson;
  String quizCategory = 'greetings';
  bool videoDownloadBusy = false;
  double? videoDownloadProgress;
  CancelToken? _videoDownloadCancel;
  final Set<String> completedLessons = {};
  int signsLearned = 0;
  int streak = 0;
  int totalHours = 0;
  String userName = 'Learner';
  String userEmail = 'learner@ethsl.app';
  int tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      boot();
    });
  }

  Future<void> boot() async {
    try {
      // Bootstrap auth with timeout
      try {
        await Future.wait([
          ref.read(authSessionProvider.notifier).bootstrap(),
        ]).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        _log('Auth bootstrap timeout');
      }
    } catch (e) {
      _log('Auth bootstrap error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      language = prefs.getString('preferredLanguage') ?? 'en';
      userName = prefs.getString('userName') ?? 'Learner';
      userEmail = prefs.getString('userEmail') ?? 'learner@ethsl.app';

      final auth = ref.read(authSessionProvider);
      if (auth.isAuthenticated && auth.userId != null) {
        await _hydrateProgressForUser(auth.userId!);
      } else {
        completedLessons.clear();
        completedLessons.addAll(prefs.getStringList('completedLessons') ?? []);
        signsLearned = countCompletedInCurriculum(completedLessons);
        streak = prefs.getInt('streak') ?? 0;
        totalHours = prefs.getInt('totalHours') ?? 0;
      }

      if (auth.isAuthenticated) {
        userName = auth.fullName ?? userName;
        userEmail = auth.email ?? userEmail;
      }

      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      if (!mounted) return;
      setState(() {
        showSplash = false;
        showOnboarding = auth.isAuthenticated && !hasSeenOnboarding;
      });
    } catch (e) {
      _log('Boot sequence error: $e');
      if (!mounted) return;
      setState(() {
        showSplash = false;
      });
    }
  }

  Future<void> _hydrateProgressForUser(int userId) async {
    try {
      final progressRepo = ref.read(progressRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final prefs = await SharedPreferences.getInstance();

      completedLessons.clear();
      completedLessons.addAll(await progressRepo.completedLessonIds(userId));

      final fromPrefs = prefs.getStringList('completedLessons') ?? [];
      for (final id in fromPrefs) {
        try {
          await progressRepo.markLessonCompleted(userId, id);
        } catch (e) {
          _log('Error marking lesson $id completed: $e');
        }
      }
      if (fromPrefs.isNotEmpty) {
        await prefs.remove('completedLessons');
      }
      completedLessons.clear();
      completedLessons.addAll(await progressRepo.completedLessonIds(userId));

      final user = await userRepo.getUserById(userId);
      if (user != null) {
        streak = (user['day_streak'] as int?) ?? 0;
        totalHours = (user['total_practiced'] as int?) ?? 0;
      }
      signsLearned = countCompletedInCurriculum(completedLessons);
      await userRepo.updateCounters(
        userId: userId,
        signsLearned: signsLearned,
        dayStreak: streak,
        totalPracticed: totalHours,
      );
    } catch (e) {
      _log('Error hydrating progress for user $userId: $e');
    }
  }

  Future<void> _hydrateAfterAuth(int userId) async {
    await _hydrateProgressForUser(userId);
    if (mounted) setState(() {});
  }

  void _clearProgressState() {
    completedLessons.clear();
    signsLearned = 0;
    streak = 0;
    totalHours = 0;
  }

  Future<void> _markLessonLearnedOnAccount(int userId, String lessonId) async {
    if (!completedLessons.add(lessonId)) return;
    await ref.read(progressRepositoryProvider).markLessonCompleted(
          userId,
          lessonId,
        );
    signsLearned = countCompletedInCurriculum(completedLessons);
    await ref.read(userRepositoryProvider).updateCounters(
      userId: userId,
      signsLearned: signsLearned,
    );
    await persist();
    if (mounted) setState(() {});
  }

  Future<LessonItem> _lessonWithDbMedia(LessonItem base) async {
    final row = await ref.read(lessonRepositoryProvider).lessonById(base.id);
    if (row == null) return base;
    return LessonItem(
      id: base.id,
      categoryId: base.categoryId,
      sign: base.sign,
      signAm: base.signAm,
      thumbnail: base.thumbnail,
      videoUrl: row['video_url'] as String?,
      videoLocalPath: row['video_local_path'] as String?,
    );
  }

  Future<void> _openLessonWithMedia(LessonItem lesson) async {
    final merged = await _lessonWithDbMedia(lesson);
    if (!mounted) return;
    setState(() {
      selectedLesson = merged;
      overlay = AppOverlay.video;
    });
  }

  Future<void> _openLessonWithMediaFromDictionary(LessonItem lesson) async {
    final merged = await _lessonWithDbMedia(lesson);
    if (!mounted) return;
    setState(() {
      selectedCategory = categories.firstWhere((c) => c.id == lesson.categoryId);
      selectedLesson = merged;
      overlay = AppOverlay.video;
    });
  }

  Future<void> _replaceSelectedLesson(LessonItem lesson) async {
    final merged = await _lessonWithDbMedia(lesson);
    if (!mounted) return;
    setState(() => selectedLesson = merged);
  }

  Future<void> _downloadLessonVideo() async {
    final lesson = selectedLesson;
    if (lesson == null) return;
    final downloadUrl = lesson.videoUrl?.trim() ?? sampleStreamUriForLesson(lesson).toString();
    if (downloadUrl.isEmpty) return;

    _videoDownloadCancel?.cancel();
    _videoDownloadCancel = CancelToken();
    setState(() {
      videoDownloadBusy = true;
      videoDownloadProgress = 0;
    });
    try {
      final dir = await getApplicationSupportDirectory();
      final dest = VideoDownloader.defaultLessonVideoPath(dir, lesson.id);
      await ref.read(videoDownloaderProvider).downloadVideoToFile(
            urlOrFileId: downloadUrl,
            destinationPath: dest,
            cancelToken: _videoDownloadCancel,
            onProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => videoDownloadProgress = received / total);
            },
          );
      await ref.read(lessonRepositoryProvider).setLocalVideoPath(lesson.id, dest);
      final merged = lesson.copyWith(videoLocalPath: dest);
      if (!mounted) return;
      setState(() {
        selectedLesson = merged;
        videoDownloadBusy = false;
        videoDownloadProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video saved for offline playback.')),
      );
    } catch (e) {
      _log('Video download failed: $e');
      if (!mounted) return;
      setState(() {
        videoDownloadBusy = false;
        videoDownloadProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredLanguage', language);
    await prefs.setString('userName', userName);
    await prefs.setString('userEmail', userEmail);
    final auth = ref.read(authSessionProvider);
    if (auth.isAuthenticated && auth.userId != null) {
      await ref.read(userRepositoryProvider).updateCounters(
            userId: auth.userId!,
            signsLearned: signsLearned,
            dayStreak: streak,
            totalPracticed: totalHours,
          );
    } else {
      await prefs.setStringList('completedLessons', completedLessons.toList());
      await prefs.setInt('signsLearned', signsLearned);
      await prefs.setInt('streak', streak);
      await prefs.setInt('totalHours', totalHours);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
      if (!next.isAuthenticated) {
        if (prev?.isAuthenticated == true) {
          _clearProgressState();
        }
        return;
      }
      if (next.userId != null) {
        final becameAuthed = prev?.isAuthenticated != true;
        final switchedUser =
            prev?.userId != null && prev!.userId != next.userId;
        if (becameAuthed || switchedUser) {
          unawaited(_hydrateAfterAuth(next.userId!));
        }
      }
    });

    if (showSplash) return const SplashScreen();

    final auth = ref.watch(authSessionProvider);
    if (!auth.isAuthenticated) {
      return const AuthenticationScreen();
    }

    if (showOnboarding) {
      return OnboardingScreen(
        initialLanguage: language,
        onDone: (lang) async {
          language = lang;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasSeenOnboarding', true);
          await prefs.setString('preferredLanguage', lang);
          final uid = ref.read(authSessionProvider).userId;
          if (uid != null) {
            await ref.read(userRepositoryProvider).updateLanguage(uid, lang);
            ref
                .read(authSessionProvider.notifier)
                .applyLanguagePreference(lang);
          }
          if (!mounted) return;
          setState(() => showOnboarding = false);
        },
      );
    }

    final displayName = auth.fullName ?? userName;
    final displayEmail = auth.email ?? userEmail;

    Widget body;
    switch (overlay) {
      case AppOverlay.lessonDetail:
        body = selectedCategory == null
            ? _buildFallbackBody('No lesson category selected yet.')
            : LessonDetailScreen(
                language: language,
                category: selectedCategory!,
                completedLessonIds: completedLessons,
                onBack: () => setState(() => overlay = AppOverlay.none),
                onOpenLesson: (lesson) =>
                    unawaited(_openLessonWithMedia(lesson)),
              );
        break;
      case AppOverlay.video:
        body = selectedLesson == null
            ? _buildFallbackBody('No lesson selected yet.')
            : VideoScreen(
                language: language,
                lesson: selectedLesson!,
                downloadInProgress: videoDownloadBusy,
                downloadProgress: videoDownloadProgress,
                showDownloadButton: true,
                onDownloadVideo: _downloadLessonVideo,
                onBack: () => setState(() => overlay = AppOverlay.lessonDetail),
                onLessonChanged: (lesson) =>
                    unawaited(_replaceSelectedLesson(lesson)),
                onStartQuiz: () => setState(() {
                  quizCategory = selectedLesson!.categoryId;
                  overlay = AppOverlay.quiz;
                }),
                onStartAI: () =>
                    setState(() => overlay = AppOverlay.aiPractice),
                onLearned: () {
                  final uid = ref.read(authSessionProvider).userId;
                  final lid = selectedLesson?.id;
                  if (uid == null || lid == null) return;
                  unawaited(_markLessonLearnedOnAccount(uid, lid));
                },
              );
        break;
      case AppOverlay.quiz:
        body = QuizScreen(
          language: language,
          categoryId: quizCategory,
          onBack: () => setState(() => overlay = AppOverlay.none),
          onQuizComplete: (score, totalQuestions) async {
            final uid = auth.userId;
            if (uid == null) return;
            await ref.read(quizRepositoryProvider).insertResult(
                  userId: uid,
                  categoryId: quizCategory,
                  score: score,
                  totalQuestions: totalQuestions,
                );
          },
        );
        break;
      case AppOverlay.aiPractice:
        body = selectedLesson == null
            ? _buildFallbackBody('No lesson selected for practice.')
            : AIPracticeScreen(
                language: language,
                lesson: selectedLesson!,
                onBack: () => setState(() => overlay = AppOverlay.video),
              );
        break;
      case AppOverlay.none:
        switch (current) {
          case AppScreen.home:
            body = HomeScreen(
              language: language,
              completedLessonIds: completedLessons,
              onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onOpenCategory: (c) => setState(() {
                selectedCategory = c;
                overlay = AppOverlay.lessonDetail;
              }),
              onOpenQuiz: (id) => setState(() {
                quizCategory = id;
                overlay = AppOverlay.quiz;
              }),
            );
            break;
          case AppScreen.lessons:
            body = LessonsScreen(
              language: language,
              completedLessonIds: completedLessons,
              onOpenAIPractice: () =>
                  setState(() => overlay = AppOverlay.aiPractice),
              onOpenCategory: (c) => setState(() {
                selectedCategory = c;
                overlay = AppOverlay.lessonDetail;
              }),
            );
            break;
          case AppScreen.dictionary:
            body = DictionaryScreen(
              language: language,
              userId: auth.userId,
              onOpenLesson: (lesson) =>
                  unawaited(_openLessonWithMediaFromDictionary(lesson)),
            );
            break;
          case AppScreen.profile:
            body = ProfileScreen(
              language: language,
              userName: displayName,
              userEmail: displayEmail,
              signsLearned: signsLearned,
              streak: streak,
              totalHours: totalHours,
              onLanguageChanged: (value) async {
                language = value;
                final uid = auth.userId;
                if (uid != null) {
                  await ref
                      .read(userRepositoryProvider)
                      .updateLanguage(uid, value);
                  ref
                      .read(authSessionProvider.notifier)
                      .applyLanguagePreference(value);
                }
                await persist();
                setState(() {});
              },
              onProfileSaved: (name, email) async {
                userName = name;
                userEmail = email;
                ref
                    .read(authSessionProvider.notifier)
                    .applyLocalProfile(fullName: name, email: email);
                await persist();
                setState(() {});
              },
              onLogout: () async {
                await ref.read(authSessionProvider.notifier).signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('hasSeenOnboarding');
                if (!mounted) return;
                setState(() {
                  overlay = AppOverlay.none;
                  current = AppScreen.home;
                  tabIndex = 0;
                });
              },
            );
            break;
        }
        break;
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(displayName, displayEmail),
      body: SafeArea(child: body),
      bottomNavigationBar:
          overlay == AppOverlay.none ||
              overlay == AppOverlay.lessonDetail ||
              overlay == AppOverlay.aiPractice ||
              overlay == AppOverlay.quiz
          ? _buildBottomNavigation()
          : null,
    );
  }

  Widget _buildBottomNavigation() {
    final selectedIndex = overlay == AppOverlay.aiPractice ? 3 : tabIndex;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            _buildBottomNavItem(
              index: 0,
              selectedIndex: selectedIndex,
              label: 'Home',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
            ),
            _buildBottomNavItem(
              index: 1,
              selectedIndex: selectedIndex,
              label: 'Lessons',
              icon: Icons.school_outlined,
              selectedIcon: Icons.school_rounded,
            ),
            _buildBottomNavItem(
              index: 2,
              selectedIndex: selectedIndex,
              label: 'Dictionary',
              icon: Icons.menu_book_outlined,
              selectedIcon: Icons.menu_book_rounded,
            ),
            _buildBottomNavItem(
              index: 3,
              selectedIndex: selectedIndex,
              label: 'AI Practice',
              icon: Icons.videocam_outlined,
              selectedIcon: Icons.videocam,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required int selectedIndex,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final isSelected = selectedIndex == index;
    final onColor = index == 3 ? const Color(0xFF202020) : kPrimary;
    final offColor = const Color(0xFF8A8A8A);
    final hasAIPill = index == 3;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          tabIndex = index;
          if (index == 3) {
            selectedLesson ??=
                (lessonsByCategory['greetings'] ?? const []).isNotEmpty
                ? lessonsByCategory['greetings']!.first
                : null;
            overlay = AppOverlay.aiPractice;
            return;
          }
          current = AppScreen.values[index];
          overlay = AppOverlay.none;
        }),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: index == 3
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasAIPill ? const Color(0xFFFFC107) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: index == 3 ? 24 : 20,
                  color: hasAIPill
                      ? const Color(0xFF202020)
                      : (isSelected ? onColor : offColor),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: index == 3 ? 11.5 : 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: hasAIPill
                        ? const Color(0xFF202020)
                        : (isSelected ? onColor : offColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppDrawer(String displayName, String displayEmail) {
    return Drawer(
      width: 320,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              color: kPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Miliketapp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ethiopian Sign Language',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: kBackground,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kSurfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kSurfaceContainerHighest),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: kAccent,
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: kOnSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kOnSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Text(
                        'ETHIOPIAN NATIONAL ASSOCIATION OF THE DEAF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: Color(0xFF3F4941),
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: kOutlineVariant,
                    ),
                    _menuItem(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          current = AppScreen.profile;
                          tabIndex = AppScreen.profile.index;
                          overlay = AppOverlay.none;
                        });
                      },
                    ),
                    _menuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () => _showDrawerMessage('Settings'),
                    ),
                    _sectionTitle('HELP & SUPPORT'),
                    _menuItem(
                      icon: Icons.help_outline,
                      title: 'Help',
                      onTap: () => _showDrawerMessage('Help'),
                    ),
                    _menuItem(
                      icon: Icons.menu_book_outlined,
                      title: 'How to use',
                      onTap: () => _showDrawerMessage('How to use'),
                    ),
                    _menuItem(
                      icon: Icons.contact_support_outlined,
                      title: 'Contact ENAD',
                      onTap: () => _showDrawerMessage('Contact ENAD'),
                    ),
                    _sectionTitle('ABOUT'),
                    _menuItem(
                      icon: Icons.info_outline,
                      title: 'App Info',
                      onTap: () => _showDrawerMessage('App Info'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tag, color: kPrimaryDark),
                      title: const Text(
                        'Version',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      trailing: const Text(
                        '1.0.0',
                        style: TextStyle(color: kOnSurfaceVariant),
                      ),
                    ),
                    _menuItem(
                      icon: Icons.stars_outlined,
                      title: 'Credits',
                      onTap: () => _showDrawerMessage('Credits'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
    );
  }

  Widget _buildFallbackBody(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: kPrimaryDark),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: kOnSurface,
          fontSize: 15,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: kSurfaceContainerLow,
      horizontalTitleGap: 12,
      minLeadingWidth: 0,
      onTap: onTap,
    );
  }

  void _showDrawerMessage(String title) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title coming soon')));
  }
}
