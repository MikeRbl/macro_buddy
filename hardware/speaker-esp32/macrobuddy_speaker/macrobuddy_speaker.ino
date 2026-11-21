/*
 * MacroBuddy Speaker — firmware para ESP32 (WROOM-32, Bluetooth clásico)
 *
 * Qué hace:
 *  - Se anuncia como bocina Bluetooth "MacroBuddy Speaker" (perfil A2DP sink).
 *  - El audio que manda el teléfono (voz del entrenador, TTS o clips) sale por
 *    I2S hacia un amplificador MAX98357A y de ahí a la bocina.
 *  - 3 botones mandan comandos de control multimedia (AVRCP) al teléfono:
 *      <<  (anterior)   -> ejercicio/serie anterior
 *      >>  (siguiente)  -> siguiente ejercicio/serie
 *      >|| (play/pausa) -> pausa o reanuda el entrenamiento
 *    Mantener presionado << o >> (0.6 s) baja / sube el volumen.
 *  - Un LED indica el estado:
 *      parpadeo lento  -> esperando conexión (visible para emparejar)
 *      fijo            -> conectado
 *      parpadeo doble  -> conectado y en pausa
 *      destello corto  -> se presionó un botón
 *
 * Librerías (Arduino IDE > Administrar bibliotecas, o ZIP desde GitHub):
 *  - ESP32-A2DP        https://github.com/pschatzmann/ESP32-A2DP
 *  - arduino-audio-tools https://github.com/pschatzmann/arduino-audio-tools
 *
 * Placa: "ESP32 Dev Module". Esquema de partición: "Huge APP (3MB No OTA)"
 * (la pila Bluetooth no cabe en la partición por defecto).
 *
 * Cableado completo en ../README.md
 */

#include "AudioTools.h"
#include "BluetoothA2DPSink.h"

// ---------------------------------------------------------------- Pines ----
// MAX98357A (I2S)
static const int PIN_I2S_BCLK = 26;  // BCLK
static const int PIN_I2S_LRC  = 25;  // LRC / WS
static const int PIN_I2S_DIN  = 22;  // DIN

// Botones (a GND, con pull-up interno). Evita GPIO 34-39 (no tienen pull-up).
static const int PIN_BTN_PREV = 32;
static const int PIN_BTN_PLAY = 33;
static const int PIN_BTN_NEXT = 27;

// LED de estado (GPIO 2 es el LED azul integrado del DevKit V1).
static const int PIN_LED = 2;

static const char *DEVICE_NAME = "MacroBuddy Speaker";

// ------------------------------------------------------------ Ajustes ------
static const uint32_t DEBOUNCE_MS   = 30;
static const uint32_t LONG_PRESS_MS = 600;   // mantener para volumen
static const uint32_t REPEAT_MS     = 200;   // repetición de volumen
static const uint8_t  VOLUME_STEP   = 8;     // 0..127
static const uint8_t  START_VOLUME  = 100;

// -------------------------------------------------------------- Estado -----
I2SStream i2s;
BluetoothA2DPSink a2dp_sink(i2s);

volatile bool g_connected = false;
volatile bool g_playing   = false;  // según el teléfono (AVRCP play status)
uint32_t g_flashUntil = 0;          // destello al presionar botón

enum ButtonId { BTN_PREV = 0, BTN_PLAY, BTN_NEXT, BTN_COUNT };

struct Button {
  int pin;
  bool stablePressed;
  bool lastRaw;
  uint32_t lastChange;
  uint32_t pressedAt;
  uint32_t lastRepeat;
  bool longFired;
};

Button buttons[BTN_COUNT] = {
  {PIN_BTN_PREV, false, false, 0, 0, 0, false},
  {PIN_BTN_PLAY, false, false, 0, 0, 0, false},
  {PIN_BTN_NEXT, false, false, 0, 0, 0, false},
};

// ----------------------------------------------------------- Callbacks -----
void onConnectionStateChanged(esp_a2d_connection_state_t state, void *) {
  g_connected = (state == ESP_A2D_CONNECTION_STATE_CONNECTED);
  if (!g_connected) g_playing = false;
  Serial.printf("[BT] conexion: %s\n", a2dp_sink.to_str(state));
}

void onAudioStateChanged(esp_a2d_audio_state_t state, void *) {
  // El flujo de audio puede suspenderse en silencios largos; solo lo usamos
  // como pista si el teléfono no reporta play status por AVRCP.
  Serial.printf("[BT] audio: %s\n", a2dp_sink.to_str(state));
}

void onPlayStatus(esp_avrc_playback_stat_t status) {
  g_playing = (status == ESP_AVRC_PLAYBACK_PLAYING);
  Serial.printf("[AVRCP] play status: %s\n", g_playing ? "playing" : "paused");
}

// ------------------------------------------------------------ Acciones -----
void flash() { g_flashUntil = millis() + 120; }

void sendPrevious() {
  Serial.println("[BTN] << anterior");
  a2dp_sink.previous();
  flash();
}

void sendNext() {
  Serial.println("[BTN] >> siguiente");
  a2dp_sink.next();
  flash();
}

void sendPlayPause() {
  // Mandamos el comando contrario al estado que conocemos. Si el teléfono no
  // reporta su estado, alternamos localmente.
  if (g_playing) {
    Serial.println("[BTN] pausa");
    a2dp_sink.pause();
  } else {
    Serial.println("[BTN] play");
    a2dp_sink.play();
  }
  g_playing = !g_playing;
  flash();
}

void changeVolume(int delta) {
  int v = (int)a2dp_sink.get_volume() + delta;
  if (v < 0) v = 0;
  if (v > 127) v = 127;
  a2dp_sink.set_volume((uint8_t)v);
  Serial.printf("[VOL] %d\n", v);
  flash();
}

// ------------------------------------------------------------- Botones -----
void onShortPress(ButtonId id) {
  if (!g_connected) return;
  switch (id) {
    case BTN_PREV: sendPrevious(); break;
    case BTN_PLAY: sendPlayPause(); break;
    case BTN_NEXT: sendNext(); break;
    default: break;
  }
}

void onLongPressTick(ButtonId id) {
  if (!g_connected) return;
  if (id == BTN_PREV) changeVolume(-VOLUME_STEP);
  if (id == BTN_NEXT) changeVolume(+VOLUME_STEP);
}

void pollButtons() {
  const uint32_t now = millis();
  for (int i = 0; i < BTN_COUNT; i++) {
    Button &b = buttons[i];
    const bool raw = digitalRead(b.pin) == LOW;  // pull-up: presionado = LOW

    if (raw != b.lastRaw) {
      b.lastRaw = raw;
      b.lastChange = now;
    }
    if (now - b.lastChange < DEBOUNCE_MS) continue;

    if (raw && !b.stablePressed) {          // se presionó
      b.stablePressed = true;
      b.pressedAt = now;
      b.longFired = false;
    } else if (!raw && b.stablePressed) {   // se soltó
      b.stablePressed = false;
      if (!b.longFired) onShortPress((ButtonId)i);
    } else if (raw && b.stablePressed) {    // sigue presionado
      const bool hasLong = (i == BTN_PREV || i == BTN_NEXT);
      if (hasLong && now - b.pressedAt >= LONG_PRESS_MS) {
        if (!b.longFired || now - b.lastRepeat >= REPEAT_MS) {
          b.longFired = true;
          b.lastRepeat = now;
          onLongPressTick((ButtonId)i);
        }
      }
    }
  }
}

// ----------------------------------------------------------------- LED -----
void updateLed() {
  const uint32_t now = millis();
  bool on;
  if (now < g_flashUntil) {
    on = false;  // destello: se apaga un instante
  } else if (!g_connected) {
    on = (now / 500) % 2 == 0;  // parpadeo lento (1 Hz)
  } else if (!g_playing) {
    const uint32_t t = now % 1500;  // parpadeo doble
    on = (t < 100) || (t > 250 && t < 350);
  } else {
    on = true;  // conectado y reproduciendo
  }
  digitalWrite(PIN_LED, on ? HIGH : LOW);
}

// --------------------------------------------------------------- Setup -----
void setup() {
  Serial.begin(115200);
  Serial.println();
  Serial.println("MacroBuddy Speaker arrancando...");

  pinMode(PIN_LED, OUTPUT);
  for (auto &b : buttons) pinMode(b.pin, INPUT_PULLUP);

  // I2S hacia el MAX98357A
  auto cfg = i2s.defaultConfig(TX_MODE);
  cfg.pin_bck = PIN_I2S_BCLK;
  cfg.pin_ws = PIN_I2S_LRC;
  cfg.pin_data = PIN_I2S_DIN;
  i2s.begin(cfg);

  a2dp_sink.set_on_connection_state_changed(onConnectionStateChanged);
  a2dp_sink.set_on_audio_state_changed(onAudioStateChanged);
  a2dp_sink.set_avrc_rn_playstatus_callback(onPlayStatus);
  a2dp_sink.set_auto_reconnect(true);  // se reconecta al último teléfono
  a2dp_sink.start(DEVICE_NAME);
  a2dp_sink.set_volume(START_VOLUME);

  Serial.printf("Listo. Busca \"%s\" en el Bluetooth del telefono.\n", DEVICE_NAME);
}

void loop() {
  pollButtons();
  updateLed();
  delay(5);
}
