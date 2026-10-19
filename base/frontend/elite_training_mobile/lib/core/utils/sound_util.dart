import 'sound_util_stub.dart'
    if (dart.library.html) 'sound_util_web.dart';

abstract final class SoundUtil {
  static void playBeep() {
    playPlatformBeep();
  }
}
