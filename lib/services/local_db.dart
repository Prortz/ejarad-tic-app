// lib/services/local_db.dart
// Base de datos embebida (sqflite) para la arquitectura Offline-First:
//  · catalogo_cache          → catálogo de precios para estimar sin red
//  · evidencias_pendientes   → trazabilidad (GPS, QR/serie, observaciones, ruta de foto)
//                              con estado 'Pendiente' | 'Sincronizado'
// Las llaves primarias son UUID v4 generados en el cliente (sin colisiones al sincronizar).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class EvidenciaLocal {
  final String id; // UUID v4
  final String proyectoId;
  final String hitoId;
  final String rutaFoto;
  final String? comentario;
  final double? latitud;
  final double? longitud;
  final double? precisionM;
  final String? numeroSerie;
  final String? qrPayload;
  final DateTime capturadoEn;
  final String registradoPor;
  final String estado; // Pendiente | Sincronizado
  final int intentos;
  final String? ultimoError;

  EvidenciaLocal({
    required this.id,
    required this.proyectoId,
    required this.hitoId,
    required this.rutaFoto,
    this.comentario,
    this.latitud,
    this.longitud,
    this.precisionM,
    this.numeroSerie,
    this.qrPayload,
    required this.capturadoEn,
    required this.registradoPor,
    this.estado = 'Pendiente',
    this.intentos = 0,
    this.ultimoError,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'proyecto_id': proyectoId,
        'hito_id': hitoId,
        'ruta_foto': rutaFoto,
        'comentario': comentario,
        'latitud': latitud,
        'longitud': longitud,
        'precision_m': precisionM,
        'numero_serie': numeroSerie,
        'qr_payload': qrPayload,
        'capturado_en': capturadoEn.toUtc().toIso8601String(),
        'registrado_por': registradoPor,
        'estado': estado,
        'intentos': intentos,
        'ultimo_error': ultimoError,
      };

  factory EvidenciaLocal.fromMap(Map<String, Object?> m) => EvidenciaLocal(
        id: m['id'] as String,
        proyectoId: m['proyecto_id'] as String,
        hitoId: m['hito_id'] as String,
        rutaFoto: (m['ruta_foto'] as String?) ?? '',
        comentario: m['comentario'] as String?,
        latitud: (m['latitud'] as num?)?.toDouble(),
        longitud: (m['longitud'] as num?)?.toDouble(),
        precisionM: (m['precision_m'] as num?)?.toDouble(),
        numeroSerie: m['numero_serie'] as String?,
        qrPayload: m['qr_payload'] as String?,
        capturadoEn: DateTime.parse(m['capturado_en'] as String),
        registradoPor: m['registrado_por'] as String,
        estado: (m['estado'] as String?) ?? 'Pendiente',
        intentos: (m['intentos'] as int?) ?? 0,
        ultimoError: m['ultimo_error'] as String?,
      );
}

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  /// sqflite solo existe en móvil/macOS. En web/Windows/Linux la app sigue
  /// funcionando en modo online (sin persistencia local).
  static bool get soportado =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'ejarad_offline.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE catalogo_cache (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE evidencias_pendientes (
            id TEXT PRIMARY KEY,
            proyecto_id TEXT NOT NULL,
            hito_id TEXT NOT NULL,
            ruta_foto TEXT,
            comentario TEXT,
            latitud REAL,
            longitud REAL,
            precision_m REAL,
            numero_serie TEXT,
            qr_payload TEXT,
            capturado_en TEXT NOT NULL,
            registrado_por TEXT NOT NULL,
            estado TEXT NOT NULL DEFAULT 'Pendiente',
            intentos INTEGER NOT NULL DEFAULT 0,
            ultimo_error TEXT
          )''');
        await db.execute(
            'CREATE INDEX idx_evid_estado ON evidencias_pendientes(estado)');
      },
    );
    return _db!;
  }

  // ───────────────────────── Catálogo ─────────────────────────

  Future<void> guardarCatalogo(List<Map<String, dynamic>> items) async {
    if (!soportado) return;
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('catalogo_cache');
      final batch = txn.batch();
      for (final it in items) {
        batch.insert(
            'catalogo_cache',
            {'id': it['id'].toString(), 'data': jsonEncode(it), 'updated_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> leerCatalogo() async {
    if (!soportado) return [];
    final db = await _database;
    final rows = await db.query('catalogo_cache');
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['data'] as String)))
        .toList();
  }

  // ───────────────────────── Evidencias ─────────────────────────

  Future<void> insertarEvidencia(EvidenciaLocal e) async {
    final db = await _database;
    await db.insert('evidencias_pendientes', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<EvidenciaLocal>> pendientes({String? registradoPor}) async {
    if (!soportado) return [];
    final db = await _database;
    final rows = await db.query(
      'evidencias_pendientes',
      where: registradoPor == null
          ? "estado = 'Pendiente'"
          : "estado = 'Pendiente' AND registrado_por = ?",
      whereArgs: registradoPor == null ? null : [registradoPor],
      orderBy: 'capturado_en ASC',
    );
    return rows.map(EvidenciaLocal.fromMap).toList();
  }

  Future<int> contarPendientes({String? registradoPor, String? proyectoId}) async {
    if (!soportado) return 0;
    final db = await _database;
    final where = StringBuffer("estado = 'Pendiente'");
    final args = <Object>[];
    if (registradoPor != null) {
      where.write(' AND registrado_por = ?');
      args.add(registradoPor);
    }
    if (proyectoId != null) {
      where.write(' AND proyecto_id = ?');
      args.add(proyectoId);
    }
    final r = await db.rawQuery(
        'SELECT COUNT(*) c FROM evidencias_pendientes WHERE $where', args);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<List<EvidenciaLocal>> pendientesDeProyecto(String proyectoId) async {
    if (!soportado) return [];
    final db = await _database;
    final rows = await db.query('evidencias_pendientes',
        where: "estado = 'Pendiente' AND proyecto_id = ?",
        whereArgs: [proyectoId],
        orderBy: 'capturado_en ASC');
    return rows.map(EvidenciaLocal.fromMap).toList();
  }

  Future<void> marcarSincronizado(String id) async {
    final db = await _database;
    await db.update(
        'evidencias_pendientes',
        {'estado': 'Sincronizado', 'ruta_foto': '', 'ultimo_error': null},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> registrarFallo(String id, String error) async {
    final db = await _database;
    await db.rawUpdate(
        'UPDATE evidencias_pendientes SET intentos = intentos + 1, ultimo_error = ? WHERE id = ?',
        [error, id]);
  }

  /// Elimina registros ya sincronizados con más de [dias] días.
  Future<void> purgarSincronizados({int dias = 7}) async {
    if (!soportado) return;
    final db = await _database;
    final limite =
        DateTime.now().subtract(Duration(days: dias)).toUtc().toIso8601String();
    await db.delete('evidencias_pendientes',
        where: "estado = 'Sincronizado' AND capturado_en < ?", whereArgs: [limite]);
  }
}
