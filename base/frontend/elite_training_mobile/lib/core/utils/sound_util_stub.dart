import 'package:flutter/services.dart';

void playPlatformBeep() {
  try {
    SystemSound.play(SystemSoundType.click);
  } catch (_) {}
}
