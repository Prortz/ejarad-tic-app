// lib/services/sync_service.dart
// Sincronización asíncrona Store-and-Forward.
//  1. Detecta recuperación de señal (Wi-Fi / 4G / LTE) con connectivity_plus.
//  2. En segundo plano, por cada evidencia 'Pendiente':
//       a) sube la foto a Supabase Storage,
//       b) UPSERT (INSERT … ON CONFLICT DO UPDATE) en PostgreSQL con el UUID v4
//          generado en el cliente  → 0 % de duplicidad,
//       c) marca el registro local como 'Sincronizado'.
//  3. Se conservan los sellos de tiempo in situ (capturado_en).
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'local_db.dart';
import 'location_service.dart';
import 'supabase_service.dart';

class ResultadoSync {
  final Set<String> sincronizados;
  final int fallidos;
  const ResultadoSync(this.sincronizados, this.fallidos);
}

enum EstadoGuardado { sincronizado, pendiente }

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Cantidad de evidencias en estado 'Pendiente' del usuario actual.
  final ValueNotifier<int> pendientes = ValueNotifier(0);
  final ValueNotifier<bool> sincronizando = ValueNotifier(false);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;

  String? get _perfilId => AuthService.instance.perfil?.id;

  /// Inicia la escucha de conectividad (idempotente).
  void iniciar() {
    if (!LocalDb.soportado) return;
    _sub ??= Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((e) => e != ConnectivityResult.none)) sincronizar();
    });
    _timer ??= Timer.periodic(const Duration(seconds: 90), (_) => sincronizar());
    refrescarContador();
    sincronizar();
  }

  Future<void> refrescarContador() async {
    final id = _perfilId;
    if (!LocalDb.soportado || id == null) {
      pendientes.value = 0;
      return;
    }
    try {
      pendientes.value = await LocalDb.instance.contarPendientes(registradoPor: id);
    } catch (_) {}
  }

  Future<ResultadoSync> sincronizar() async {
    final perfilId = _perfilId;
    if (!LocalDb.soportado || perfilId == null || sincronizando.value) {
      return const ResultadoSync({}, 0);
    }
    if (!AuthService.instance.haySesion) return const ResultadoSync({}, 0);

    sincronizando.value = true;
    final ok = <String>{};
    var fallidos = 0;
    try {
      final lista = await LocalDb.instance.pendientes(registradoPor: perfilId);
      final svc = SupabaseService();
      for (final e in lista) {
        try {
          final f = File(e.rutaFoto);
          if (!await f.exists()) {
            await LocalDb.instance.registrarFallo(e.id, 'Archivo de foto no encontrado');
            fallidos++;
            continue;
          }
          await svc.upsertEvidencia(
            id: e.id,
            proyectoId: e.proyectoId,
            hitoId: e.hitoId,
            bytes: await f.readAsBytes(),
            comentario: e.comentario,
            perfilId: e.registradoPor,
            latitud: e.latitud,
            longitud: e.longitud,
            precisionM: e.precisionM,
            numeroSerie: e.numeroSerie,
            qrPayload: e.qrPayload,
            capturadoEn: e.capturadoEn,
          );
          await LocalDb.instance.marcarSincronizado(e.id);
          try {
            await f.delete();
          } catch (_) {}
          ok.add(e.id);
        } catch (err) {
          fallidos++;
          await LocalDb.instance.registrarFallo(e.id, err.toString());
          // Sin red: no tiene sentido seguir intentando el resto.
          final msg = err.toString().toLowerCase();
          if (msg.contains('socket') ||
              msg.contains('network') ||
              msg.contains('connection') ||
              msg.contains('host lookup') ||
              msg.contains('timeout')) {
            break;
          }
        }
      }
      await LocalDb.instance.purgarSincronizados();
    } catch (_) {
      // Nunca propagar: la sincronización es de fondo.
    } finally {
      sincronizando.value = false;
      await refrescarContador();
    }
    return ResultadoSync(ok, fallidos);
  }
}

/// Punto único para registrar evidencias (offline-first).
class EvidenciaRepository {
  EvidenciaRepository._();
  static final EvidenciaRepository instance = EvidenciaRepository._();

  /// Guarda SIEMPRE primero en SQLite (estado 'Pendiente') y luego intenta
  /// sincronizar de inmediato. Si no hay red, queda en cola.
  Future<EstadoGuardado> guardar({
    required String proyectoId,
    required String hitoId,
    required Uint8List bytes,
    String? comentario,
    GpsCaptura? gps,
    String? numeroSerie,
    String? qrPayload,
  }) async {
    final perfilId = AuthService.instance.perfil?.id;
    if (perfilId == null) throw Exception('Sesión no válida. Vuelve a iniciar sesión.');

    final id = const Uuid().v4(); // UUID v4 generado en el cliente
    final cuando = DateTime.now();

    // Plataformas sin SQLite (web/Windows): envío directo.
    if (!LocalDb.soportado) {
      await SupabaseService().upsertEvidencia(
        id: id,
        proyectoId: proyectoId,
        hitoId: hitoId,
        bytes: bytes,
        comentario: comentario,
        perfilId: perfilId,
        latitud: gps?.latitud,
        longitud: gps?.longitud,
        precisionM: gps?.precisionM,
        numeroSerie: numeroSerie,
        qrPayload: qrPayload,
        capturadoEn: cuando,
      );
      return EstadoGuardado.sincronizado;
    }

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'evidencias_pendientes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final archivo = File(p.join(dir.path, '$id.jpg'));
    await archivo.writeAsBytes(bytes, flush: true);

    await LocalDb.instance.insertarEvidencia(EvidenciaLocal(
      id: id,
      proyectoId: proyectoId,
      hitoId: hitoId,
      rutaFoto: archivo.path,
      comentario: (comentario ?? '').trim().isEmpty ? null : comentario!.trim(),
      latitud: gps?.latitud,
      longitud: gps?.longitud,
      precisionM: gps?.precisionM,
      numeroSerie: (numeroSerie ?? '').trim().isEmpty ? null : numeroSerie!.trim(),
      qrPayload: qrPayload,
      capturadoEn: cuando,
      registradoPor: perfilId,
    ));
    await SyncService.instance.refrescarContador();

    final r = await SyncService.instance.sincronizar();
    return r.sincronizados.contains(id)
        ? EstadoGuardado.sincronizado
        : EstadoGuardado.pendiente;
  }
}
