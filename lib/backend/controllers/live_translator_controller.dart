import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:esl_learning_flutter/backend/ai/pose_matcher.dart';
import 'package:esl_learning_flutter/backend/database/sqlite_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Match result returned on every recognized sign
// ─────────────────────────────────────────────────────────────────────────────

class SignMatchResult {
  const SignMatchResult({
    required this.signId,
    required this.labelEn,
    required this.labelAm,
    required this.confidence,
    required this.isConfirmed,
  });

  final String signId;
  final String labelEn;
  final String labelAm;
  final double confidence; // 0.0–1.0
  final bool isConfirmed;  // true once stable for debounce period
}

// ─────────────────────────────────────────────────────────────────────────────
// LiveTranslatorController
// Loads ALL trained sign templates; on each landmark frame evaluates every
// template and returns the best match above threshold.
// ─────────────────────────────────────────────────────────────────────────────

class LiveTranslatorController {
  LiveTranslatorController();

  // ── Config ──────────────────────────────────────────────────────────────────
  static const int _bufferSize = 5;
  static const double _confirmThreshold = 0.75;
  static const Duration _stableDebounce = Duration(milliseconds: 1500);
  static const Duration _cooldown = Duration(milliseconds: 2000);

  // ── State ───────────────────────────────────────────────────────────────────
  Map<String, List<double>> _templates = {};
  final List<List<double>> _slidingBuffer = [];

  // Last confirmed sign — avoids repeating the same sign multiple times
  String? _lastConfirmedSignId;
  DateTime? _signStableFrom;
  DateTime? _lastAnnouncedAt;

  bool _loaded = false;
  int get templateCount => _templates.length;
  bool get isLoaded => _loaded;

  // ── Bilingual label maps ────────────────────────────────────────────────────
  static const Map<String, String> _amharicLabels = {
    // Numbers
    'zero':  'ዜሮ',
    'one':   'አንድ',
    'two':   'ሁለት',
    'three': 'ሦስት',
    'four':  'አራት',
    'five':  'አምስት',
    'six':   'ስድስት',
    'seven': 'ሰባት',
    'eight': 'ስምንት',
    'nine':  'ዘጠኝ',
    'ten':   'አስር',
    // Greetings
    'hello':      'ሰላም',
    'goodbye':    'ደህና ሁን',
    'thankyou':   'አመሰግናለሁ',
    'thank you':  'አመሰግናለሁ',
    'sorry':      'ይቅርታ',
    'yes':        'አዎ',
    'no':         'አይ',
    'please':     'እባክዎ',
    'help':       'እርዳኝ',
    'name':       'ስም',
    'eat':        'ብላ',
    'water':      'ውሃ',
    'bathroom':   'መፀዳጃ',
    'doctor':     'ዶክተር',
    'pain':       'ህመም',
    'emergency':  'አደጋ',
    'family':     'ቤተሰብ',
    'mother':     'እናት',
    'father':     'አባት',
    'friend':     'ወዳጅ',
    'school':     'ትምህርት ቤት',
    'work':       'ስራ',
    'home':       'ቤት',
    'love':       'ፍቅር',
    'good':       'ጥሩ',
    'bad':        'መጥፎ',
    'morning':    'ጠዋት',
    'evening':    'ምሽት',
    'today':      'ዛሬ',
    'tomorrow':   'ነገ',
    'repeat':     'ደግም',
    'understand': 'ገባኝ',
    'wait':       'ጠብቅ',
    'come':       'ና',
    'go':         'ሂድ',
  };

  static const Map<String, String> _englishLabels = {
    'zero':  'Zero',
    'one':   'One',
    'two':   'Two',
    'three': 'Three',
    'four':  'Four',
    'five':  'Five',
    'six':   'Six',
    'seven': 'Seven',
    'eight': 'Eight',
    'nine':  'Nine',
    'ten':   'Ten',
  };

  /// Load all trained templates from SQLite into memory.
  Future<void> loadAllTemplates(SQLiteHelper db) async {
    try {
      _templates = await db.getAllTrainedTemplates();
      _loaded = true;
      debugPrint('LiveTranslatorController: loaded ${_templates.length} templates — '
          '${_templates.keys.join(', ')}');
    } catch (e) {
      debugPrint('LiveTranslatorController: failed to load templates: $e');
      _templates = {};
      _loaded = true; // mark done even on error so UI doesn't hang
    }
  }

  /// Process a landmark frame and return the best matching sign (or null).
  /// Call this on every MediaPipe landmark update.
  SignMatchResult? processLandmarks(List<double> flatCoords) {
    if (_templates.isEmpty) return null;
    if (flatCoords.length != 63) return null;

    // Normalize incoming frame
    final normalized = PoseMatcher.normalizeHand(flatCoords);

    // Add to sliding buffer
    _slidingBuffer.add(normalized);
    if (_slidingBuffer.length > _bufferSize) {
      _slidingBuffer.removeAt(0);
    }

    // Need full buffer before evaluating
    if (_slidingBuffer.length < _bufferSize) return null;

    // Average the buffer frames
    final avgPose = _averagePose(_slidingBuffer);
    return _evaluatePose(avgPose, useDebounce: true);
  }

  /// Evaluate a SINGLE frame immediately — used for Single Sign mode.
  /// No sliding buffer averaging; returns a result as soon as a frame
  /// exceeds the confidence threshold (isConfirmed is always false here;
  /// the caller decides whether to act on the result).
  SignMatchResult? processLandmarksSingleShot(List<double> flatCoords) {
    if (_templates.isEmpty) return null;
    if (flatCoords.length != 63) return null;
    final normalized = PoseMatcher.normalizeHand(flatCoords);
    return _evaluatePose(normalized, useDebounce: false);
  }

  SignMatchResult? _evaluatePose(List<double> pose, {required bool useDebounce}) {
    // Evaluate against EVERY template — find best match
    String? bestId;
    double bestSimilarity = 0.0;

    for (final entry in _templates.entries) {
      final eval = PoseMatcher.evaluatePose(pose, entry.value);
      final sim = (eval['similarity'] as num).toDouble();
      if (sim > bestSimilarity) {
        bestSimilarity = sim;
        bestId = entry.key;
      }
    }

    if (bestId == null || bestSimilarity < _confirmThreshold) {
      _signStableFrom = null;
      return null;
    }

    if (!useDebounce) {
      // Single-shot: return raw result — caller decides whether to act.
      return SignMatchResult(
        signId: bestId,
        labelEn: _labelEn(bestId),
        labelAm: _labelAm(bestId),
        confidence: bestSimilarity,
        isConfirmed: false,
      );
    }

    // ── Stability debounce ────────────────────────────────────────────────────
    final now = DateTime.now();
    if (_signStableFrom == null || _lastConfirmedSignId != bestId) {
      _signStableFrom = now;
      _lastConfirmedSignId = bestId;
    }
    final stableDuration = now.difference(_signStableFrom!);
    final isConfirmed = stableDuration >= _stableDebounce;

    // ── Cooldown ─────────────────────────────────────────────────────────────
    bool shouldAnnounce = isConfirmed;
    if (isConfirmed && _lastAnnouncedAt != null) {
      if (now.difference(_lastAnnouncedAt!) < _cooldown) shouldAnnounce = false;
    }
    if (shouldAnnounce) _lastAnnouncedAt = now;

    return SignMatchResult(
      signId: bestId,
      labelEn: _labelEn(bestId),
      labelAm: _labelAm(bestId),
      confidence: bestSimilarity,
      isConfirmed: shouldAnnounce,
    );
  }

  String _labelEn(String id) =>
      _englishLabels[id] ??
      id.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

  String _labelAm(String id) => _amharicLabels[id] ?? id;

  /// 5-frame arithmetic mean — matches AIPracticeController logic.
  static List<double> _averagePose(List<List<double>> frames) {
    final avg = List<double>.filled(63, 0.0);
    for (var i = 0; i < 63; i++) {
      var sum = 0.0;
      for (final frame in frames) {
        sum += frame[i];
      }
      avg[i] = sum / frames.length;
    }
    return avg;
  }

  void clearBuffer() {
    _slidingBuffer.clear();
    _signStableFrom = null;
    _lastAnnouncedAt = null;
    _lastConfirmedSignId = null;
  }

  void dispose() {
    clearBuffer();
    _templates.clear();
    _loaded = false;
  }
}
