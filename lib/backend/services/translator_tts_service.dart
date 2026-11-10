import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Bilingual TTS service for the Live Translator.
/// Speaks in English (en-US) and Amharic (am-ET) with high-quality settings.
/// Falls back to English if Amharic locale is unavailable on the device.
class TranslatorTtsService {
  TranslatorTtsService._();
  static final TranslatorTtsService instance = TranslatorTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;

    // ── Quality settings ────────────────────────────────────────────────────
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.42);   // Slower = clearer for Amharic
    await _tts.setPitch(1.05);        // Slightly warmer voice
    await _tts.awaitSpeakCompletion(true); // Block until speech ends

    _tts.setStartHandler(() { _isSpeaking = true; });
    _tts.setCompletionHandler(() { _isSpeaking = false; });
    _tts.setCancelHandler(() { _isSpeaking = false; });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });
  }

  /// Speaks a single English phrase (en-US).
  Future<void> speakEnglish(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.44);
    await _tts.setPitch(1.05);
    await _tts.speak(text.trim());
  }

  /// Speaks a single Amharic phrase (am-ET), falls back to en-US.
  Future<void> speakAmharic(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    final ok = await _setAmharicLocale();
    if (!ok) await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.38); // Amharic needs a bit slower
    await _tts.setPitch(1.08);
    await _tts.speak(text.trim());
  }

  /// Speaks English first, waits for completion, then speaks Amharic.
  /// This gives the clearest bilingual experience.
  Future<void> speakBoth(String english, String amharic) async {
    final en = english.trim();
    final am = amharic.trim();
    if (en.isEmpty && am.isEmpty) return;

    await _ensureInit();
    await _tts.stop();

    if (en.isNotEmpty) {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.44);
      await _tts.setPitch(1.05);
      await _tts.speak(en);
      // awaitSpeakCompletion(true) means speak() blocks until done
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (am.isNotEmpty) {
      final ok = await _setAmharicLocale();
      if (!ok) {
        // Amharic locale not installed — speak transliterated English instead
        await _tts.setLanguage('en-US');
        debugPrint('TTS: am-ET unavailable, skipping Amharic speech.');
        return;
      }
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(1.08);
      await _tts.speak(am);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> setVolume(double volume) async {
    await _ensureInit();
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setRate(double rate) async {
    await _ensureInit();
    await _tts.setSpeechRate(rate.clamp(0.1, 1.0));
  }

  /// Returns true if am-ET was set successfully on the device.
  Future<bool> _setAmharicLocale() async {
    try {
      final result = await _tts.setLanguage('am-ET');
      // flutter_tts returns 1 on success on Android, 0 on failure.
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    await _ensureInit();
    return await _tts.getLanguages ?? [];
  }

  Future<void> dispose() async {
    await _tts.stop();
    _initialized = false;
  }
}
