import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  final List<Duration> _laps = [];

  bool get _running => _stopwatch.isRunning;

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hundredths = (d.inMilliseconds % 1000) ~/ 10;
    return '${d.inMinutes}:${two(d.inSeconds % 60)}.${two(hundredths)}';
  }

  void _start() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  void _pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() {});
  }

  void _lap() {
    if (!_running) return;
    setState(() => _laps.insert(0, _stopwatch.elapsed));
  }

  void _reset() {
    _pause();
    _stopwatch.reset();
    setState(() => _laps.clear());
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final time = _format(_stopwatch.elapsed);

    return Scaffold(
      appBar: AppBar(title: const Text('Cronómetro')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              time,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  label: _running ? 'Vuelta' : 'Reiniciar',
                  icon: _running ? Icons.flag : Icons.restart_alt,
                  onTap: _running ? _lap : _reset,
                ),
                const SizedBox(width: 24),
                _ActionButton(
                  label: _running ? 'Pausa' : 'Inicio',
                  icon: _running ? Icons.pause : Icons.play_arrow,
                  primary: true,
                  onTap: _running ? _pause : _start,
                ),
              ],
            ),
            const Spacer(flex: 2),
            Divider(height: 1, color: c.input),
            Expanded(
              flex: 3,
              child: _laps.isEmpty
                  ? Center(
                      child: Text(
                        'Sin vueltas registradas',
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _laps.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.input),
                      itemBuilder: (context, index) {
                        final lapNumber = _laps.length - index;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vuelta $lapNumber',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _format(_laps[index]),
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final color = primary ? c.textPrimary : c.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.input,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
