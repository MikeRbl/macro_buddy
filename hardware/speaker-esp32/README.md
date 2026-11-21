# MacroBuddy Speaker (ESP32)

Bocina Bluetooth "entrenador" para la app MacroBuddy. Funciona como una bocina
Bluetooth normal: el teléfono le manda el audio (la voz del entrenador) y los
botones `<<`, `>>` y `play/pausa` mandan comandos de control multimedia que la
app convierte en *serie anterior*, *siguiente serie* y *pausa*.

No hay protocolo propio: se usan los perfiles estándar **A2DP** (audio) y
**AVRCP** (botones). Por eso la vinculación se hace desde los ajustes Bluetooth
del teléfono, una sola vez, y funciona también con Spotify o YouTube.

```
 Teléfono (app MacroBuddy)                       Bocina
 ┌──────────────────────┐   A2DP (audio)   ┌──────────────────────────┐
 │ Voz: clips de Mike   │ ───────────────▶ │ ESP32 ──I2S──▶ MAX98357A │──▶ 🔊
 │      o TTS           │                  │   ▲                      │
 │ Media session        │ ◀─────────────── │ botones << >|| >>        │
 └──────────────────────┘   AVRCP (botones)└──────────────────────────┘
```

## Lista de componentes

| Componente | Cant. | Precio aprox. (MXN) | Nota |
|---|---|---|---|
| ESP32 DevKit V1 (**WROOM-32**) | 1 | $150 | El S3, C3 y C6 **no** tienen Bluetooth clásico (A2DP). |
| Amplificador I2S MAX98357A (3 W) | 1 | $90 | Bocina de 4 a 8 Ω. |
| Bocina 4–8 Ω, 3–5 W | 1 | (la que ya tienes) | |
| Botón pulsador 12 mm | 3 | $30 | `<<`, `>||`, `>>`. |
| LED 5 mm + resistencia 220 Ω | 1 | $5 | Opcional: el DevKit ya trae un LED azul en GPIO 2. |
| Batería 18650 + portapilas | 1 | $120 | |
| Módulo de carga TP4056 USB-C **con protección** (DW01) | 1 | $30 | El que tiene 6 pines: `B+ B- OUT+ OUT-`. |
| Elevador MT3608 | 1 | $30 | Ajustar a **5.0 V** antes de conectar nada. |
| Interruptor deslizable | 1 | $10 | Encendido. |
| Placa perforada, headers, cables dupont, termofit | – | $70 | |
| Carcasa impresa en 3D o caja de proyecto | 1 | – | |

Total aproximado: **$550 a $650 MXN** (sin la bocina).

## Cableado

### Audio (ESP32 → MAX98357A)

| MAX98357A | ESP32 |
|---|---|
| `VIN` | `5V` del MT3608 (mismo riel que el `VIN` del ESP32) |
| `GND` | `GND` |
| `BCLK` | `GPIO 26` |
| `LRC` | `GPIO 25` |
| `DIN` | `GPIO 22` |
| `SD` | sin conectar (mezcla L+R en mono) |
| `GAIN` | sin conectar (9 dB). A `GND` = 12 dB, a `VIN` = 6 dB |
| `+` / `-` | a la bocina |

### Botones y LED

Cada botón va entre el pin y `GND`. No hacen falta resistencias: el firmware
activa el *pull-up* interno.

| Función | ESP32 |
|---|---|
| `<<` anterior (mantener = bajar volumen) | `GPIO 32` |
| `>||` play / pausa | `GPIO 33` |
| `>>` siguiente (mantener = subir volumen) | `GPIO 27` |
| LED de estado (externo, opcional) | `GPIO 2` → 220 Ω → LED → `GND` |

### Alimentación

```
 18650 ──▶ TP4056 (B+/B-) ── OUT+ ──▶ interruptor ──▶ MT3608 IN+ ── OUT+ (5.0 V) ──┬──▶ ESP32 VIN
                         └─ OUT- ─────────────────▶ MT3608 IN- ── OUT- (GND) ──┬──│──▶ ESP32 GND
                                                                               │  └──▶ MAX98357A VIN
                                                                               └─────▶ MAX98357A GND
```

1. Conecta el MT3608 solo a la batería y gira su potenciómetro hasta medir
   **5.0 V** en la salida con el multímetro. Si lo conectas sin ajustar puede
   dar más de 20 V y quemar el ESP32.
2. Luego conecta el ESP32 (`VIN` y `GND`) y el MAX98357A.
3. Para cargar, conecta USB-C al TP4056. Para programar el ESP32 por USB,
   apaga el interruptor primero.

## Programar el ESP32

1. Arduino IDE 2.x → *Preferencias* → URL de placas:
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`.
   Instala **esp32 by Espressif** (2.x o 3.x).
2. Instala las librerías (descargar ZIP de GitHub → *Programa* → *Incluir
   biblioteca* → *Añadir .ZIP*):
   - [ESP32-A2DP](https://github.com/pschatzmann/ESP32-A2DP)
   - [arduino-audio-tools](https://github.com/pschatzmann/arduino-audio-tools)
3. Abre `macrobuddy_speaker/macrobuddy_speaker.ino`.
4. Placa: **ESP32 Dev Module**. Partition Scheme: **Huge APP (3MB No OTA)**.
5. Sube el programa y abre el Monitor Serie a 115200 baudios. Debe decir
   `Listo. Busca "MacroBuddy Speaker"...`.

Para cambiar el nombre o los pines, edita las constantes al inicio del `.ino`.

## Vincular con el teléfono

1. Enciende la bocina: el LED parpadea lento (esperando conexión).
2. En el teléfono: *Ajustes → Bluetooth → MacroBuddy Speaker*.
3. El LED queda fijo. La próxima vez se reconecta sola al último teléfono.
4. En la app: *Perfil → Bocina MacroBuddy* (o el icono de bocina en la vista
   previa del entrenamiento) muestra si está conectada y tiene un botón de
   *Probar voz*.

| LED | Significado |
|---|---|
| Parpadeo lento | Sin conexión, visible para emparejar |
| Fijo | Conectado y reproduciendo |
| Parpadeo doble | Conectado y en pausa |
| Se apaga un instante | Se presionó un botón |

## Plan de pruebas

1. **Protoboard + música:** ESP32 + MAX98357A + bocina. Reproduce Spotify
   desde el teléfono y confirma que suena.
2. **Botones:** con Spotify abierto, `>>` cambia de canción, `>||` pausa.
3. **App:** inicia un *Entrenamiento con voz*; la bocina dice el ejercicio y
   `>>` avanza a la siguiente serie.
4. **Batería y carcasa:** pasa todo a placa perforada, mide autonomía.

## Problemas comunes

- **No aparece en Bluetooth:** revisa que sea un ESP32 WROOM-32 (no S3/C3) y
  que el Monitor Serie diga `Listo`.
- **Error de compilación "Sketch too big":** cambia el Partition Scheme a
  *Huge APP*.
- **Suena con ruido o cortado:** verifica `GND` común y que el MT3608 entregue
  5 V estables. Un capacitor de 470 µF entre 5 V y GND cerca del amplificador
  ayuda.
- **Los botones no hacen nada en la app:** la app debe estar en el
  entrenamiento con voz (es quien tiene la "sesión multimedia" activa). Si otra
  app (Spotify) reprodujo audio después, Android le manda los botones a esa app;
  vuelve a presionar *play* en la app de MacroBuddy.
