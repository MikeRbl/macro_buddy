import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Objetivo diario de pasos. Local y configurable en el futuro.
const dailyStepsGoal = 8000;

/// Estado local del podómetro. Los pasos NUNCA salen del dispositivo.
class StepsState {
  const StepsState({
    this.stepsToday = 0,
    this.permissionGranted = true,
    this.failed = false,
  });

  final int stepsToday;
  final bool permissionGranted;
  final bool failed;

  StepsState copyWith({
    int? stepsToday,
    bool? permissionGranted,
    bool? failed,
  }) {
    return StepsState(
      stepsToday: stepsToday ?? this.stepsToday,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      failed: failed ?? this.failed,
    );
  }
}

final stepsProvider = NotifierProvider<StepsController, StepsState>(
  StepsController.new,
);

/// El sensor TYPE_STEP_COUNTER entrega pasos acumulados desde el último
/// encendido del dispositivo; el controlador guarda el baseline del día
/// para estimar los pasos de hoy (medición local, se resetea si el
/// dispositivo se reinicia o cambia el día).
class StepsController extends Notifier<StepsState> {
  StreamSubscription<StepCount>? _sub;
  int _baseline = -1;
  int _lastRaw = -1;
  int _dayAtBaseline = -1;

  @override
  StepsState build() {
    Future.microtask(_start);
    ref.onDispose(() => _sub?.cancel());
    return const StepsState();
  }

  Future<void> _start() async {
    // Android 10+: ACTIVITY_RECOGNITION es permiso dangerous y se pide
    // en runtime. iOS usa CoreMotion y no pide nada.
    try {
      if (await Permission.activityRecognition.request().isDenied ||
          await Permission.activityRecognition.isPermanentlyDenied) {
        state = const StepsState(permissionGranted: false);
        return;
      }
    } catch (_) {
      // Plataformas sin activity recognition: seguimos con el stream.
    }
    _listen();
  }

  Future<void> _listen() async {
    await _sub?.cancel();
    _sub = Pedometer.stepCountStream.listen(
      _onEvent,
      onError: (_) =>
          state = state.copyWith(failed: true, permissionGranted: false),
      cancelOnError: false,
    );
  }

  void _onEvent(StepCount event) {
    final raw = event.steps;
    final day = event.timeStamp.day;
    final deviceRebooted = raw < _lastRaw;
    final dayChanged = day != _dayAtBaseline;
    if (_baseline < 0 || deviceRebooted || dayChanged) {
      _baseline = raw;
      _dayAtBaseline = day;
    }
    _lastRaw = raw;
    final steps = raw - _baseline;
    state = state.copyWith(
      stepsToday: steps < 0 ? 0 : steps,
      permissionGranted: true,
      failed: false,
    );
  }

  /// Reintenta tras conceder el permiso en Ajustes.
  Future<void> retry() async {
    state = const StepsState();
    await _start();
  }
}
