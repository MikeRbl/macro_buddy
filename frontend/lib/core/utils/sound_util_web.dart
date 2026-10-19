// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void playPlatformBeep() {
  try {
    const beepBase64 =
        'data:audio/wav;base64,UklGRl9vT19XQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YU'
        '9vT18A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A'
        '/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A'
        '/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A/38A';
    final audio = html.AudioElement(beepBase64);
    audio.play();
  } catch (_) {}
}
