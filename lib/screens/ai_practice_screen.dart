import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';
import 'package:esl_learning_flutter/backend/controllers/ai_practice_controller.dart';
import 'package:esl_learning_flutter/backend/ai/mediapipe_processor.dart';
import 'package:esl_learning_flutter/backend/providers.dart';

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
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  // App Templates & State
  bool _hasTemplate = false;
  bool _isRecordingTemplate = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  final List<List<double>> _recordedTemplateFrames = [];

  // Real-time evaluation outcomes
  double _confidence = 0.0;
  bool _isCorrect = false;
  List<String> _feedback = ["Initializing hand tracker..."];

  // Activity flow states
  // Activity flow states
  bool _hasSavedFeedback = false; // Prevents logging database rows repeatedly per frame
  int _emptyFrameCount = 0; // Number of consecutive frames without hand detection

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
              "Sign is not trained yet.",
              "Tap 'Teach Sign' below, hold the gesture, and wait for the 3s recording count."
            ];
          }
        });
      }

      // Preload template in controller to cache it for real-time streaming
      if (template != null) {
        await ref.read(aiPracticeControllerProvider).preloadTemplate(widget.lesson.sign);
      }
      
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

      _cameraController = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      // 3. Hook into Camera Frame Stream
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessing) return;
        _isProcessing = true;

        try {
          // Process current frame coordinates
          final flatCoords = MediaPipeProcessor.processCameraImage(image, frontCam);
          
          if (flatCoords != null) {
            _emptyFrameCount = 0; // Hand detected! Reset grace counter
            
            if (_isRecordingTemplate) {
              // Teach/Creator Mode: capture sequence
              _recordedTemplateFrames.add(flatCoords);
              if (mounted) {
                setState(() {
                  _feedback = [
                    "Recording gesture template...",
                    "Frames: ${_recordedTemplateFrames.length} / 30"
                  ];
                });
              }
              
              if (_recordedTemplateFrames.length >= 30) {
                await _saveTemplate();
              }
            } else if (_hasTemplate) {
              // Practice Mode: run on-device evaluation
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

                // Write result to local SQLite feedback table once when matching
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
                  _hasSavedFeedback = false; // Reset log trigger when hand lets go
                }
              }
            }
          } else {
            // Hand not detected in this frame
            _emptyFrameCount++;
            
            // Only clear active match and buffer if hand is missing for 15+ consecutive frames
            if (_emptyFrameCount >= 15) {
              if (mounted && !_isRecordingTemplate) {
                setState(() {
                  _confidence = 0.0;
                  _isCorrect = false;
                  _feedback = ["Analysing... Keep your hand within the frame."];
                });
                ref.read(aiPracticeControllerProvider).clearBuffer();
              }
            }
          }
        } catch (e) {
          // Frame stream parsing catch block
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

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('Camera access is required to practice sign language gestures.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopAndRelease(); // Release resources and return home
            },
            child: const Text('OK'),
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
        title: const Text('AI Practice Unavailable'),
        content: const Text('Failed to load the hand landmarker tracking model or activate the camera.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopAndRelease(); // Release resources and return home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startTeachCountdown() {
    _cameraController?.pausePreview(); // Temporarily pause to let user prepare
    setState(() {
      _countdown = 3;
      _recordedTemplateFrames.clear();
      _isRecordingTemplate = false;
    });
    SystemSound.play(SystemSoundType.click);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_countdown > 1) {
          _countdown--;
          SystemSound.play(SystemSoundType.click);
        } else {
          timer.cancel();
          _countdown = 0;
          _isRecordingTemplate = true;
          _cameraController?.resumePreview();
          SystemSound.play(SystemSoundType.click); // Final chime sound
        }
      });
    });
  }

  Future<void> _saveTemplate() async {
    _isRecordingTemplate = false;
    
    final controller = ref.read(aiPracticeControllerProvider);
    final success = await controller.recordTemplateFromSequence(
      _recordedTemplateFrames, 
      widget.lesson.sign
    );
    
    if (mounted) {
      setState(() {
        _hasTemplate = success;
        _recordedTemplateFrames.clear();
        if (success) {
          _feedback = ["Sign template saved successfully!", "You can now begin practicing."];
          _confidence = 0.0;
          _isCorrect = false;
        } else {
          _feedback = ["Failed to save template. Please try recording again."];
        }
      });
    }
  }

  void _stopAndRelease() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    MediaPipeProcessor.dispose(); // Add this line
    try {
      ref.read(aiPracticeControllerProvider).clearBuffer();
    } catch (_) {}
    widget.onBack(); // Return to Home
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    MediaPipeProcessor.dispose(); // Add this line
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
          title: Text('Practice: ${widget.lesson.sign.toUpperCase()}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _stopAndRelease,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening Camera Feed...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: Text('Practice: ${widget.lesson.sign.toUpperCase()}'),
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
                      !_hasTemplate 
                          ? 'UNTRAINED' 
                          : _isCorrect 
                              ? 'CORRECT!' 
                              : 'ANALYSING...',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
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
                    child: const Text(
                      'Keep your hand within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                // Big Countdown Overlay
                if (_countdown > 0)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                        ),
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
                    onPressed: _countdown > 0 || _isRecordingTemplate ? null : _startTeachCountdown,
                    icon: const Icon(Icons.psychology_alt, color: Colors.white),
                    label: Text(_hasTemplate ? 'Reteach Sign' : 'Teach Sign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopAndRelease, // Release resources and return Home
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('Stop Practice'),
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
              padding: const EdgeInsets.all(20),
              color: Colors.grey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pose Similarity:',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        _hasTemplate ? '${_confidence.toStringAsFixed(0)}%' : 'N/A',
                        style: TextStyle(
                          color: !_hasTemplate
                              ? Colors.grey
                              : _confidence >= 75
                                  ? Colors.green
                                  : Colors.amber,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  
                  // Premium Real-time Evaluation Alert Cards
                  if (_hasTemplate && _isCorrect)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.green, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CORRECT SIGN DETECTED!",
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  "Excellent form! Your hand matches the trained template.",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  if (_hasTemplate && !_isCorrect && _confidence > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.amber, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "GESTURE MISMATCH (Below 75%)",
                                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  "Your hand pose is similar but not close enough. Adjust using the guidelines below.",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    'Practice Guidelines:',
                    style: TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _feedback.length,
                      itemBuilder: (context, index) {
                        final item = _feedback[index];
                        final isSuccess = item.contains("Excellent") || item.contains("saved") || item.contains("Correct") || item.contains("Perfect");
                        final isAlert = item.contains("not trained") || item.contains("Analysing") || item.contains("No hand");
                        
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
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontSize: 14,
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
    );
  }
}
