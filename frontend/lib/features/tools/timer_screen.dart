import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/sound_util.dart';
import '../../theme/app_theme.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final List<Duration> _presets = [
    const Duration(minutes: 5),
    const Duration(minutes: 1),
  ];

  Duration? _remaining;
  Duration? _total;
  Timer? _countdown;

  bool get _running => _countdown != null;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _label(Duration d) {
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
    return '${d.inSeconds} s';
  }

  void _start(Duration duration) {
    _countdown?.cancel();
    _remaining = duration;
    _total = duration;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining! - const Duration(seconds: 1);
        if (_remaining! <= Duration.zero) {
          _remaining = Duration.zero;
          timer.cancel();
          _countdown = null;
          SoundUtil.playBeep();
        }
      });
    });
  }

  void _pause() {
    _countdown?.cancel();
    _countdown = null;
    setState(() {});
  }

  void _stop() {
    _countdown?.cancel();
    _countdown = null;
    setState(() {
      _remaining = null;
      _total = null;
    });
  }

  Future<void> _createPreset() async {
    final duration = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateTimerSheet(),
    );
    if (duration != null && mounted) {
      setState(() => _presets.insert(0, duration));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final remaining = _remaining;
    final total = _total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temporizador'),
        actions: [
          IconButton(
            onPressed: _createPreset,
            icon: Icon(Icons.add, color: c.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (remaining != null && total != null) ...[
              Material(
                color: c.card,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _format(remaining),
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total.inMilliseconds > 0
                              ? remaining.inMilliseconds / total.inMilliseconds
                              : 0,
                          minHeight: 6,
                          backgroundColor: c.input,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _running ? _pause : () {},
                            icon: const Icon(Icons.pause),
                            label: const Text('Pausa'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _stop,
                            icon: const Icon(Icons.stop),
                            label: const Text('Detener'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mis temporizadores',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _createPreset,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final preset in _presets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppColors.radiusCard),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: AppColors.accentOrange,
                    ),
                    title: Text(
                      _label(preset),
                      style: TextStyle(color: c.textPrimary, fontSize: 16),
                    ),
                    trailing: Icon(
                      Icons.play_circle_outline,
                      color: c.textSecondary,
                    ),
                    onTap: () => _start(preset),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateTimerSheet extends StatefulWidget {
  const _CreateTimerSheet();

  @override
  State<_CreateTimerSheet> createState() => _CreateTimerSheetState();
}

class _CreateTimerSheetState extends State<_CreateTimerSheet> {
  static const _maxHours = 24;

  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _save() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    if (hours > _maxHours ||
        (hours == _maxHours && (minutes > 0 || seconds > 0))) {
      setState(() => _error = 'El máximo es 24 horas.');
      return;
    }
    if (minutes > 59 || seconds > 59) {
      setState(() => _error = 'Minutos y segundos deben ser menores a 60.');
      return;
    }
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    if (duration == Duration.zero) {
      setState(() => _error = 'Ingresa un tiempo mayor a cero.');
      return;
    }
    Navigator.of(context).pop(duration);
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crear temporizador',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_hoursController, 'Horas', 2)),
              const SizedBox(width: 8),
              Expanded(child: _field(_minutesController, 'Min', 2)),
              const SizedBox(width: 8),
              Expanded(child: _field(_secondsController, 'Seg', 2)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, int maxLen) {
    final c = ThemeColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLen),
      ],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
        isDense: true,
      ),
    );
  }
}
