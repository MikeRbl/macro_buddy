# Voces del entrenador

Aquí van los clips de voz grabados que usa **Entrenar con voz**. La app arma
cada frase con clips cortos y, si falta alguno, dice ese pedazo con la voz del
teléfono (TTS). Con esta carpeta vacía todo funciona solo con TTS.

## Cómo agregar un clip

1. Graba el clip y guárdalo aquí con el nombre de su clave:
   `Assets/voces/num_10.mp3`, `Assets/voces/ej_lagartijas.mp3`, etc.
2. Recompila la app (`flutter run` o `flutter build apk`).

No hay que registrar nada: la app descubre los archivos por su nombre.
Formatos: `.mp3`, `.m4a`, `.aac`, `.wav`, `.ogg`. Todo en esta carpeta, sin
subcarpetas.

Para revisar qué falta: abre un entrenamiento → icono de bocina → sección
*Voz del entrenador*. Ahí aparecen los clips de ejercicios que faltan para ese
entrenamiento, con el nombre exacto del archivo.

## Cómo se arman las frases

| Momento | Frase | Claves |
|---|---|---|
| Inicio | "¡Vamos a entrenar!" | `frase_comenzamos` |
| Primera serie de un ejercicio | "Primer / Siguiente / Último ejercicio." | `frase_primer_ejercicio`, `frase_siguiente_ejercicio`, `frase_ultimo_ejercicio` |
| Última serie de un ejercicio | "Última serie." | `frase_ultima_serie` |
| Anuncio de serie | "Diez lagartijas. Serie uno de tres." | `num_10` `ej_lagartijas` `palabra_serie` `num_1` `palabra_de` `num_3` |
| Anuncio con rango | "De ocho a doce sentadillas. Serie dos de tres." | `palabra_de` `num_8` `palabra_a` `num_12` `ej_sentadillas` `palabra_serie` `num_2` `palabra_de` `num_3` |
| Descanso | "Descanso. Noventa segundos." | `palabra_descanso` `num_90` `palabra_segundos` |
| Aviso de descanso | "Diez segundos." / "Tres, dos, uno" | `num_10` `palabra_segundos` / `num_3` `num_2` `num_1` |
| Ánimo (al azar, ~40 % de las series) | "¡Eso es!" | cualquier `animo_*` |
| Mitad del entrenamiento | "Ya vamos a la mitad." | `animo_mitad` |
| Últimas 2 series | "Estamos a punto de terminar." | `animo_casi_terminamos` |
| Pausa / reanudar | "Pausa." / "Continuamos." | `frase_pausa`, `frase_continuamos` |
| Fin | "¡Terminaste! Excelente trabajo." | `frase_terminaste` |
| Prueba de bocina | "Hola, soy tu entrenador MacroBuddy..." | `frase_hola` |

## Lista de grabación (en orden de prioridad)

### 1. Números (`num_N`)

`num_1` a `num_20`, más `num_25`, `num_30`, `num_40`, `num_45`, `num_50`,
`num_60` y `num_90` (descanso por defecto). Con esos 27 clips se cubren casi
todas las repeticiones y series. Di el número solo, sin entonación de pregunta
("diez").

### 2. Palabras de unión

| Clave | Di |
|---|---|
| `palabra_serie` | "serie" |
| `palabra_de` | "de" |
| `palabra_a` | "a" |
| `palabra_descanso` | "descanso" |
| `palabra_segundos` | "segundos" |

### 3. Frases

| Clave | Di |
|---|---|
| `frase_comenzamos` | "¡Vamos a entrenar!" |
| `frase_primer_ejercicio` | "Primer ejercicio" |
| `frase_siguiente_ejercicio` | "Siguiente ejercicio" |
| `frase_ultimo_ejercicio` | "Último ejercicio" |
| `frase_ultima_serie` | "Última serie" |
| `frase_pausa` | "Pausa" |
| `frase_continuamos` | "Continuamos" |
| `frase_terminaste` | "¡Terminaste! Excelente trabajo" |
| `frase_hola` | "Hola, soy tu entrenador MacroBuddy" |

### 4. Ejercicios (`ej_*`)

El catálogo de ejercicios está en inglés, así que `voces.json` traduce el
nombre del catálogo a la clave del clip y al texto en español:

```json
"ejercicios": {
  "push_up": { "clave": "ej_lagartijas", "texto": "lagartijas" }
}
```

- La llave (`push_up`) es el nombre del ejercicio en el catálogo, en minúsculas,
  sin acentos y con `_` en vez de espacios o símbolos: "Push-Up" → `push_up`,
  "Pull Up (Neutral Grip)" → `pull_up_neutral_grip`.
- `clave` es el nombre del archivo a grabar (`ej_lagartijas.mp3`).
- `texto` es lo que dice el TTS si todavía no grabas el clip.

Si un ejercicio no está en `voces.json`, su clave es `ej_` + el nombre del
catálogo (`ej_cable_curl`) y el TTS dice el nombre tal cual. Varios ejercicios
pueden compartir la misma clave (por ejemplo `squat` y `bodyweight_squat` →
`ej_sentadillas`).

### 5. Ánimos (`animo_*`)

Cualquier archivo que empiece con `animo_` entra al sorteo de ánimos; la app
nunca repite el mismo dos veces seguidas. Sugeridos: `animo_eso_es` ("¡Eso
es!"), `animo_sigue_asi`, `animo_muy_bien`, `animo_vamos` ("¡Vamos, tú
puedes!"). `animo_mitad` y `animo_casi_terminamos` se usan en su momento y no
entran al sorteo.

Mientras no haya ningún `animo_*` grabado, se usan esos mismos textos con TTS,
más los que pongas en `"animos": ["¡Dale!", "..."]` de `voces.json`.

## Otras opciones de `voces.json`

`"clips"` apunta una clave a un archivo con otro nombre, por ejemplo para
probar dos tomas: `"clips": { "animo_eso_es": "eso_es_toma2.m4a" }`.

## Tips de grabación

- Graba con el celular en un cuarto con ropa o cortinas, a unos 20 cm.
- Deja medio segundo de silencio al inicio y al final y recórtalo en Audacity
  (deja ~50 ms para que no suene cortado).
- Exporta en MP3 mono a 64–96 kbps. Cada clip pesa unos 10 KB; el paquete
  completo, menos de 2 MB.
- Normaliza todos a -1 dB (Audacity → Efecto → Normalizar) para que no suenen
  disparejos junto al TTS.
- Mantén el mismo tono y energía en todos: se van a escuchar encadenados.
