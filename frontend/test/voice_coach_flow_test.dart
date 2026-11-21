import 'package:flutter_test/flutter_test.dart';

import 'package:macrobuddy/features/voice_coach/coach_media_session.dart';
import 'package:macrobuddy/features/voice_coach/coach_voice.dart';
import 'package:macrobuddy/features/voice_coach/guided_workout_controller.dart';
import 'package:macrobuddy/features/workout/workout_models.dart';

/// Voz falsa: guarda lo que diría en vez de hablar.
class _FakeVoice extends CoachVoice {
  _FakeVoice({required super.library});

  final said = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> say(VoicePhrase phrase) async => said.add(phrase.text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeMedia implements CoachMediaBackend {
  CoachMediaControls? controls;
  bool? playing;
  String? title;

  @override
  Future<void> attach(CoachMediaControls c) async => controls = c;

  @override
  Future<void> release(CoachMediaControls c) async => controls = null;

  @override
  void update({
    required String title,
    required String subtitle,
    String? album,
    required bool playing,
  }) {
    this.title = title;
    this.playing = playing;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flujo: siguiente, descanso, anterior, pausa y fin', () async {
    final media = _FakeMedia();
    late _FakeVoice voice;
    final c = GuidedWorkoutController(
      restSeconds: 30,
      mediaSession: media,
      voiceFactory: (lib) => voice = _FakeVoice(library: lib),
      exercises: const [
        PreviewExercise(id: 'a', name: 'push up', sets: 2, minReps: 10, maxReps: 10, isBodyweight: true),
        PreviewExercise(id: 'b', name: 'squat', sets: 1, minReps: 15, maxReps: 15, isBodyweight: true),
      ],
    );
    await c.init();
    await c.start();
    expect(c.phase, GuidedPhase.working);
    expect(media.controls, same(c));
    expect(media.title, 'push up');
    expect(voice.said.last, contains('10 lagartijas. Serie 1 de 2'));

    // ">>" desde la bocina: termina la serie 1 y empieza el descanso.
    media.controls!.onNext();
    expect(c.sets[0].done, isTrue);
    expect(c.phase, GuidedPhase.resting);
    expect(c.position, 1);
    expect(c.restRemaining, 30);
    expect(voice.said.last, contains('Descanso. 30 segundos'));

    // "<<": regresa a la serie 1.
    media.controls!.onPrevious();
    expect(c.phase, GuidedPhase.working);
    expect(c.position, 0);
    expect(c.sets[0].done, isFalse);

    c.next(); // descanso
    c.next(); // salta descanso
    expect(c.phase, GuidedPhase.working);
    expect(c.position, 1);
    expect(voice.said.last, contains('Última serie'));

    // Pausa desde la bocina.
    media.controls!.onPause();
    expect(c.paused, isTrue);
    expect(media.playing, isFalse);
    media.controls!.onPlay();
    expect(c.paused, isFalse);
    expect(media.playing, isTrue);

    c.next(); // serie 2 de push up → descanso
    c.next(); // salta descanso
    expect(voice.said.last, contains('Último ejercicio'));
    expect(voice.said.last, contains('15 sentadillas'));
    c.next(); // sentadillas: última serie → fin
    expect(c.phase, GuidedPhase.finished);
    expect(c.completedSets, 3);
    expect(c.buildSetsPayload().length, 3);
    expect(voice.said.last, contains('Terminaste'));

    c.dispose();
    expect(media.controls, isNull);
  });

}
