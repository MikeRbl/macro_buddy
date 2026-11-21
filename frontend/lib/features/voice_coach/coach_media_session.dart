import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Lo que la sesión multimedia le pide al entrenamiento.
abstract interface class CoachMediaControls {
  void onNext();
  void onPrevious();
  void onPlay();
  void onPause();
}

/// Lo que el entrenamiento necesita de la sesión multimedia (se puede
/// reemplazar en pruebas).
abstract interface class CoachMediaBackend {
  Future<void> attach(CoachMediaControls controls);
  Future<void> release(CoachMediaControls controls);
  void update({
    required String title,
    required String subtitle,
    String? album,
    required bool playing,
  });
}

/// Sesión multimedia del entrenador.
///
/// Es la pieza que recibe los botones `<<`, `>>` y `play/pausa` de la bocina
/// (AVRCP), de audífonos Bluetooth, de la pantalla de bloqueo y de la
/// notificación. Para el sistema, MacroBuddy es "la app que está
/// reproduciendo", igual que Spotify.
///
/// Para que Android e iOS le manden los botones a esta app aunque no se esté
/// hablando, se reproduce en bucle un audio en silencio mientras dura el
/// entrenamiento.
class CoachMediaSession implements CoachMediaBackend {
  CoachMediaSession._();

  static final CoachMediaSession instance = CoachMediaSession._();

  static const String _silenceAsset = 'Assets/audio/silencio.wav';

  _CoachAudioHandler? _handler;
  Future<_CoachAudioHandler?>? _initializing;
  final AudioPlayer _silence = AudioPlayer(handleInterruptions: false);
  bool _silenceLoaded = false;

  /// Quién recibe los botones. Es una pila: si la pantalla de prueba toma
  /// los botones durante un entrenamiento, al cerrarla vuelven al
  /// entrenamiento.
  final List<CoachMediaControls> _stack = [];

  CoachMediaControls? get _controls => _stack.isEmpty ? null : _stack.last;

  /// Último botón recibido (para la pantalla de prueba de la bocina).
  final ValueNotifier<String?> lastButton = ValueNotifier<String?>(null);

  bool get isAvailable => _handler != null;

  Future<_CoachAudioHandler?> _ensureHandler() {
    return _initializing ??= () async {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
      } catch (e) {
        debugPrint('[CoachMediaSession] audio_session: $e');
      }
      try {
        _handler = await AudioService.init(
          builder: () => _CoachAudioHandler(this),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.macrobuddy.coach',
            androidNotificationChannelName: 'Entrenamiento con voz',
            androidNotificationIcon: 'mipmap/ic_launcher',
            // Mantiene el servicio en primer plano durante la pausa, para
            // poder reanudar desde la bocina con la pantalla apagada.
            androidStopForegroundOnPause: false,
          ),
        );
      } catch (e) {
        // Plataformas sin soporte (escritorio) o falta de configuración: el
        // entrenamiento funciona igual con los botones de la app.
        debugPrint('[CoachMediaSession] audio_service no disponible: $e');
        _handler = null;
      }
      return _handler;
    }();
  }

  /// Toma el control de los botones multimedia. [controls] recibe los
  /// eventos hasta que se llame a [release].
  @override
  Future<void> attach(CoachMediaControls controls) async {
    _stack
      ..remove(controls)
      ..add(controls);
    await _ensureHandler();
    await _startSilence();
  }

  /// Suelta los botones y detiene la sesión.
  @override
  Future<void> release(CoachMediaControls controls) async {
    if (!_stack.remove(controls)) return;
    if (_stack.isNotEmpty) return;
    await _stopSilence();
    final handler = _handler;
    if (handler != null) {
      handler.playbackState.add(
        handler.playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      handler.mediaItem.add(null);
    }
  }

  /// Actualiza lo que se ve en la pantalla de bloqueo / notificación y el
  /// estado play/pausa que se reporta a la bocina.
  @override
  void update({
    required String title,
    required String subtitle,
    String? album,
    required bool playing,
  }) {
    final handler = _handler;
    if (handler == null) return;
    handler.mediaItem.add(
      MediaItem(
        id: 'macrobuddy-coach',
        title: title,
        artist: subtitle,
        album: album ?? 'MacroBuddy',
      ),
    );
    handler.playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
      ),
    );
  }

  Future<void> _startSilence() async {
    try {
      if (!_silenceLoaded) {
        await _silence.setAsset(_silenceAsset);
        await _silence.setLoopMode(LoopMode.one);
        _silenceLoaded = true;
      }
      unawaited(_silence.play());
    } catch (e) {
      debugPrint('[CoachMediaSession] silencio: $e');
    }
  }

  Future<void> _stopSilence() async {
    try {
      await _silence.pause();
    } catch (_) {}
  }

  void _dispatch(String button, void Function(CoachMediaControls c) action) {
    lastButton.value = '$button · ${DateTime.now().millisecondsSinceEpoch}';
    final controls = _controls;
    if (controls != null) action(controls);
  }
}

class _CoachAudioHandler extends BaseAudioHandler {
  _CoachAudioHandler(this._owner);

  final CoachMediaSession _owner;

  @override
  Future<void> skipToNext() async =>
      _owner._dispatch('next', (c) => c.onNext());

  @override
  Future<void> skipToPrevious() async =>
      _owner._dispatch('previous', (c) => c.onPrevious());

  @override
  Future<void> play() async => _owner._dispatch('play', (c) => c.onPlay());

  @override
  Future<void> pause() async => _owner._dispatch('pause', (c) => c.onPause());

  // Algunas bocinas mandan "fast forward/rewind" en vez de next/previous.
  @override
  Future<void> fastForward() => skipToNext();

  @override
  Future<void> rewind() => skipToPrevious();

  @override
  Future<void> stop() async {
    // "Stop" desde la notificación: lo tratamos como pausa; terminar o
    // descartar solo se hace en la app.
    await pause();
  }
}
