import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/backend/controllers/ai_practice_controller.dart';
import 'package:esl_learning_flutter/backend/ai/mediapipe_processor.dart';
import 'package:esl_learning_flutter/backend/providers.dart';
import 'package:esl_learning_flutter/backend/services/localisation_service.dart';

class AIPracticeScreen extends ConsumerStatefulWidget {
  const AIPracticeScreen({
    super.key, 
    required this.language, 
    required this.lesson, 
    required this.onBack
  });
  final String language;
  final LessonItem lesson;
  final VoidCallback onBack;

  @override
  ConsumerState<AIPracticeScreen> createState() => _AIPracticeScreenState();
}

class _AIPracticeScreenState extends ConsumerState<AIPracticeScreen> {
  CameraController? _cameraController;
  StreamSubscription<List<double>?>? _landmarkSubscription;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  // App Templates & State
  bool _hasTemplate = false;

  // Real-time evaluation outcomes
  double _confidence = 0.0;
  bool _isCorrect = false;
  List<String> _feedback = ["Initializing hand tracker..."];

  // Activity flow states
  bool _hasSavedFeedback = false;
  DateTime? _lastHandDetectedTime;

  // Debug states
  int _processedFramesCount = 0;
  bool _isHandDetected = false;
  int _sensorOrientation = 0;

  @override
  void initState() {
    super.initState();
    _checkTemplateAndInitCamera();
  }

  Future<void> _checkTemplateAndInitCamera() async {
    try {
      // 1. Check if sign template exists in SQLite local DB
      final template = await ref.read(sqliteHelperProvider).getSignTemplate(widget.lesson.sign);
      if (mounted) {
        setState(() {
          _hasTemplate = template != null;
          if (_hasTemplate) {
            _feedback = ["Hold your hand in camera view to practice."];
          } else {
            _feedback = [
              "Practice sign is not trained yet.",
              "Please train this sign externally and save its coordinate template into the database."
            ];
          }
        });
      }

      // Preload template in controller to cache it for real-time streaming
      if (template != null) {
        await ref.read(aiPracticeControllerProvider).preloadTemplate(widget.lesson.sign);
      }

      // Initialize on-device hand tracker before opening the camera stream.
      await MediaPipeProcessor.ensureInitialized();

      _landmarkSubscription = MediaPipeProcessor.landmarkUpdates.listen(
        _onLandmarksUpdated,
        onError: (Object error) {
          debugPrint('Landmark stream error: $error');
        },
      );
      
      // 2. Initialize camera permission & controller
      await _initializeCamera();
    } catch (e) {
      debugPrint("DB template check error: $e");
      if (mounted) {
        _showModelErrorDialog();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showModelErrorDialog();
        return;
      }
      
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _sensorOrientation = frontCam.sensorOrientation;

      // Default format matches the hand_landmarker example and works better on
      // emulators (often NV21 as 1–2 planes) than forcing YUV420.
      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // 3. Hook into Camera Frame Stream
      DateTime lastProcessedTime = DateTime.now();

      _cameraController!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        
        // Throttle to 10 FPS — matches sign_practice frameThrottleInterval.
        if (now.difference(lastProcessedTime).inMilliseconds < 100) {
          return;
        }

        if (_isProcessing) return;
        _isProcessing = true;
        lastProcessedTime = now;

        try {
          MediaPipeProcessor.feedCameraImage(image, frontCam);
          if (mounted) {
            setState(() => _processedFramesCount++);
          }
        } catch (e, st) {
          debugPrint("Error in camera frame stream processor: $e\n$st");
        } finally {
          _isProcessing = false;
        }
      });
    } catch (e) {
      debugPrint("Camera initialize error: $e");
      if (!mounted) return;
      
      // Determine if exception is due to denied permission
      if (e.toString().contains("CameraAccessDenied") || e.toString().contains("permission")) {
        _showPermissionErrorDialog();
      } else {
        _showModelErrorDialog();
      }
    }
  }

  Future<void> _onLandmarksUpdated(List<double>? flatCoords) async {
    if (!mounted) return;

    final handDetected = flatCoords != null;
    setState(() => _isHandDetected = handDetected);

    if (flatCoords != null) {
      _lastHandDetectedTime = DateTime.now();

      if (!_hasTemplate) {
        setState(() {
          _feedback = [
            'Hand detected — tracking is active.',
            'This sign is not trained yet. Try Numbers → Two or Three for full evaluation.',
          ];
        });
        return;
      }

      final controller = ref.read(aiPracticeControllerProvider);
      final result = await controller.processFrame(flatCoords, widget.lesson.sign);

      if (result != null && mounted) {
        final double score = (result['target_confidence'] as num).toDouble() * 100;
        final bool correct = result['is_correct'] as bool;

        setState(() {
          _confidence = score;
          _isCorrect = correct;
          _feedback = List<String>.from(result['feedback']);
        });

        if (correct && !_hasSavedFeedback) {
          _hasSavedFeedback = true;
          final int userId = ref.read(authSessionProvider).userId ?? 1;
          await controller.saveFeedback(
            userId: userId,
            targetSign: widget.lesson.sign,
            predictedSign: widget.lesson.sign,
            confidence: score / 100.0,
            isCorrect: true,
          );
        } else if (!correct) {
          _hasSavedFeedback = false;
        }
      }
      return;
    }

    final handMissingMs = _lastHandDetectedTime == null
        ? 1501
        : DateTime.now().difference(_lastHandDetectedTime!).inMilliseconds;
    if (handMissingMs >= 1500 && mounted) {
      setState(() {
        _confidence = 0.0;
        _isCorrect = false;
        _feedback = [
          'No hand detected.',
          'Hold your hand clearly in front of the camera.',
          if (Platform.isAndroid)
            'Emulator tip: Extended Controls → Camera → set Front to Webcam.',
        ];
      });
      ref.read(aiPracticeControllerProvider).clearBuffer();
    }
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Camera Permission Required'.tr(widget.language)),
        content: Text('Camera access is required to practice sign language gestures.'.tr(widget.language)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopAndRelease(); // Release resources and return home
            },
            child: Text('OK'.tr(widget.language)),
          ),
        ],
      ),
    );
  }

  void _showModelErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('AI Practice Unavailable'.tr(widget.language)),
        content: Text('Failed to load the hand landmarker tracking model or activate the camera.'.tr(widget.language)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopAndRelease(); // Release resources and return home
            },
            child: Text('OK'.tr(widget.language)),
          ),
        ],
      ),
    );
  }

  void _stopAndRelease() {
    _landmarkSubscription?.cancel();
    _landmarkSubscription = null;
    _cameraController?.dispose();
    MediaPipeProcessor.dispose();
    try {
      ref.read(aiPracticeControllerProvider).clearBuffer();
    } catch (_) {}
    widget.onBack(); // Return to Home
  }

  @override
  void dispose() {
    _landmarkSubscription?.cancel();
    _landmarkSubscription = null;
    _cameraController?.dispose();
    MediaPipeProcessor.dispose();
    try {
      ref.read(aiPracticeControllerProvider).clearBuffer();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          title: Text('${'Practice'.tr(widget.language)}: ${widget.language == 'en' ? widget.lesson.sign.toUpperCase() : widget.lesson.signAm}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _stopAndRelease,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Opening Camera Feed...'.tr(widget.language)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: Text('${'Practice'.tr(widget.language)}: ${widget.language == 'en' ? widget.lesson.sign.toUpperCase() : widget.lesson.signAm}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopAndRelease,
        ),
      ),
      body: Column(
        children: [
          // 1. Camera Viewfinder Section
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                
                // Status Badge Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_hasTemplate 
                          ? Colors.grey.withValues(alpha: 0.85)
                          : _isCorrect 
                              ? Colors.green.withValues(alpha: 0.85) 
                              : Colors.amber.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      (!_hasTemplate
                          ? (_isHandDetected ? 'TRACKING' : 'UNTRAINED')
                          : _isCorrect
                              ? 'CORRECT!'
                              : (_isHandDetected ? 'ANALYSING...' : 'NO HAND')).tr(widget.language),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Debug Info Overlay (Helpful for emulators/developers)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Frames: $_processedFramesCount',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          'Hand: ${_isHandDetected ? "DETECTED" : "NO HAND"}',
                          style: TextStyle(
                            color: _isHandDetected ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Angle: $_sensorOrientation°',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Keep Hand In Frame prompt helper
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Keep your hand within the frame'.tr(widget.language),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 2. Control Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.grey[850],
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopAndRelease, // Release resources and return Home
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: Text('Stop Practice'.tr(widget.language)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDanger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 3. Metrics & Suggestions panel
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[900],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Gauge & Badge (Evaluation Result)
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "EVALUATION RESULT".tr(widget.language),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Custom Radial Gauge mimicking index.html
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _confidence / 100.0,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    !_hasTemplate
                                        ? Colors.grey
                                        : _confidence >= 75
                                            ? Colors.green
                                            : Colors.amber,
                                  ),
                                ),
                                Text(
                                  _hasTemplate ? '${_confidence.toStringAsFixed(0)}%' : '0%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Match Confidence".tr(widget.language),
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                          ),
                          const SizedBox(height: 10),
                          // Badge mimicking web evaluation indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_hasTemplate
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : _isCorrect
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.amber.withValues(alpha: 0.15),
                              border: Border.all(
                                color: !_hasTemplate
                                    ? Colors.grey
                                    : _isCorrect
                                        ? Colors.green
                                        : Colors.amber,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  !_hasTemplate
                                      ? Icons.help_outline
                                      : _isCorrect
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                  color: !_hasTemplate
                                      ? Colors.grey
                                      : _isCorrect
                                          ? Colors.green
                                          : Colors.amber,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (!_hasTemplate
                                      ? "INCOMPLETE"
                                      : _isCorrect
                                          ? "CORRECT"
                                          : "INCORRECT").tr(widget.language),
                                  style: TextStyle(
                                    color: !_hasTemplate
                                        ? Colors.grey
                                        : _isCorrect
                                            ? Colors.green
                                            : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Right side: Diagnostic Feedback (Guidelines)
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'DIAGNOSTIC FEEDBACK'.tr(widget.language),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _feedback.length,
                              itemBuilder: (context, index) {
                                final item = _feedback[index];
                                final isSuccess = item.contains("Excellent") || item.contains("saved") || item.contains("Correct") || item.contains("Perfect");
                                final isAlert = item.contains("not trained") || item.contains("Analysing") || item.contains("No hand") || item.contains("Keep");
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        isSuccess 
                                            ? Icons.check_circle 
                                            : isAlert 
                                                ? Icons.info 
                                                : Icons.arrow_right_alt,
                                        color: isSuccess 
                                            ? Colors.green 
                                            : isAlert 
                                                ? Colors.amber 
                                                : Colors.cyanAccent,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.tr(widget.language),
                                          style: const TextStyle(
                                            color: Colors.white, 
                                            fontSize: 12,
                                            height: 1.3
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
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
