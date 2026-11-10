import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:esl_learning_flutter/backend/ai/mediapipe_processor.dart';
import 'package:esl_learning_flutter/backend/controllers/live_translator_controller.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/services/translator_tts_service.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Live Translator Screen  — real AI pipeline
// Tab 1: Sign → Speech/Text (MediaPipe + multi-sign PoseMatcher + TTS)
// Tab 2: Speech → Text (SpeechToText + TTS readback)
// ─────────────────────────────────────────────────────────────────────────────

class LiveTranslatorScreen extends ConsumerStatefulWidget {
  const LiveTranslatorScreen({
    super.key,
    required this.language,
    required this.onBack,
  });

  final String language;
  final VoidCallback onBack;

  @override
  ConsumerState<LiveTranslatorScreen> createState() =>
      _LiveTranslatorScreenState();
}

class _LiveTranslatorScreenState extends ConsumerState<LiveTranslatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F4),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              language: widget.language,
              onBack: widget.onBack,
              tabController: _tabController,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SignToSpeechTab(
                      language: widget.language, ref: ref),
                  _SpeechToTextTab(language: widget.language),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.language,
    required this.onBack,
    required this.tabController,
  });

  final String language;
  final VoidCallback onBack;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kPrimaryDark,
        boxShadow: [BoxShadow(color: Color(0x28000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Ai Translator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TabPill(
                    index: 0, tabController: tabController,
                    icon: Icons.sign_language_outlined,
                    label: 'Sign → Speech/Text',
                  ),
                  _TabPill(
                    index: 1, tabController: tabController,
                    icon: Icons.mic_outlined,
                    label: 'Speech → Text',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.index, required this.tabController,
    required this.icon, required this.label,
  });

  final int index;
  final TabController tabController;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isSelected = tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? kPrimaryDark : Colors.white70),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kPrimaryDark : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Sign → Speech / Text  (REAL PIPELINE)
// ─────────────────────────────────────────────────────────────────────────────

class _SignToSpeechTab extends ConsumerStatefulWidget {
  const _SignToSpeechTab({required this.language, required this.ref});
  final String language;
  final WidgetRef ref;

  @override
  ConsumerState<_SignToSpeechTab> createState() => _SignToSpeechTabState();
}

class _SignToSpeechTabState extends ConsumerState<_SignToSpeechTab> {

  // ── Camera ───────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  StreamSubscription<List<double>?>? _landmarkSub;
  bool _isCameraReady = false;
  bool _isLive = false;
  bool _isProcessing = false;
  DateTime _lastFrameTime = DateTime.now();

  // ── Recognition ──────────────────────────────────────────────────────────
  final LiveTranslatorController _controller = LiveTranslatorController();
  bool _isContinuous = true;
  bool _loadingTemplates = true;
  int _templateCount = 0;

  // Current best match (live, may not yet be confirmed)
  String _currentSignEn = '';
  String _currentSignAm = '';
  double _currentConfidence = 0.0;
  bool _handDetected = false;

  // Confirmed translation sentence (accumulates confirmed signs)
  final List<String> _sentenceEn = [];
  final List<String> _sentenceAm = [];
  String _lastAnnouncedSignId = '';

  // ── TTS ──────────────────────────────────────────────────────────────────
  bool _autoSpeak = true;
  double _speakerVolume = 0.85;
  final TranslatorTtsService _tts = TranslatorTtsService.instance;

  // ── UI animation ─────────────────────────────────────────────────────────
  Timer? _animTimer;
  double _animPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _animTimer = Timer.periodic(const Duration(milliseconds: 50),
        (_) { if (mounted) setState(() => _animPhase += 0.08); });
    _init();
  }

  Future<void> _init() async {
    // Load templates first (non-blocking — camera starts in parallel)
    final db = widget.ref.read(sqliteHelperProvider);
    await _controller.loadAllTemplates(db);
    if (mounted) {
      setState(() {
        _loadingTemplates = false;
        _templateCount = _controller.templateCount;
      });
    }
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await MediaPipeProcessor.ensureInitialized();

      _landmarkSub = MediaPipeProcessor.landmarkUpdates.listen(
        _onLandmarks,
        onError: (Object e) => debugPrint('Landmark stream error: $e'),
      );

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() { _isCameraReady = true; _isLive = true; });

      await _cameraController!.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('LiveTranslator camera error: $e');
    }
  }

  void _onCameraFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 100) return; // 10 FPS
    if (_isProcessing) return;
    _isProcessing = true;
    _lastFrameTime = now;
    try {
      MediaPipeProcessor.feedCameraImage(image, _cameraDescription!);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onLandmarks(List<double>? coords) async {
    if (!mounted) return;
    final detected = coords != null;
    if (detected != _handDetected) {
      setState(() => _handDetected = detected);
    }
    if (coords == null) {
      _controller.clearBuffer();
      if (mounted) setState(() { _currentConfidence = 0.0; _currentSignEn = ''; _currentSignAm = ''; });
      return;
    }

    if (_isContinuous) {
      // ── CONTINUOUS MODE: 5-frame buffer + 1.5 s stability debounce ────────
      final result = _controller.processLandmarks(coords);
      if (!mounted) return;

      if (result == null) {
        setState(() { _currentConfidence = 0.0; _currentSignEn = ''; _currentSignAm = ''; });
        return;
      }

      setState(() {
        _currentSignEn = result.labelEn;
        _currentSignAm = result.labelAm;
        _currentConfidence = result.confidence;
      });

      if (result.isConfirmed && result.signId != _lastAnnouncedSignId) {
        _lastAnnouncedSignId = result.signId;
        HapticFeedback.heavyImpact();
        setState(() {
          _sentenceEn.add(result.labelEn);
          _sentenceAm.add(result.labelAm);
        });
        await _tts.setVolume(_speakerVolume);
        if (_autoSpeak) await _tts.speakBoth(result.labelEn, result.labelAm);
        await Future.delayed(const Duration(milliseconds: 2100));
        if (mounted) _lastAnnouncedSignId = '';
      }
    } else {
      // ── SINGLE SIGN MODE: instant confirm on first frame above threshold ─
      // Clear buffer every frame so each snapshot is evaluated fresh.
      _controller.clearBuffer();
      final result = _controller.processLandmarksSingleShot(coords);
      if (!mounted) return;

      if (result == null) {
        setState(() { _currentConfidence = 0.0; _currentSignEn = ''; _currentSignAm = ''; });
        return;
      }

      setState(() {
        _currentSignEn = result.labelEn;
        _currentSignAm = result.labelAm;
        _currentConfidence = result.confidence;
      });

      // In single-sign mode, ANY frame above threshold counts as a confirmed sign.
      // We still debounce using _lastAnnouncedSignId to avoid flooding.
      if (result.confidence >= 0.75 && result.signId != _lastAnnouncedSignId) {
        _lastAnnouncedSignId = result.signId;
        HapticFeedback.heavyImpact();
        setState(() {
          _sentenceEn.add(result.labelEn);
          _sentenceAm.add(result.labelAm);
        });
        await _tts.setVolume(_speakerVolume);
        if (_autoSpeak) await _tts.speakBoth(result.labelEn, result.labelAm);
        // Shorter cooldown for single-sign snapping
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) _lastAnnouncedSignId = '';
      }
    }
  }

  Future<void> _speakSentence() async {
    if (_sentenceEn.isEmpty && _currentSignEn.isEmpty) return;
    final en = _sentenceEn.isNotEmpty ? _sentenceEn.join(', ') : _currentSignEn;
    final am = _sentenceAm.isNotEmpty ? _sentenceAm.join('፣ ') : _currentSignAm;
    await _tts.setVolume(_speakerVolume);
    await _tts.speakBoth(en, am);
  }

  void _copyToClipboard() {
    final text = '${_sentenceEn.join(', ')}\n${_sentenceAm.join('፣ ')}';
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _clearOutput() {
    setState(() {
      _sentenceEn.clear();
      _sentenceAm.clear();
      _currentSignEn = '';
      _currentSignAm = '';
      _currentConfidence = 0.0;
      _lastAnnouncedSignId = '';
    });
    _controller.clearBuffer();
    _tts.stop();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _landmarkSub?.cancel();
    _cameraController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sentenceEnText = _sentenceEn.join(', ');
    final sentenceAmText = _sentenceAm.join('፣ ');

    // What to show in the translation card
    final displayEn = sentenceEnText.isNotEmpty
        ? sentenceEnText
        : (_currentSignEn.isNotEmpty ? _currentSignEn : '');
    final displayAm = sentenceAmText.isNotEmpty
        ? sentenceAmText
        : (_currentSignAm.isNotEmpty ? _currentSignAm : '');

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      children: [
        // ── Template loading banner ─────────────────────────────────────
        if (_loadingTemplates)
          _InfoBanner(
            color: const Color(0xFFE3F2FD),
            icon: Icons.hourglass_top_rounded,
            iconColor: Colors.blue,
            text: 'Loading trained sign templates…',
          )
        else if (_templateCount == 0)
          _InfoBanner(
            color: const Color(0xFFFFEBEE),
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.orange,
            text: 'No trained signs found in database. Train signs in AI Practice first.',
          )
        else
          _InfoBanner(
            color: const Color(0xFFE8F5E9),
            icon: Icons.check_circle_outline,
            iconColor: kPrimary,
            text: 'Ready — $_templateCount trained sign${_templateCount == 1 ? '' : 's'} loaded',
          ),
        const SizedBox(height: 8),

        // ── Camera card ─────────────────────────────────────────────────
        _CameraCard(
          cameraController: _cameraController,
          isCameraReady: _isCameraReady,
          isLive: _isLive,
          handDetected: _handDetected,
          animPhase: _animPhase,
          currentSignEn: _currentSignEn,
          currentSignAm: _currentSignAm,
          confidence: _currentConfidence,
        ),
        const SizedBox(height: 10),

        // ── Model flow toggle ───────────────────────────────────────────
        _ModelFlowRow(
          isContinuous: _isContinuous,
          onToggle: (v) => setState(() { _isContinuous = v; _controller.clearBuffer(); }),
        ),
        const SizedBox(height: 10),

        // ── Translation card ────────────────────────────────────────────
        _TranslationCard(
          amText: displayAm,
          enText: displayEn,
          autoSpeak: _autoSpeak,
          speakerVolume: _speakerVolume,
          onAutoSpeakToggle: (v) => setState(() => _autoSpeak = v),
          onVolumeChanged: (v) async {
            setState(() => _speakerVolume = v);
            await _tts.setVolume(v);
          },
          onSpeak: _speakSentence,
          onCopy: _copyToClipboard,
          onClear: _clearOutput,
          language: widget.language,
        ),
        const SizedBox(height: 10),

        // ── Haptic banner ───────────────────────────────────────────────
        _HapticBanner(templateCount: _templateCount),
      ],
    );
  }
}

// ─── Info Banner ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color, required this.icon,
    required this.iconColor, required this.text,
  });
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─── Camera Card ─────────────────────────────────────────────────────────────

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.cameraController,
    required this.isCameraReady,
    required this.isLive,
    required this.handDetected,
    required this.animPhase,
    required this.currentSignEn,
    required this.currentSignAm,
    required this.confidence,
  });

  final CameraController? cameraController;
  final bool isCameraReady;
  final bool isLive;
  final bool handDetected;
  final double animPhase;
  final String currentSignEn;
  final String currentSignAm;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview or placeholder
            if (isCameraReady && cameraController != null)
              CameraPreview(cameraController!)
            else
              _CameraPlaceholder(animPhase: animPhase),

            // Dashed detection box
            if (handDetected)
              Positioned(
                left: 40, right: 40, top: 30, bottom: 70,
                child: CustomPaint(painter: _DashedBoxPainter()),
              ),

            // LIVE badge + engine tag
            Positioned(
              top: 10, left: 12,
              child: Row(
                children: [
                  _DarkBadge(child: Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(
                      color: isLive ? const Color(0xFF4CAF50) : Colors.grey,
                      shape: BoxShape.circle,
                    )),
                    const SizedBox(width: 5),
                    Text('LIVE', style: TextStyle(
                      color: isLive ? Colors.white : Colors.grey,
                      fontSize: 11, fontWeight: FontWeight.w700,
                    )),
                  ])),
                  const SizedBox(width: 6),
                  _DarkBadge(child: const Text('MediaPipe TFLite',
                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500))),
                ],
              ),
            ),

            // Icon controls top-right
            Positioned(
              top: 10, right: 12,
              child: Row(children: [
                _IconBtn(icon: Icons.flash_off_outlined),
                const SizedBox(width: 6),
                _IconBtn(icon: Icons.flip_camera_ios_outlined),
                const SizedBox(width: 6),
                _IconBtn(icon: Icons.grid_on_outlined),
              ]),
            ),

            // Bottom: detected sign label + confidence
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: currentSignEn.isNotEmpty
                          ? _DarkBadge(
                              key: ValueKey(currentSignEn),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Text('🤟', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Flexible(child: Text(
                                  'Sign: $currentSignAm ($currentSignEn)',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                )),
                              ]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (confidence > 0.5)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: confidence >= 0.75
                            ? const Color(0xFF00502A).withValues(alpha: 0.9)
                            : Colors.orange.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          confidence >= 0.75 ? Icons.check_circle_outline : Icons.pending_outlined,
                          color: Colors.white, size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(confidence * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
      ),
      child: child,
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.animPhase});
  final double animPhase;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Stack(children: [
        Center(child: CustomPaint(
          size: const Size(160, 180),
          painter: _HandSkeletonPainter(phase: animPhase),
        )),
        const Align(
          alignment: Alignment(0, 0.6),
          child: Text('Point camera at your hand',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: Colors.white70, size: 16),
    );
  }
}

// ─── Model Flow Row ───────────────────────────────────────────────────────────

class _ModelFlowRow extends StatelessWidget {
  const _ModelFlowRow({required this.isContinuous, required this.onToggle});
  final bool isContinuous;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E2E1)),
      ),
      child: Row(children: [
        const Icon(Icons.account_tree_outlined, size: 18, color: kPrimaryDark),
        const SizedBox(width: 8),
        const Text('Model Flow', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const Spacer(),
        _FlowBtn(label: 'Continuous', selected: isContinuous, onTap: () => onToggle(true)),
        const SizedBox(width: 8),
        _FlowBtn(label: 'Single Sign', selected: !isContinuous, onTap: () => onToggle(false)),
      ]),
    );
  }
}

class _FlowBtn extends StatelessWidget {
  const _FlowBtn({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? kPrimaryDark : const Color(0xFFF0EDED),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF555555),
        )),
      ),
    );
  }
}

// ─── Translation Card ─────────────────────────────────────────────────────────

class _TranslationCard extends StatelessWidget {
  const _TranslationCard({
    required this.amText,
    required this.enText,
    required this.autoSpeak,
    required this.speakerVolume,
    required this.onAutoSpeakToggle,
    required this.onVolumeChanged,
    required this.onSpeak,
    required this.onCopy,
    required this.onClear,
    required this.language,
  });

  final String amText;
  final String enText;
  final bool autoSpeak;
  final double speakerVolume;
  final ValueChanged<bool> onAutoSpeakToggle;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final String language;

  @override
  Widget build(BuildContext context) {
    final hasContent = amText.isNotEmpty || enText.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("GE'EZ & ENGLISH SYNTHESIS",
                style: TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            ),
            const Spacer(),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.translate, size: 18, color: kPrimary),
            ),
          ]),
          const SizedBox(height: 14),

          // Amharic text (large)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasContent && amText.isNotEmpty
                ? Text(amText,
                    key: ValueKey(amText),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.3, letterSpacing: -0.5))
                : Text(
                    language == 'en' ? 'Perform a sign to translate…' : 'ምልክት ያሳዩ…',
                    key: const ValueKey('placeholder'),
                    style: const TextStyle(color: Colors.black38, fontSize: 16)),
          ),

          // English text
          if (enText.isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(enText,
                key: ValueKey(enText),
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            ),
          ],

          const SizedBox(height: 16),

          // Speak + Auto-speak row
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: hasContent ? onSpeak : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasContent ? kPrimaryDark : const Color(0xFFBDBDBD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Speak Translation',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EDED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.graphic_eq_rounded, size: 18, color: kPrimaryDark),
                const SizedBox(width: 6),
                const Text('Auto-\nspeak', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Switch(
                  value: autoSpeak,
                  onChanged: onAutoSpeakToggle,
                  activeThumbColor: kPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
            ),
          ]),

          const SizedBox(height: 10),

          // Volume slider
          Row(children: [
            const Icon(Icons.volume_mute_rounded, size: 16, color: Colors.black38),
            Expanded(child: Slider(
              value: speakerVolume,
              onChanged: onVolumeChanged,
              activeColor: kPrimary,
              inactiveColor: const Color(0xFFE0E0E0),
            )),
            const Icon(Icons.volume_up_rounded, size: 16, color: Colors.black38),
          ]),

          const Divider(height: 16, color: Color(0xFFEEEEEE)),

          // Actions
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _ActionBtn(icon: Icons.copy_outlined, label: 'Copy', onTap: hasContent ? onCopy : () {}),
            _ActionBtn(icon: Icons.clear_all_rounded, label: 'Clear', onTap: onClear),
            _ActionBtn(icon: Icons.share_outlined, label: 'Share', onTap: () {}),
          ]),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF555555)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
        ]),
      ),
    );
  }
}

// ─── Haptic Banner ────────────────────────────────────────────────────────────

class _HapticBanner extends StatelessWidget {
  const _HapticBanner({required this.templateCount});
  final int templateCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.vibration_rounded, size: 18, color: Color(0xFFE65100)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HAPTIC & VISUAL FEEDBACK ACTIVE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7B4B00), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            templateCount > 0
                ? 'Vibration triggers when signs are confirmed. $templateCount sign${templateCount == 1 ? '' : 's'} recognized.'
                : 'Train signs in AI Practice to enable recognition.',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
            overflow: TextOverflow.ellipsis,
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Speech → Text  (REAL PIPELINE)
// ─────────────────────────────────────────────────────────────────────────────

class _SpeechToTextTab extends StatefulWidget {
  const _SpeechToTextTab({required this.language});
  final String language;

  @override
  State<_SpeechToTextTab> createState() => _SpeechToTextTabState();
}

class _SpeechToTextTabState extends State<_SpeechToTextTab>
    with SingleTickerProviderStateMixin {

  // ── STT ──────────────────────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _keepListening = false;      // true while user wants session active
  bool _amharicSttAvailable = false; // whether device has am-ET STT locale

  // Text state ─────────────────────────────────────────────────────────────
  // _cumulativeText   : all *confirmed* (finalResult) sentences from past segments
  // _currentSegment   : live partial text from the current STT session
  // _recognizedText   : what is displayed  =  cumulative + current partial
  String _cumulativeText = '';
  String _currentSegment = '';
  String _recognizedText = '';
  String _statusText = '';

  // ── TTS ──────────────────────────────────────────────────────────────────
  final TranslatorTtsService _tts = TranslatorTtsService.instance;

  // ── Mic animation ─────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Locale ───────────────────────────────────────────────────────────────
  bool _listenAmharic = true;

  // Quick sign presets
  static const List<_QuickPreset> _presets = [
    _QuickPreset(emoji: '👍', labelAm: 'እሺ', labelEn: 'OK / Yes', color: Color(0xFFE8F5E9)),
    _QuickPreset(emoji: '🤲', labelAm: 'አመሰግናለሁ', labelEn: 'Thank you', color: Color(0xFFFFF8E1)),
    _QuickPreset(emoji: '❓', labelAm: 'አልገባኝም', labelEn: "I don't understand", color: Color(0xFFFFEBEE)),
    _QuickPreset(emoji: '🔄', labelAm: 'ይድገሙልኝ', labelEn: 'Please repeat', color: Color(0xFFE8F5E9)),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initStt();
  }

  Future<void> _initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: _onSttError,
        debugLogging: false,
      );
      if (_sttAvailable) {
        // Check whether device actually has an Amharic STT locale
        final locales = await _stt.locales();
        _amharicSttAvailable = locales.any((l) =>
            l.localeId.toLowerCase().startsWith('am'));
        debugPrint('STT locales: ${locales.map((l) => l.localeId).join(', ')}');
        debugPrint('Amharic STT available: $_amharicSttAvailable');
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('STT init error: $e');
    }
  }

  void _onSttStatus(String status) {
    if (!mounted) return;
    // 'listening' = actively capturing, 'notListening'/'done' = paused
    final nowListening = status == 'listening';
    setState(() {
      _isListening = nowListening;
      _statusText = status;
    });

    // Auto-restart: when STT pauses (done/notListening) but user hasn't tapped stop,
    // re-invoke listen so the session stays open.
    if ((status == 'done' || status == 'notListening') &&
        _sttAvailable && _keepListening) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || !_keepListening) return;
        _startListening();
      });
    }
  }

  void _onSttError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _statusText = 'Error: ${error.errorMsg}';
    });
    // On non-permanent errors, try restarting
    if (error.permanent == false && _keepListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || !_keepListening) return;
        _startListening();
      });
    }
  }

  Future<void> _toggleListening() async {
    if (!_sttAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device.')),
        );
      }
      return;
    }

    if (_keepListening) {
      // User taps stop
      _keepListening = false;
      await _stt.stop();
      setState(() => _isListening = false);
      // Speak back the full accumulated sentence
      final fullText = _recognizedText.trim();
      if (fullText.isNotEmpty) {
        // The text is already in the detected language (Amharic or English)
        // speak it in the matching locale
        if (_listenAmharic) {
          await _tts.speakAmharic(fullText);
        } else {
          await _tts.speakEnglish(fullText);
        }
      }
    } else {
      // User taps start — reset accumulators
      _keepListening = true;
      setState(() {
        _cumulativeText = '';
        _currentSegment = '';
        _recognizedText = '';
        _statusText = 'Starting…';
      });
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || !mounted) return;

    // Determine locale:
    // If user wants Amharic but device has no am-ET STT engine, fall back to en-US
    // and show a warning once.
    String localeId;
    if (_listenAmharic) {
      if (_amharicSttAvailable) {
        // Try both common formats — am-ET (iOS/Windows) and am_ET (Android)
        localeId = 'am-ET';
      } else {
        localeId = 'en-US';
        if (mounted && _cumulativeText.isEmpty && _currentSegment.isEmpty) {
          // Show one-time notice
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Amharic STT not installed on this device. '  
                'Recording in English. Install Amharic voice input from Settings.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      localeId = 'en-US';
    }

    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        // onDevice: false (cloud STT) — supports Amharic on more devices
      ),
    );
    if (mounted) setState(() => _isListening = true);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    final words = result.recognizedWords;

    if (result.finalResult) {
      // ── Confirmed sentence: append to cumulative text ─────────────────────
      if (words.trim().isNotEmpty) {
        setState(() {
          // Append with a space separator between sentences
          _cumulativeText = _cumulativeText.isEmpty
              ? words.trim()
              : '$_cumulativeText ${words.trim()}';
          _currentSegment = '';           // clear live segment
          _recognizedText = _cumulativeText;
        });
        // Auto-speak final sentence in the correct language
        if (_listenAmharic) {
          _tts.speakAmharic(words.trim());
        } else {
          _tts.speakEnglish(words.trim());
        }
      }
    } else {
      // ── Partial result: show cumulative + live segment ────────────────────
      setState(() {
        _currentSegment = words;
        _recognizedText = _cumulativeText.isEmpty
            ? words
            : '$_cumulativeText $words';
      });
    }
  }


  Future<void> _announcePreset(_QuickPreset preset) async {
    HapticFeedback.lightImpact();
    await _tts.speakBoth(preset.labelEn, preset.labelAm);
  }

  @override
  void dispose() {
    _keepListening = false;
    _pulseCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      children: [
        // ── Mic card ──────────────────────────────────────────────────────
        _MicCard(
          isListening: _isListening,
          keepListening: _keepListening,
          sttAvailable: _sttAvailable,
          amharicSttAvailable: _amharicSttAvailable,
          pulseAnim: _pulseAnim,
          recognizedText: _recognizedText,
          statusText: _statusText,
          listenAmharic: _listenAmharic,
          onToggleLocale: () => setState(() {
            _listenAmharic = !_listenAmharic;
            // Restart with new locale if already listening
            if (_keepListening) {
              _stt.stop().then((_) => _startListening());
            }
          }),
          onToggleListen: _toggleListening,
        ),
        const SizedBox(height: 10),

        // ── Live reader card ───────────────────────────────────────────────
        _LiveReaderCard(
          cumulativeText: _cumulativeText,
          currentSegment: _currentSegment,
          recognizedText: _recognizedText,
          isListening: _isListening,
          keepListening: _keepListening,
          listenAmharic: _listenAmharic,
          language: widget.language,
          onSpeak: () {
            final text = _recognizedText.trim();
            if (text.isNotEmpty) {
              if (_listenAmharic) {
                _tts.speakAmharic(text);
              } else {
                _tts.speakEnglish(text);
              }
            }
          },
          onCopy: () {
            if (_recognizedText.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: _recognizedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
              );
            }
          },
        ),
        const SizedBox(height: 10),

        // ── Quick presets ──────────────────────────────────────────────────
        _QuickPresetsCard(presets: _presets, onPresetTap: _announcePreset),
        const SizedBox(height: 12),

        // ── Compose bar ────────────────────────────────────────────────────
        _ComposeBar(
          onSend: (text) async {
            if (text.trim().isNotEmpty) {
              await _tts.speakBoth(text.trim(), text.trim());
            }
          },
        ),
      ],
    );
  }
}

// ─── Mic Card ────────────────────────────────────────────────────────────────

class _MicCard extends StatelessWidget {
  const _MicCard({
    required this.isListening,
    required this.keepListening,
    required this.sttAvailable,
    required this.amharicSttAvailable,
    required this.pulseAnim,
    required this.recognizedText,
    required this.statusText,
    required this.listenAmharic,
    required this.onToggleLocale,
    required this.onToggleListen,
  });

  final bool isListening;
  final bool keepListening;
  final bool sttAvailable;
  final bool amharicSttAvailable;
  final Animation<double> pulseAnim;
  final String recognizedText;
  final String statusText;
  final bool listenAmharic;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleListen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Status row
          Row(children: [
            GestureDetector(
              onTap: onToggleLocale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: keepListening ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  // Dot blinks when keep-alive but momentarily restarting
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: keepListening
                          ? (isListening ? const Color(0xFF4CAF50) : const Color(0xFFFFA000))
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    keepListening
                        ? (isListening ? 'LISTENING ACTIVE' : 'RESTARTING…')
                        : (sttAvailable ? 'TAP MIC TO START' : 'STT UNAVAILABLE'),
                    style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: keepListening ? kPrimary : Colors.grey,
                    ),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            // Locale toggle chip — shows warning if Amharic STT not installed
            GestureDetector(
              onTap: onToggleLocale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (listenAmharic && !amharicSttAvailable)
                      ? const Color(0xFFFFF8E1)  // amber tint = warning
                      : const Color(0xFFE8F5E9), // green tint = OK
                  borderRadius: BorderRadius.circular(20),
                  border: (listenAmharic && !amharicSttAvailable)
                      ? Border.all(color: const Color(0xFFFFB300), width: 1)
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    (listenAmharic && !amharicSttAvailable)
                        ? Icons.warning_amber_rounded
                        : Icons.translate,
                    size: 13,
                    color: (listenAmharic && !amharicSttAvailable)
                        ? const Color(0xFFE65100)
                        : kPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    listenAmharic
                        ? (amharicSttAvailable
                            ? 'Amharic (am-ET) ✓'
                            : 'Amharic ⚠ (no engine)')
                        : 'English (en-US)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: (listenAmharic && !amharicSttAvailable)
                          ? const Color(0xFFE65100)
                          : kPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.swap_horiz,
                    size: 13,
                    color: (listenAmharic && !amharicSttAvailable)
                        ? const Color(0xFFE65100)
                        : kPrimary,
                  ),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Pulsing mic button
          GestureDetector(
            onTap: onToggleListen,
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  if (keepListening) ...[
                    Transform.scale(
                      scale: pulseAnim.value * 1.3,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: kPrimary.withValues(alpha: 0.08)),
                      ),
                    ),
                    Transform.scale(
                      scale: pulseAnim.value * 1.15,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: kPrimary.withValues(alpha: 0.12)),
                      ),
                    ),
                  ],
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: keepListening ? kPrimaryDark : const Color(0xFF888888),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: (keepListening ? kPrimary : Colors.grey).withValues(alpha: 0.35),
                        blurRadius: 16, offset: const Offset(0, 4),
                      )],
                    ),
                    child: Icon(
                      keepListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: Colors.white, size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Audio waveform (animated when session is active)
          if (keepListening) const _AudioWave(),
          const SizedBox(height: 10),

          // Status / hint text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(keepListening),
              keepListening
                  ? (recognizedText.isNotEmpty
                      ? '"${recognizedText.length > 50 ? '${recognizedText.substring(0, 50)}…' : recognizedText}"'
                      : (isListening ? 'Listening…' : 'Processing…'))
                  : (sttAvailable ? 'Tap the mic to start listening' : 'Speech recognition not available'),
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Audio Wave ───────────────────────────────────────────────────────────────

class _AudioWave extends StatefulWidget {
  const _AudioWave();

  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  List<double> _bars = List.generate(18, (_) => 0.3);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120))
      ..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) {
          setState(() { _bars = List.generate(18, (_) => 0.2 + _rng.nextDouble() * 0.8); });
          _ctrl.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _ctrl.forward();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _bars.asMap().entries.map((e) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 3,
            height: 32 * e.value,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.6 + e.value * 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Live Reader Card ─────────────────────────────────────────────────────────

class _LiveReaderCard extends StatelessWidget {
  const _LiveReaderCard({
    required this.cumulativeText,
    required this.currentSegment,
    required this.recognizedText,
    required this.isListening,
    required this.keepListening,
    required this.listenAmharic,
    required this.language,
    required this.onSpeak,
    required this.onCopy,
  });

  final String cumulativeText;    // confirmed sentences (finalResult)
  final String currentSegment;    // live partial from current session
  final String recognizedText;    // cumulative + current (displayed)
  final bool isListening;
  final bool keepListening;
  final bool listenAmharic;
  final String language;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final hasConfirmed = cumulativeText.isNotEmpty;
    final hasPartial   = currentSegment.isNotEmpty;
    final hasAny       = hasConfirmed || hasPartial;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              const Icon(Icons.hearing_rounded, size: 15, color: kPrimaryDark),
              const SizedBox(width: 6),
              const Text('LIVE HIGH-CONTRAST READER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: kPrimaryDark, letterSpacing: 0.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  listenAmharic ? ' አማርኛ' : 'EN',
                  style: const TextStyle(fontSize: 10, color: kPrimary, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),

          // ── Speaker label ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.person_rounded, size: 13, color: kPrimary),
                  SizedBox(width: 4),
                  Text('Speaking Person',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: hasAny ? onSpeak : null,
                child: Icon(Icons.volume_up_rounded, size: 18,
                    color: hasAny ? const Color(0xFF444444) : Colors.black26),
              ),
            ]),
          ),

          // ── Text display ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: hasAny
                ? RichText(
                    text: TextSpan(children: [
                      // Confirmed sentences — bold, black
                      if (hasConfirmed)
                        TextSpan(
                          text: cumulativeText,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, height: 1.4,
                            letterSpacing: -0.3, color: Color(0xFF111111),
                          ),
                        ),
                      // Space between confirmed and partial
                      if (hasConfirmed && hasPartial)
                        const TextSpan(text: ' '),
                      // Live partial — italic, grey (still being recognized)
                      if (hasPartial)
                        TextSpan(
                          text: currentSegment,
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500, height: 1.4,
                            letterSpacing: -0.3, color: Color(0xFF888888),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      // Blinking cursor-like indicator while active
                      if (keepListening)
                        const TextSpan(
                          text: ' ▍',
                          style: TextStyle(
                            fontSize: 18, color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ]),
                  )
                : Text(
                    keepListening
                        ? (listenAmharic ? 'ማዳመጥ ላይ ነኝ…' : 'Listening…')
                        : (language == 'en' ? 'Tap the mic to start…' : 'ሚሲኮን ይጫኑ…'),
                    style: const TextStyle(
                        color: Colors.black38, fontSize: 15, fontStyle: FontStyle.italic),
                  ),
          ),

          // ── Status line ───────────────────────────────────────────────────
          if (keepListening && hasConfirmed)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text(
                '${cumulativeText.split(' ').where((w) => w.isNotEmpty).length} words recorded',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888),
                    fontWeight: FontWeight.w500),
              ),
            ),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: hasAny ? onSpeak : null,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasAny ? const Color(0xFFFFC107) : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.volume_up_rounded, size: 16,
                          color: hasAny ? const Color(0xFF5B3800) : Colors.grey),
                      const SizedBox(width: 6),
                      Text('Speak Aloud',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                            color: hasAny ? const Color(0xFF5B3800) : Colors.grey)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: hasAny ? onCopy : null,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.copy_outlined, size: 15, color: Color(0xFF555555)),
                    SizedBox(width: 5),
                    Text('Copy', style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 12, color: Color(0xFF555555))),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Presets Card ───────────────────────────────────────────────────────

class _QuickPreset {
  const _QuickPreset({
    required this.emoji, required this.labelAm,
    required this.labelEn, required this.color,
  });
  final String emoji;
  final String labelAm;
  final String labelEn;
  final Color color;
}

class _QuickPresetsCard extends StatelessWidget {
  const _QuickPresetsCard({required this.presets, required this.onPresetTap});
  final List<_QuickPreset> presets;
  final Future<void> Function(_QuickPreset) onPresetTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.touch_app_rounded, size: 15, color: kPrimaryDark),
            const SizedBox(width: 6),
            const Text('QUICK SIGN PRESETS (REPLY BACK)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimaryDark, letterSpacing: 0.4)),
            const Spacer(),
            const Text('Tap to\nannounce',
              style: TextStyle(fontSize: 9.5, color: Colors.black38), textAlign: TextAlign.right),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: presets.map((p) => _PresetTile(preset: p, onTap: () => onPresetTap(p))).toList(),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onTap});
  final _QuickPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: preset.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: preset.color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Text(preset.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preset.labelAm,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
              Text(preset.labelEn,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
                overflow: TextOverflow.ellipsis),
            ],
          )),
          const Icon(Icons.volume_up_rounded, size: 14, color: Colors.black38),
        ]),
      ),
    );
  }
}

// ─── Compose Bar ─────────────────────────────────────────────────────────────

class _ComposeBar extends StatefulWidget {
  const _ComposeBar({required this.onSend});
  final Future<void> Function(String) onSend;

  @override
  State<_ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<_ComposeBar> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.keyboard_alt_outlined, color: Colors.black38, size: 20),
        ),
        Expanded(child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            hintText: 'Type to speak aloud…',
            hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          ),
          style: const TextStyle(fontSize: 13),
          textInputAction: TextInputAction.send,
          onSubmitted: (text) async {
            await widget.onSend(text);
            _ctrl.clear();
          },
        )),
        GestureDetector(
          onTap: () async {
            await widget.onSend(_ctrl.text);
            _ctrl.clear();
          },
          child: Container(
            width: 42, height: 42, margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: kPrimaryDark, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.8)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    void drawDashedLine(Offset p1, Offset p2) {
      const dashLen = 8.0, gapLen = 5.0;
      final total = (p2 - p1).distance;
      final dir = (p2 - p1) / total;
      var traveled = 0.0;
      while (traveled < total) {
        final start = p1 + dir * traveled;
        final end = p1 + dir * math.min(traveled + dashLen, total);
        canvas.drawLine(start, end, paint);
        traveled += dashLen + gapLen;
      }
    }

    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    drawDashedLine(r.topLeft, r.topRight);
    drawDashedLine(r.topRight, r.bottomRight);
    drawDashedLine(r.bottomRight, r.bottomLeft);
    drawDashedLine(r.bottomLeft, r.topLeft);

    final accentPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const c = 12.0;
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final dx = corner == r.topLeft || corner == r.bottomLeft ? c : -c;
      final dy = corner == r.topLeft || corner == r.topRight ? c : -c;
      canvas.drawLine(corner, corner + Offset(dx, 0), accentPaint);
      canvas.drawLine(corner, corner + Offset(0, dy), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _HandSkeletonPainter extends CustomPainter {
  _HandSkeletonPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2 + 20;

    final palmPoints = [
      Offset(cx - 30, cy + 10), Offset(cx - 15, cy + 20),
      Offset(cx, cy + 22), Offset(cx + 15, cy + 20), Offset(cx + 30, cy + 10),
    ];

    final fingerTips = palmPoints.asMap().entries.map((e) {
      final wave = math.sin(phase + e.key * 0.8) * 5;
      return Offset(e.value.dx, cy - 55 - wave);
    }).toList();

    for (int i = 0; i < palmPoints.length; i++) {
      canvas.drawLine(palmPoints[i], fingerTips[i], bonePaint);
    }

    final path = Path()..moveTo(palmPoints.first.dx, palmPoints.first.dy);
    for (final p in palmPoints.skip(1)) { path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, bonePaint);

    for (final p in [...palmPoints, ...fingerTips]) {
      canvas.drawCircle(p, 4, jointPaint);
    }
    canvas.drawCircle(Offset(cx, cy + 30), 7, jointPaint);
  }

  @override
  bool shouldRepaint(_HandSkeletonPainter old) => old.phase != phase;
}
