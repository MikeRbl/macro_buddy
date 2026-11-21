# macrobuddy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# elte_training_frontend

## Entrenar con voz (bocina MacroBuddy)

Modo de entrenamiento guiado por voz para la bocina Bluetooth MacroBuddy
(firmware y cableado en [`../hardware/speaker-esp32`](../hardware/speaker-esp32/README.md)).

- Entrada: vista previa de un entrenamiento → **Entrenar con voz (bocina)**.
  La pantalla de la bocina está en el icono 🔊 de la vista previa y en
  *Perfil → Bocina MacroBuddy*.
- Código: `lib/features/voice_coach/`.
  - `guided_workout_controller.dart`: flujo serie → descanso → siguiente.
  - `coach_voice.dart` + `voice_clip_library.dart`: encadena clips grabados y
    usa TTS para lo que falte.
  - `coach_media_session.dart`: sesión multimedia (`audio_service`) que recibe
    los botones `<<`, `>||`, `>>` de la bocina.
- Voces: `Assets/voces/` (ver su `README.md`). Sin clips, todo funciona con TTS.
