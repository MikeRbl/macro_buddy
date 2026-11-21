import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../workout/workout_models.dart';
import 'coach_media_session.dart';
import 'coach_phrases.dart';
import 'coach_voice.dart';
import 'voice_clip_library.dart';

/// Nombre con el que se anuncia el firmware de la bocina.
const String kSpeakerName = 'MacroBuddy Speaker';

/// Conectar y probar la bocina MacroBuddy, y revisar qué clips de voz hay.
///
/// La bocina es una bocina Bluetooth estándar: se empareja desde los ajustes
/// del teléfono. Esta pantalla detecta si está conectada como salida de audio,
/// permite probar la voz y los botones.
class SpeakerSetupScreen extends StatefulWidget {
  const SpeakerSetupScreen({super.key, this.exercises = const []});

  /// Si se abre desde un entrenamiento, muestra qué clips le faltan.
  final List<PreviewExercise> exercises;

  @override
  State<SpeakerSetupScreen> createState() => _SpeakerSetupScreenState();
}

class _SpeakerSetupScreenState extends State<SpeakerSetupScreen>
    with WidgetsBindingObserver
    implements CoachMediaControls {
  List<AudioDevice> _bluetooth = [];
  bool _checking = true;
  bool _detectionSupported = true;
  StreamSubscription<AudioDevicesChangedEvent>? _devicesSub;

  VoiceClipLibrary? _library;
  CoachVoice? _voice;

  bool _testingButtons = false;
  String? _lastButton;
  bool _testPlaying = true;
  bool _mediaAttachedByUs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDevices();
    _listenDevices();
    VoiceClipLibrary.load().then((lib) {
      if (!mounted) return;
      setState(() {
        _library = lib;
        _voice = CoachVoice(library: lib);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _devicesSub?.cancel();
    _voice?.dispose();
    if (_mediaAttachedByUs) CoachMediaSession.instance.release(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de los ajustes de Bluetooth.
    if (state == AppLifecycleState.resumed) _refreshDevices();
  }

  Future<void> _listenDevices() async {
    try {
      final session = await AudioSession.instance;
      _devicesSub = session.devicesChangedEventStream.listen(
        (_) => _refreshDevices(),
      );
    } catch (_) {}
  }

  Future<void> _refreshDevices() async {
    setState(() => _checking = true);
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices(includeInputs: false);
      final bt = devices
          .where(
            // ignore: experimental_member_use
            (d) => d.isOutput && d.type == AudioDeviceType.bluetoothA2dp,
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _bluetooth = bt;
        _checking = false;
        _detectionSupported = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _detectionSupported = false;
      });
    }
  }

  AudioDevice? get _macroBuddy {
    for (final d in _bluetooth) {
      if (d.name.toLowerCase().contains('macrobuddy')) return d;
    }
    return null;
  }

  Future<void> _openBluetoothSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abre Ajustes > Bluetooth en tu teléfono.'),
        ),
      );
    }
  }

  Future<void> _testVoice() async {
    final voice = _voice;
    final lib = _library;
    if (voice == null || lib == null) return;
    final phrases = CoachPhrases(lib);
    await voice.say(
      phrases.hello() +
          phrases.setAnnouncement(
            name: 'push up',
            setNumber: 1,
            totalSets: 3,
            minReps: 10,
            maxReps: 10,
          ) +
          phrases.encouragement(),
    );
  }

  Future<void> _toggleButtonTest() async {
    if (_testingButtons) {
      setState(() => _testingButtons = false);
      await CoachMediaSession.instance.release(this);
      _mediaAttachedByUs = false;
      return;
    }
    setState(() {
      _testingButtons = true;
      _lastButton = null;
      _testPlaying = true;
    });
    await CoachMediaSession.instance.attach(this);
    _mediaAttachedByUs = true;
    _syncTestMedia();
  }

  void _syncTestMedia() {
    CoachMediaSession.instance.update(
      title: 'Prueba de botones',
      subtitle: _lastButton ?? 'Presiona un botón de la bocina',
      playing: _testPlaying,
    );
  }

  void _gotButton(String label) {
    if (!mounted) return;
    setState(() => _lastButton = label);
    _syncTestMedia();
  }

  @override
  void onNext() => _gotButton('⏭  Siguiente');

  @override
  void onPrevious() => _gotButton('⏮  Anterior');

  @override
  void onPause() {
    _testPlaying = false;
    _gotButton('⏸  Pausa');
  }

  @override
  void onPlay() {
    _testPlaying = true;
    _gotButton('▶  Play');
  }

  // -------------------------------------------------------------- UI ------

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bocina MacroBuddy',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppColors.screenPadding),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildPairingSteps(),
          const SizedBox(height: 16),
          _buildTests(),
          const SizedBox(height: 16),
          _buildVoices(),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: child,
    );
  }

  Widget _buildStatusCard() {
    final c = ThemeColors.of(context);
    final mb = _macroBuddy;
    final other = mb == null && _bluetooth.isNotEmpty ? _bluetooth.first : null;

    IconData icon;
    Color color;
    String title;
    String subtitle;
    if (_checking) {
      icon = Icons.bluetooth_searching;
      color = c.textSecondary;
      title = 'Buscando bocina...';
      subtitle = '';
    } else if (!_detectionSupported) {
      icon = Icons.bluetooth;
      color = c.textSecondary;
      title = 'No se puede detectar aquí';
      subtitle = 'Conecta la bocina desde el Bluetooth del teléfono y usa '
          '"Probar voz".';
    } else if (mb != null) {
      icon = Icons.bluetooth_connected;
      color = AppColors.accentTeal;
      title = '${mb.name} conectada';
      subtitle = 'La voz del entrenador saldrá por la bocina.';
    } else if (other != null) {
      icon = Icons.bluetooth_connected;
      color = AppColors.warningAmber;
      title = 'Conectado a ${other.name}';
      subtitle = 'Funciona igual, pero no es la bocina MacroBuddy.';
    } else {
      icon = Icons.bluetooth_disabled;
      color = AppColors.danger;
      title = 'Bocina no conectada';
      subtitle = 'La voz saldrá por el teléfono.';
    }

    return _card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshDevices,
            icon: Icon(Icons.refresh, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingSteps() {
    final c = ThemeColors.of(context);
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: c.input,
                child: Text(
                  '$n',
                  style: TextStyle(color: c.textPrimary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vincular (solo la primera vez)',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          step(1, 'Enciende la bocina. El LED parpadea lento.'),
          step(2, 'Abre el Bluetooth del teléfono y elige "$kSpeakerName".'),
          step(3, 'El LED queda fijo. Las próximas veces se conecta sola.'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openBluetoothSettings,
              icon: const Icon(Icons.bluetooth),
              label: const Text('Abrir ajustes de Bluetooth'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTests() {
    final c = ThemeColors.of(context);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Probar',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _voice == null ? null : _testVoice,
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Probar voz'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _toggleButtonTest,
              icon: Icon(_testingButtons ? Icons.stop : Icons.touch_app),
              label: Text(
                _testingButtons ? 'Terminar prueba de botones' : 'Probar botones',
              ),
            ),
          ),
          if (_testingButtons) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.input,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lastButton ?? 'Presiona ⏮  ⏯  ⏭ en la bocina...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _lastButton == null ? c.textSecondary : c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoices() {
    final c = ThemeColors.of(context);
    final lib = _library;
    if (lib == null) return const SizedBox.shrink();

    final needed = <String, String>{};
    for (final ex in widget.exercises) {
      final v = lib.exerciseVoice(ex.name);
      needed[v.key] = '${ex.name} → "${v.text}"';
    }
    final missing = needed.keys.where((k) => !lib.has(k)).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voz del entrenador',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lib.count == 0
                ? 'Aún no hay clips grabados: se usa la voz del teléfono.'
                : '${lib.count} clips grabados. Lo que falte se dice con la '
                    'voz del teléfono.',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (widget.exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              missing.isEmpty
                  ? 'Este entrenamiento tiene todos sus ejercicios grabados.'
                  : 'Clips que faltan para este entrenamiento:',
              style: TextStyle(color: c.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            for (final key in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '$key.mp3  ·  ${needed[key]}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
