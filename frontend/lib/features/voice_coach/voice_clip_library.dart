import 'dart:convert';

import 'package:flutter/services.dart';

/// Biblioteca de clips de voz grabados (la voz del entrenador).
///
/// Los clips viven en `Assets/voces/` como archivos sueltos. Un clip se
/// encuentra por su clave, que es el nombre del archivo sin extensión:
/// `Assets/voces/num_10.mp3` es la clave `num_10`. No hace falta registrarlo
/// en ningún lado: basta con copiar el archivo y recompilar la app.
///
/// `Assets/voces/voces.json` es opcional y sirve para:
///  - `clips`: apuntar una clave a otro archivo (`"animo_eso_es": "eso_es_v2.m4a"`).
///  - `ejercicios`: traducir el nombre del catálogo (en inglés) a la clave y al
///    texto en español: `"push_up": {"clave": "ej_lagartijas", "texto": "lagartijas"}`.
///  - `animos`: textos de ánimo de respaldo para TTS.
///
/// Si un clip no existe, quien llama usa TTS para ese pedazo. Con cero clips la
/// app funciona igual, solo con la voz del teléfono.
class VoiceClipLibrary {
  VoiceClipLibrary._(this._clips, this._exercises, this._encouragements);

  static const String folder = 'Assets/voces/';
  static const String manifestPath = '${folder}voces.json';
  static const Set<String> _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
  };

  /// Biblioteca vacía: todo se dice con TTS.
  static final VoiceClipLibrary empty = VoiceClipLibrary._({}, {}, const []);

  static Future<VoiceClipLibrary>? _loading;

  /// Carga (una sola vez) los clips empaquetados con la app.
  static Future<VoiceClipLibrary> load({AssetBundle? bundle}) {
    return _loading ??= _load(bundle ?? rootBundle);
  }

  static Future<VoiceClipLibrary> _load(AssetBundle bundle) async {
    final clips = <String, String>{};
    final exercises = <String, ExerciseVoice>{};
    var encouragements = <String>[];

    // 1) Descubre los archivos de audio dentro de Assets/voces/.
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith(folder)) continue;
        final file = asset.substring(folder.length);
        if (file.contains('/')) continue;
        final dot = file.lastIndexOf('.');
        if (dot <= 0) continue;
        final ext = file.substring(dot).toLowerCase();
        if (!_audioExtensions.contains(ext)) continue;
        clips[file.substring(0, dot)] = asset;
      }
    } catch (_) {
      // Sin manifest de assets (tests, plataforma rara): seguimos con TTS.
    }

    // 2) Aplica voces.json (opcional).
    try {
      final raw = await bundle.loadString(manifestPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final overrides = json['clips'] as Map<String, dynamic>? ?? const {};
      for (final entry in overrides.entries) {
        final file = entry.value;
        if (file is! String || file.isEmpty) continue;
        final path = file.startsWith('Assets/') ? file : '$folder$file';
        // Solo si el archivo existe; si no, que caiga a TTS.
        if (clips.containsValue(path) || await _exists(bundle, path)) {
          clips[entry.key] = path;
        }
      }

      final ex = json['ejercicios'] as Map<String, dynamic>? ?? const {};
      for (final entry in ex.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          exercises[slugify(entry.key)] = ExerciseVoice(
            key: value['clave'] as String? ?? 'ej_${slugify(entry.key)}',
            text: value['texto'] as String? ?? entry.key,
          );
        } else if (value is String) {
          // Forma corta: "push_up": "lagartijas"
          exercises[slugify(entry.key)] = ExerciseVoice(
            key: 'ej_${slugify(value)}',
            text: value,
          );
        }
      }

      encouragements = (json['animos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
    } catch (_) {
      // voces.json no existe o tiene un error: se ignora.
    }

    return VoiceClipLibrary._(clips, exercises, encouragements);
  }

  static Future<bool> _exists(AssetBundle bundle, String path) async {
    try {
      await bundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  final Map<String, String> _clips;
  final Map<String, ExerciseVoice> _exercises;
  final List<String> _encouragements;

  /// Número de clips disponibles.
  int get count => _clips.length;

  /// Todas las claves disponibles, ordenadas.
  List<String> get keys => _clips.keys.toList()..sort();

  bool has(String key) => _clips.containsKey(key);

  /// Ruta del asset para [key], o `null` si no se grabó.
  String? assetFor(String key) => _clips[key];

  /// Claves disponibles que empiezan con [prefix] (p. ej. `animo_`).
  List<String> keysWithPrefix(String prefix) =>
      _clips.keys.where((k) => k.startsWith(prefix)).toList()..sort();

  /// Textos de ánimo extra definidos en voces.json.
  List<String> get encouragementTexts => _encouragements;

  /// Clave y texto en español para un ejercicio del catálogo.
  ExerciseVoice exerciseVoice(String exerciseName) {
    final slug = slugify(exerciseName);
    return _exercises[slug] ?? ExerciseVoice(key: 'ej_$slug', text: exerciseName);
  }

  /// Convierte un texto en clave: minúsculas, sin acentos, `_` entre palabras.
  /// `"Push-Up (Wide)"` -> `push_up_wide`.
  static String slugify(String input) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      var ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      if (i >= 0) ch = to[i];
      final isAlnum = RegExp(r'[a-z0-9]').hasMatch(ch);
      buffer.write(isAlnum ? ch : '_');
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

/// Cómo se dice un ejercicio: clave del clip y texto de respaldo para TTS.
class ExerciseVoice {
  const ExerciseVoice({required this.key, required this.text});

  final String key;
  final String text;
}
