import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_clip_library.dart';

/// Un pedazo de frase: se reproduce el clip [key] si existe, si no se dice
/// [text] con TTS.
@immutable
class VoiceSegment {
  const VoiceSegment(this.key, this.text);

  /// Segmento que siempre va por TTS (no hay clip para esto).
  const VoiceSegment.tts(this.text) : key = null;

  final String? key;
  final String text;

  @override
  String toString() => key == null ? '"$text"' : '$key("$text")';
}

/// Una frase completa, armada con varios segmentos.
/// Ej.: "Diez lagartijas" = [num_10, ej_lagartijas].
@immutable
class VoicePhrase {
  const VoicePhrase(this.segments);

  final List<VoiceSegment> segments;

  VoicePhrase operator +(VoicePhrase other) =>
      VoicePhrase([...segments, ...other.segments]);

  /// Texto completo, para mostrarlo en pantalla.
  String get text =>
      segments.map((s) => s.text).join(' ').replaceAll(' .', '.');

  bool get isEmpty => segments.isEmpty;
}

/// Reproduce frases encadenando clips grabados y TTS como respaldo.
///
/// Si llega una frase nueva mientras otra suena, la anterior se corta: así,
/// al presionar ">>" varias veces seguidas, solo se escucha la última.
class CoachVoice {
  CoachVoice({required this.library});

  final VoiceClipLibrary library;

  // Se crean al primer uso (así las pruebas pueden reemplazar [say]).
  late final FlutterTts _tts = FlutterTts();
  // handleInterruptions: false para que el TTS (otra app en Android) no
  // pause nuestros clips al pedir el foco de audio.
  late final AudioPlayer _player = AudioPlayer(handleInterruptions: false);

  bool _ready = false;
  bool _ttsAvailable = true;
  bool _disposed = false;
  int _generation = 0;

  /// Frase que se está diciendo (para mostrarla en pantalla).
  final ValueNotifier<String?> speaking = ValueNotifier<String?>(null);

  void _setSpeaking(String? text) {
    if (!_disposed) speaking.value = text;
  }

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      final langs = <String>['es-MX', 'es-US', 'es-ES', 'es'];
      for (final lang in langs) {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(lang);
          break;
        }
      }
      await _tts.setSpeechRate(defaultTargetPlatform == TargetPlatform.iOS ? 0.5 : 0.55);
      await _tts.setPitch(1.0);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Sin mixWithOthers: si no, iOS no manda los botones de la bocina
        // (remote commands) a la app.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }
    } catch (e) {
      debugPrint('[CoachVoice] TTS no disponible: $e');
      _ttsAvailable = false;
    }
  }

  /// Dice [phrase]. Completa cuando termina o cuando otra frase la corta.
  Future<void> say(VoicePhrase phrase) async {
    if (_disposed) return;
    await init();
    final gen = ++_generation;
    await _stopOutput();
    if (phrase.isEmpty) return;
    _setSpeaking(phrase.text);

    // Agrupa: clips sueltos o tramos de texto seguidos para TTS (así el TTS
    // suena natural en vez de palabra por palabra).
    final pending = <String>[];
    Future<void> flushTts() async {
      if (pending.isEmpty) return;
      final text = pending.join(' ');
      pending.clear();
      await _speakTts(text);
    }

    for (final segment in phrase.segments) {
      if (gen != _generation) return;
      final asset = segment.key == null ? null : library.assetFor(segment.key!);
      if (asset == null) {
        pending.add(segment.text);
        continue;
      }
      await flushTts();
      if (gen != _generation) return;
      final played = await _playClip(asset);
      // Clip dañado o ilegible: ese pedazo se dice con TTS.
      if (!played) pending.add(segment.text);
    }
    if (gen != _generation) return;
    await flushTts();
    if (gen == _generation) _setSpeaking(null);
  }

  /// Corta lo que se esté diciendo.
  Future<void> stop() async {
    _generation++;
    _setSpeaking(null);
    await _stopOutput();
  }

  Future<void> _stopOutput() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _speakTts(String text) async {
    if (!_ttsAvailable || text.trim().isEmpty) return;
    try {
      await _tts.speak(text).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[CoachVoice] TTS falló: $e');
    }
  }

  Future<bool> _playClip(String asset) async {
    try {
      await _player.setAsset(asset);
    } catch (e) {
      debugPrint('[CoachVoice] clip $asset no se pudo cargar: $e');
      return false;
    }
    try {
      // play() completa al terminar el clip; luego pausa para que el
      // siguiente play() no regrese de inmediato.
      await _player.play().timeout(const Duration(seconds: 15));
      await _player.pause();
    } catch (e) {
      debugPrint('[CoachVoice] clip $asset falló: $e');
    }
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    speaking.dispose();
    try {
      await _tts.stop();
    } catch (_) {}
    await _player.dispose();
  }
}
