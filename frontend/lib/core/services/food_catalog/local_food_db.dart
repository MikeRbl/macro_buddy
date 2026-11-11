import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'food_models.dart';
import 'food_text.dart';

/// Dos bases SQLite en el teléfono:
///
/// - `food_catalog.db`: copia del catálogo verificado. Viene dentro de la
///   app (Assets/catalog/) y se actualiza con deltas del servidor. Se puede
///   reemplazar completa sin perder nada del usuario.
/// - `user_foods.db`: productos creados por el usuario. Nunca se reemplaza.
class LocalFoodDb {
  LocalFoodDb({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// Debe coincidir con `SCHEMA_VERSION` en backend/scripts/export-catalog.ts.
  static const catalogSchemaVersion = 1;
  static const _catalogAsset = 'Assets/catalog/food_catalog.db';
  static const _catalogInfoAsset = 'Assets/catalog/food_catalog.json';

  final AssetBundle _bundle;
  Database? _catalog;
  Database? _user;
  Future<void>? _opening;

  Future<void> open() => _opening ??= _open();

  Future<Database> get catalog async {
    await open();
    return _catalog!;
  }

  Future<Database> get user async {
    await open();
    return _user!;
  }

  Future<void> _open() async {
    final dir = await getDatabasesPath();
    final catalogPath = p.join(dir, 'food_catalog.db');
    await _installBundledCatalogIfNewer(catalogPath);
    _catalog = await openDatabase(catalogPath);
    await _ensureCatalogSchema(_catalog!);

    _user = await openDatabase(
      p.join(dir, 'user_foods.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE user_foods (
            local_id TEXT PRIMARY KEY,
            barcode TEXT,
            name TEXT NOT NULL,
            brand TEXT,
            search_text TEXT NOT NULL,
            kcal REAL NOT NULL,
            protein REAL NOT NULL,
            carbs REAL NOT NULL,
            fat REAL NOT NULL,
            base_unit TEXT NOT NULL DEFAULT 'g',
            serving_g REAL,
            serving_label TEXT,
            contribution_status TEXT NOT NULL DEFAULT 'local',
            contribution_id TEXT,
            reviewer_note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        await db.execute(
          'CREATE UNIQUE INDEX user_foods_barcode ON user_foods(barcode) '
          'WHERE barcode IS NOT NULL',
        );
      },
    );
  }

  // ── Catálogo ──────────────────────────────────────────────────────────

  /// Copia el catálogo de los assets si no hay uno instalado, si cambió el
  /// esquema, o si el de la app es más nuevo que el ya sincronizado (pasa
  /// al actualizar la app con un catálogo recién exportado).
  Future<void> _installBundledCatalogIfNewer(String path) async {
    final info = await _bundledInfo();
    if (info == null) return; // la app se compiló sin catálogo: solo sync.

    final file = File(path);
    if (await file.exists()) {
      final installed = await _installedInfo(path);
      final sameSchema = installed.schema == info.schema;
      if (sameSchema && installed.version >= info.version) return;
    }
    final data = await _bundle.load(_catalogAsset);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  Future<({int version, int schema})?> _bundledInfo() async {
    try {
      final raw = await _bundle.loadString(_catalogInfoAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        version: (json['version'] as num).toInt(),
        schema: (json['schema'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<({int version, int schema})> _installedInfo(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true, singleInstance: false);
      final schema = Sqflite.firstIntValue(
            await db.rawQuery('PRAGMA user_version'),
          ) ??
          0;
      final rows = await db.rawQuery(
        "SELECT value FROM meta WHERE key = 'catalog_version'",
      );
      final version = rows.isEmpty
          ? 0
          : int.tryParse('${rows.first['value']}') ?? 0;
      return (version: version, schema: schema);
    } catch (_) {
      return (version: 0, schema: 0);
    } finally {
      await db?.close();
    }
  }

  /// Si no vino catálogo en los assets se crea vacío (se llena con sync).
  Future<void> _ensureCatalogSchema(Database db) async {
    final schema =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')) ?? 0;
    if (schema == catalogSchemaVersion) return;
    await db.execute('DROP TABLE IF EXISTS foods');
    await db.execute('DROP TABLE IF EXISTS barcodes');
    await db.execute('DROP TABLE IF EXISTS meta');
    await db.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        search_text TEXT NOT NULL,
        kcal REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        base_unit TEXT NOT NULL DEFAULT 'g',
        servings TEXT NOT NULL DEFAULT '[]',
        source TEXT NOT NULL,
        popularity REAL NOT NULL DEFAULT 0,
        version INTEGER NOT NULL
      )''');
    await db.execute(
      'CREATE TABLE barcodes (barcode TEXT PRIMARY KEY, food_id TEXT NOT NULL)',
    );
    await db.execute('CREATE INDEX barcodes_food ON barcodes(food_id)');
    await db.execute('CREATE INDEX foods_popularity ON foods(popularity DESC)');
    await db.execute(
      'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.execute('PRAGMA user_version = $catalogSchemaVersion');
  }

  Future<int> catalogVersion() async {
    final rows = await (await catalog).rawQuery(
      "SELECT value FROM meta WHERE key = 'catalog_version'",
    );
    return rows.isEmpty ? 0 : int.tryParse('${rows.first['value']}') ?? 0;
  }

  Future<CatalogFood?> catalogByBarcode(String barcode) async {
    final rows = await (await catalog).rawQuery(
      'SELECT f.* FROM barcodes b JOIN foods f ON f.id = b.food_id '
      'WHERE b.barcode = ? LIMIT 1',
      [barcode],
    );
    return rows.isEmpty ? null : CatalogFood.fromRow(rows.first, barcode: barcode);
  }

  Future<List<CatalogFood>> searchCatalog(String query, {int limit = 30}) async {
    final where = _likeClause(query);
    if (where == null) return const [];
    final rows = await (await catalog).rawQuery(
      'SELECT f.*, (SELECT barcode FROM barcodes WHERE food_id = f.id LIMIT 1) '
      'AS first_barcode FROM foods f WHERE ${where.sql} '
      // Primero la palabra completa ("pan" → Pan Blanco antes que Panqué),
      // luego lo que empieza igual y al final lo más popular.
      "ORDER BY ((' ' || f.search_text || ' ') LIKE ?) DESC, "
      '(f.search_text LIKE ?) DESC, f.popularity DESC LIMIT ?',
      [...where.args, '% ${where.first} %', '${where.first}%', limit],
    );
    return [
      for (final r in rows)
        CatalogFood.fromRow(r, barcode: r['first_barcode'] as String?),
    ];
  }

  /// Aplica una página de `/api/foods/sync` en una sola transacción.
  /// Devuelve los códigos que llegaron (para marcar contribuciones aprobadas).
  Future<Set<String>> applySyncPage(
    List<Map<String, dynamic>> items,
    int nextSince,
  ) async {
    final codes = <String>{};
    await (await catalog).transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        final id = item['id'] as String;
        batch.delete('barcodes', where: 'food_id = ?', whereArgs: [id]);
        if (item['deleted'] == true) {
          batch.delete('foods', where: 'id = ?', whereArgs: [id]);
          continue;
        }
        _putFood(batch, item);
        codes.addAll(((item['barcodes'] as List?) ?? const []).cast<String>());
      }
      // Sin "ON CONFLICT DO UPDATE": Android < 11 trae SQLite < 3.24.
      batch.rawInsert(
        "INSERT OR IGNORE INTO meta (key, value) VALUES ('catalog_version', '0')",
      );
      batch.rawUpdate(
        "UPDATE meta SET value = ? WHERE key = 'catalog_version' "
        'AND CAST(value AS INTEGER) < ?',
        ['$nextSince', nextSince],
      );
      await batch.commit(noResult: true);
    });
    return codes;
  }

  /// Guarda un alimento que llegó por búsqueda/código del servidor sin
  /// mover `catalog_version` (el sync lo volverá a aplicar sin problema).
  Future<void> cacheFood(Map<String, dynamic> item) async {
    final db = await catalog;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('barcodes', where: 'food_id = ?', whereArgs: [item['id']]);
      _putFood(batch, item);
      await batch.commit(noResult: true);
    });
  }

  void _putFood(Batch batch, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final name = item['name'] as String;
    final brand = item['brand'] as String?;
    batch.insert('foods', {
      'id': id,
      'name': name,
      'brand': brand,
      'search_text': normalizeSearch('$name ${brand ?? ''}'),
      'kcal': (item['kcal'] as num).toDouble(),
      'protein': (item['protein'] as num).toDouble(),
      'carbs': (item['carbs'] as num).toDouble(),
      'fat': (item['fat'] as num).toDouble(),
      'base_unit': item['baseUnit'] ?? 'g',
      'servings': jsonEncode(item['servings'] ?? const []),
      'source': item['source'] ?? 'off',
      'popularity': (item['popularity'] as num?)?.toDouble() ?? 0,
      'version': (item['version'] as num?)?.toInt() ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final code in ((item['barcodes'] as List?) ?? const []).cast<String>()) {
      batch.insert('barcodes', {
        'barcode': code,
        'food_id': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ── Productos del usuario ─────────────────────────────────────────────

  Future<UserFood?> userByBarcode(String barcode) async {
    final rows = await (await user).query(
      'user_foods',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    return rows.isEmpty ? null : UserFood.fromRow(rows.first);
  }

  Future<UserFood?> userById(String localId) async {
    final rows = await (await user).query(
      'user_foods',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : UserFood.fromRow(rows.first);
  }

  Future<List<UserFood>> searchUser(String query, {int limit = 10}) async {
    final where = _likeClause(query, column: 'search_text');
    if (where == null) return const [];
    final rows = await (await user).rawQuery(
      'SELECT * FROM user_foods WHERE ${where.sql} '
      'ORDER BY updated_at DESC LIMIT ?',
      [...where.args, limit],
    );
    return rows.map(UserFood.fromRow).toList();
  }

  Future<List<UserFood>> allUserFoods() async {
    final rows = await (await user).query('user_foods', orderBy: 'name');
    return rows.map(UserFood.fromRow).toList();
  }

  /// Crea o actualiza (por código de barras, o por `localId`).
  Future<UserFood> upsertUser({
    String? localId,
    String? barcode,
    required String name,
    String? brand,
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
    String baseUnit = 'g',
    double? servingG,
    String? servingLabel,
  }) async {
    final db = await user;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = localId != null
        ? await userById(localId)
        : (barcode != null ? await userByBarcode(barcode) : null);
    // Volver a registrar el mismo producto sin cambios no debe borrar el
    // estado de su solicitud. La hoja muestra 1 decimal para la porción,
    // así que al pasar a 100 g el redondeo crece en 5/gramos.
    final tolerance = (servingG != null && servingG > 0 ? 5 / servingG : 0) + 0.05;
    bool same(double a, double b) => (a - b).abs() <= tolerance;
    if (existing != null &&
        existing.name == name &&
        existing.brand == brand &&
        existing.barcode == barcode &&
        same(existing.kcal, kcal) &&
        same(existing.protein, protein) &&
        same(existing.carbs, carbs) &&
        same(existing.fat, fat)) {
      return existing;
    }
    final id = existing?.localId ?? _newLocalId();
    await db.insert('user_foods', {
      'local_id': id,
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'search_text': normalizeSearch('$name ${brand ?? ''}'),
      'kcal': kcal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'base_unit': baseUnit,
      'serving_g': servingG,
      'serving_label': servingLabel,
      // Editar un producto ya enviado lo regresa a "solo local": los datos
      // nuevos no son los que se verificaron.
      'contribution_status': ContributionStatus.local.name,
      'contribution_id': null,
      'reviewer_note': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return (await userById(id))!;
  }

  Future<void> setContribution(
    String localId, {
    required ContributionStatus status,
    String? contributionId,
    String? reviewerNote,
  }) async {
    await (await user).update(
      'user_foods',
      {
        'contribution_status': status.name,
        'contribution_id': ?contributionId,
        'reviewer_note': reviewerNote,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Al llegar del sync un código que el usuario había enviado, su copia
  /// pasa a "aprobada" y desde ahí manda la versión del catálogo.
  Future<void> markApprovedByBarcodes(Set<String> codes) async {
    if (codes.isEmpty) return;
    final db = await user;
    final list = codes.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, min(i + 500, list.length));
      await db.rawUpdate(
        "UPDATE user_foods SET contribution_status = 'approved' "
        "WHERE contribution_status = 'pending' AND barcode IN "
        '(${List.filled(chunk.length, '?').join(',')})',
        chunk,
      );
    }
  }

  Future<void> deleteUserFood(String localId) async {
    await (await user).delete(
      'user_foods',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // ── Utilidades ────────────────────────────────────────────────────────

  /// Cada palabra debe aparecer (AND). `normalizeSearch` ya quitó los
  /// caracteres especiales de LIKE (% y _).
  ({String sql, List<Object> args, String first})? _likeClause(
    String query, {
    String column = 'f.search_text',
  }) {
    final tokens = normalizeSearch(query)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .take(6)
        .toList();
    if (tokens.isEmpty) return null;
    return (
      sql: tokens.map((_) => '$column LIKE ?').join(' AND '),
      args: [for (final t in tokens) '%$t%'],
      first: tokens.first,
    );
  }

  static final _random = Random.secure();

  static String _newLocalId() {
    final rand = List.generate(
      6,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'u${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$rand';
  }
}
