// lib/services/supabase_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class SupabaseService {
  static final instance = SupabaseService();
  final SupabaseClient client = Supabase.instance.client;

  static const bucketEvidencias = 'evidencias-hitos';
  static const bucketActas = 'actas';

  // ═══════════════════════════════════════════════
  // CATÁLOGO DE PRECIOS
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCatalogoMateriales() async {
    final response = await client
        .from('catalogo_precios')
        .select('*')
        .eq('activo', true)
        .order('categoria', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> toggleActivoCatalogo(String id, bool activo) async {
    await client
        .from('catalogo_precios')
        .update({'activo': activo, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Todo el catálogo (activos e inactivos) para la pantalla de gestión.
  Future<List<Map<String, dynamic>>> getCatalogoCompleto() async {
    final res = await client
        .from('catalogo_precios')
        .select('*')
        .order('categoria', ascending: true)
        .order('descripcion', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static const _prefijoSku = {
    'cableado': 'CAB',
    'conectividad': 'CON',
    'gabinete_rack': 'RAC',
    'equipo_activo': 'ACT',
    'canalizacion': 'CAN',
    'mano_obra': 'MO',
    'otros': 'OTR',
  };

  /// SKU único autogenerado (la columna `sku` es obligatoria en BD).
  static String generarSku(String categoria) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return '${_prefijoSku[categoria] ?? 'OTR'}-${ts.substring(ts.length - 7)}';
  }

  Future<void> crearInsumo(Map<String, dynamic> data) async {
    await client.from('catalogo_precios').insert({
      ...data,
      'sku': data['sku'] ?? generarSku('${data['categoria']}'),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> actualizarInsumo(String id, Map<String, dynamic> data) async {
    await client.from('catalogo_precios').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ═══════════════════════════════════════════════
  // CLIENTES y DIRECCIONES
  // ═══════════════════════════════════════════════

  Future<Map<String, dynamic>?> buscarClientePorRuc(String ruc) async {
    final res = await client
        .from('clientes')
        .select('*')
        .eq('ruc_cliente', ruc)
        .maybeSingle();
    return res;
  }

  Future<String> crearOActualizarCliente({
    required String ruc,
    required String razonSocial,
    String? contactoNombre,
    String? telefono,
    String? correo,
    String? direccion,
    String? distrito,
    String? provincia,
    String? referencia,
  }) async {
    final existente = await buscarClientePorRuc(ruc);
    String clienteId;
    if (existente != null) {
      clienteId = existente['id'] as String;
      await client.from('clientes').update({
        'razon_social': razonSocial,
        if (contactoNombre != null) 'contacto_nombre': contactoNombre,
        if (telefono != null) 'telefono': telefono,
        if (correo != null) 'correo': correo,
      }).eq('id', clienteId);
    } else {
      clienteId = await crearCliente(
        ruc: ruc,
        razonSocial: razonSocial,
        contacto: contactoNombre,
        telefono: telefono,
        correo: correo,
      );
    }

    return clienteId;
  }

  /// Sede de la obra para la cotización (direccion_id es obligatorio).
  /// Reutiliza la dirección si el cliente ya la tiene registrada; si no se
  /// indicó dirección, usa la principal del cliente.
  Future<String> resolverDireccion({
    required String clienteId,
    String? direccion,
    String? distrito,
    String? provincia,
    String? referencia,
  }) async {
    final texto = direccion?.trim() ?? '';
    if (texto.isNotEmpty) {
      final existente = await client
          .from('direcciones_clientes')
          .select('id')
          .eq('cliente_id', clienteId)
          .ilike('direccion_especifica', texto)
          .limit(1)
          .maybeSingle();
      if (existente != null) return existente['id'] as String;
      return crearDireccion(
        clienteId: clienteId,
        provincia: (provincia ?? '').isEmpty ? 'Piura' : provincia!,
        distrito: (distrito ?? '').isEmpty ? 'Piura' : distrito!,
        direccionEspecifica: texto,
        referencia: referencia,
      );
    }
    final principal = await client
        .from('direcciones_clientes')
        .select('id')
        .eq('cliente_id', clienteId)
        .order('es_principal', ascending: false)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (principal == null) {
      throw Exception('Ingresa la dirección de la obra: el cliente no tiene sedes registradas.');
    }
    return principal['id'] as String;
  }

  Future<String> crearCliente({
    required String ruc,
    required String razonSocial,
    String? contacto,
    String? telefono,
    String? correo,
  }) async {
    final res = await client
        .from('clientes')
        .insert({
          'ruc_cliente': ruc,
          'razon_social': razonSocial,
          'contacto_nombre': contacto,
          'telefono': telefono,
          'correo': correo,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<String> crearDireccion({
    required String clienteId,
    required String provincia,
    required String distrito,
    required String direccionEspecifica,
    String departamento = 'Piura',
    String? referencia,
  }) async {
    final res = await client
        .from('direcciones_clientes')
        .insert({
          'cliente_id': clienteId,
          'departamento': departamento,
          'provincia': provincia,
          'distrito': distrito,
          'direccion_especifica': direccionEspecifica,
          'referencia': referencia,
          'es_principal': true,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // ═══════════════════════════════════════════════
  // COTIZACIONES
  // ═══════════════════════════════════════════════

  /// Código de respaldo (solo si no hay red / la función RPC no existe).
  static String generarCodigoCotizacion() {
    final now = DateTime.now();
    final seq = (now.millisecondsSinceEpoch % 900 + 100).toString();
    return 'COT-${now.year}-$seq';
  }

  /// Código correlativo único `COT-AAAA-NNN` (ej. COT-2026-001).
  /// 1) RPC atómica `siguiente_codigo_cotizacion` (sin duplicados).
  /// 2) Respaldo: último código del año + 1.
  Future<String> siguienteCodigoCotizacion() async {
    try {
      final r = await client.rpc('siguiente_codigo_cotizacion');
      if (r is String && r.isNotEmpty) return r;
    } catch (_) {}
    try {
      final anio = DateTime.now().year;
      final res = await client
          .from('cotizaciones')
          .select('codigo_cotizacion')
          .like('codigo_cotizacion', 'COT-$anio-%')
          .order('codigo_cotizacion', ascending: false)
          .limit(1);
      var n = 0;
      if (res.isNotEmpty) {
        final partes = '${res.first['codigo_cotizacion']}'.split('-');
        n = int.tryParse(partes.last) ?? 0;
      }
      return 'COT-$anio-${(n + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      return generarCodigoCotizacion();
    }
  }

  Future<String> crearCotizacionConDetalles({
    required Map<String, dynamic> cotizacionHeader,
    required List<Map<String, dynamic>> detallesBOM,
  }) async {
    final resCot = await client
        .from('cotizaciones')
        .insert(cotizacionHeader)
        .select('id')
        .single();
    final String cotizacionId = resCot['id'] as String;

    final detallesConId = detallesBOM
        .map((item) => {...item, 'cotizacion_id': cotizacionId})
        .toList();
    await client.from('cotizacion_detalles').insert(detallesConId);
    return cotizacionId;
  }

  // ═══════════════════════════════════════════════
  // APROBAR → CREAR PROYECTO
  // ═══════════════════════════════════════════════

  Future<String> aprobarYCrearProyecto(
      String cotizacionId, [String? liderId]) async {
    final cotizacion = await client
        .from('cotizaciones')
        .select('*, cotizacion_detalles(*)')
        .eq('id', cotizacionId)
        .single();

    await client
        .from('cotizaciones')
        .update({'estado': 'Aprobada'})
        .eq('id', cotizacionId);

    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final codigoProyecto = 'PRY-${ts.substring(ts.length - 6)}';

    final resProyecto = await client
        .from('proyectos')
        .insert({
          'codigo_proyecto': codigoProyecto,
          'cotizacion_id': cotizacionId,
          'cliente_id': cotizacion['cliente_id'],
          'direccion_id': cotizacion['direccion_id'],
          if (liderId != null) 'lider_id': liderId,
          'nombre_obra':
              'Red ${cotizacion['puntos_totales']} Pts — ${cotizacion['categoria_cable']}',
          'estado': 'En Proceso',
          if (cotizacion['latitud_nodo'] != null)
            'latitud_nodo': cotizacion['latitud_nodo'],
          if (cotizacion['longitud_nodo'] != null)
            'longitud_nodo': cotizacion['longitud_nodo'],
        })
        .select('id')
        .single();

    final String proyectoId = resProyecto['id'] as String;

    final List detalles = cotizacion['cotizacion_detalles'] as List? ?? [];
    if (detalles.isNotEmpty) {
      final materiales = detalles
          .map((d) => {
                'proyecto_id': proyectoId,
                'item_descripcion': d['descripcion'],
                'unidad': d['unidad'],
                'cantidad_presupuestada': d['cantidad'],
                'cantidad_instalada': 0,
                'es_adicional': false,
              })
          .toList();
      await client.from('proyecto_materiales').insert(materiales);
    }

    await client.from('hitos_proyecto').insert([
      {'proyecto_id': proyectoId, 'fase': '1_Tendido_Canalizacion', 'nombre_fase': 'Hito 1: Tendido y Canalización', 'orden': 1},
      {'proyecto_id': proyectoId, 'fase': '2_Terminacion_Conectorizado', 'nombre_fase': 'Hito 2: Terminación y Conectorizado', 'orden': 2},
      {'proyecto_id': proyectoId, 'fase': '3_Montaje_Organizacion_Rack', 'nombre_fase': 'Hito 3: Montaje y Organización de Rack', 'orden': 3},
      {'proyecto_id': proyectoId, 'fase': '4_Pruebas_Certificacion', 'nombre_fase': 'Hito 4: Pruebas de Continuidad y Certificación', 'orden': 4},
    ]);

    return proyectoId;
  }

  Future<void> cambiarEstadoProyecto(String proyectoId, String nuevoEstado) async {
    await client.from('proyectos').update({'estado': nuevoEstado}).eq('id', proyectoId);
  }

  // ═══════════════════════════════════════════════
  // EVIDENCIAS FOTOGRÁFICAS
  // ═══════════════════════════════════════════════

  /// Sube la foto y hace UPSERT de la evidencia usando el UUID v4 generado en
  /// el cliente (`id`). La ruta en Storage es determinística (`<id>.jpg`) y se
  /// sube con `upsert: true`, por lo que reintentar NUNCA duplica registros.
  /// Preserva el sello de tiempo in situ (`capturado_en`).
  Future<void> upsertEvidencia({
    required String id,
    required String proyectoId,
    required String hitoId,
    required Uint8List bytes,
    String? comentario,
    required String perfilId,
    double? latitud,
    double? longitud,
    double? precisionM,
    String? numeroSerie,
    String? qrPayload,
    DateTime? capturadoEn,
  }) async {
    final path = 'proyectos/$proyectoId/$hitoId/$id.jpg';

    await client.storage.from(bucketEvidencias).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final fotoUrl = client.storage.from(bucketEvidencias).getPublicUrl(path);
    final cuando = (capturadoEn ?? DateTime.now()).toUtc().toIso8601String();

    // UPSERT  ==  INSERT ... ON CONFLICT (id) DO UPDATE
    await client.from('evidencias_proyecto').upsert({
      'id': id,
      'hito_id': hitoId,
      'foto_url': fotoUrl,
      'comentario': (comentario ?? '').trim().isEmpty ? null : comentario!.trim(),
      'registrado_por': perfilId,
      'latitud': latitud,
      'longitud': longitud,
      'precision_m': precisionM,
      'numero_serie': (numeroSerie ?? '').trim().isEmpty ? null : numeroSerie!.trim(),
      'qr_payload': qrPayload,
      'capturado_en': cuando,
      'created_at': cuando,
    }, onConflict: 'id');

    // Completa el hito (solo si estaba pendiente)
    await client
        .from('hitos_proyecto')
        .update({
          'completado': true,
          'fecha_completado': cuando,
          'completado_por': perfilId,
        })
        .eq('id', hitoId)
        .eq('completado', false);

    // Si se había cerrado "sin evidencia", ahora ya tiene evidencia
    await client
        .from('hitos_proyecto')
        .update({'completado_sin_evidencia': false, 'motivo_sin_evidencia': null})
        .eq('id', hitoId)
        .eq('completado_sin_evidencia', true);
  }

  /// Evidencias de todo el proyecto (con hito) para trazabilidad / acta.
  Future<List<Map<String, dynamic>>> getEvidenciasProyecto(String proyectoId) async {
    final res = await client
        .from('hitos_proyecto')
        .select('id, nombre_fase, orden, evidencias_proyecto(*)')
        .eq('proyecto_id', proyectoId)
        .order('orden', ascending: true);
    final out = <Map<String, dynamic>>[];
    for (final h in List<Map<String, dynamic>>.from(res)) {
      for (final e in List<Map<String, dynamic>>.from(h['evidencias_proyecto'] ?? [])) {
        out.add({...e, 'hito_nombre': h['nombre_fase']});
      }
    }
    return out;
  }



  Future<List<Map<String, dynamic>>> getEvidenciasHito(String hitoId) async {
    final res = await client
        .from('evidencias_proyecto')
        .select('*')
        .eq('hito_id', hitoId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> eliminarEvidencia(Map<String, dynamic> evidencia) async {
    final url = evidencia['foto_url']?.toString() ?? '';
    const marker = '/object/public/$bucketEvidencias/';
    final i = url.indexOf(marker);
    if (i >= 0) {
      final path = Uri.decodeComponent(url.substring(i + marker.length));
      try {
        await client.storage.from(bucketEvidencias).remove([path]);
      } catch (_) {}
    }
    await client.from('evidencias_proyecto').delete().eq('id', evidencia['id']);
  }

  // ═══════════════════════════════════════════════
  // HITOS
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getHitosConEvidencias(
      String proyectoId) async {
    final res = await client
        .from('hitos_proyecto')
        .select('*, evidencias_proyecto(*)')
        .eq('proyecto_id', proyectoId)
        .order('orden', ascending: true);
    final hitos = List<Map<String, dynamic>>.from(res);
    for (final h in hitos) {
      final ev = List<Map<String, dynamic>>.from(h['evidencias_proyecto'] ?? []);
      ev.sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
      h['evidencias_proyecto'] = ev;
    }
    return hitos;
  }

  Future<void> completarHitoSinEvidencia({
    required String hitoId,
    String? perfilId,
    String? motivo,
  }) async {
    await client.from('hitos_proyecto').update({
      'completado': true,
      'completado_sin_evidencia': true,
      'motivo_sin_evidencia': (motivo ?? '').trim().isEmpty ? null : motivo!.trim(),
      'fecha_completado': DateTime.now().toIso8601String(),
      if (perfilId != null) 'completado_por': perfilId,
    }).eq('id', hitoId);
  }

  Future<void> reabrirHito(String hitoId) async {
    await client.from('hitos_proyecto').update({
      'completado': false,
      'completado_sin_evidencia': false,
      'motivo_sin_evidencia': null,
      'fecha_completado': null,
      'completado_por': null,
    }).eq('id', hitoId);
  }

  // ═══════════════════════════════════════════════
  // EQUIPO DEL PROYECTO
  // ═══════════════════════════════════════════════

  /// Equipo del proyecto. Los datos del personal se leen de la vista
  /// `perfiles_publico` (sin DNI) para respetar el Privilegio Mínimo (Ley 29733).
  /// Si la vista aún no existe, se usa `perfiles` como respaldo.
  Future<List<Map<String, dynamic>>> getEquipoProyecto(String proyectoId) async {
    final res = await client
        .from('proyecto_equipo')
        .select('*')
        .eq('proyecto_id', proyectoId)
        .order('created_at', ascending: true);
    final list = List<Map<String, dynamic>>.from(res);
    final ids = list.map((e) => e['perfil_id'].toString()).toList();
    final perfiles = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      List<dynamic> rows;
      try {
        rows = await client.from('perfiles_publico').select('*').inFilter('id', ids);
      } catch (_) {
        rows = await client.from('perfiles').select('*').inFilter('id', ids);
      }
      for (final r in rows) {
        perfiles[r['id'].toString()] = Map<String, dynamic>.from(r as Map);
      }
    }
    for (final e in list) {
      e['perfiles'] = perfiles[e['perfil_id'].toString()] ??
          {'id': e['perfil_id'], 'nombre': 'Usuario', 'cargo': 'Técnico'};
    }
    // Líder primero
    list.sort((a, b) => (a['rol_en_proyecto'] == 'Líder' ? 0 : 1)
        .compareTo(b['rol_en_proyecto'] == 'Líder' ? 0 : 1));
    return list;
  }

  Future<void> agregarMiembroEquipo({
    required String proyectoId,
    required String perfilId,
    String rol = 'Técnico',
  }) async {
    if (rol == 'Líder') await _degradarLideres(proyectoId);
    await client.from('proyecto_equipo').upsert({
      'proyecto_id': proyectoId,
      'perfil_id': perfilId,
      'rol_en_proyecto': rol,
    }, onConflict: 'proyecto_id,perfil_id');
    if (rol == 'Líder') {
      await client.from('proyectos').update({'lider_id': perfilId}).eq('id', proyectoId);
    }
  }

  Future<void> cambiarRolMiembro({
    required String miembroId,
    required String proyectoId,
    required String perfilId,
    required String rol,
  }) async {
    if (rol == 'Líder') await _degradarLideres(proyectoId);
    await client.from('proyecto_equipo').update({'rol_en_proyecto': rol}).eq('id', miembroId);
    if (rol == 'Líder') {
      await client.from('proyectos').update({'lider_id': perfilId}).eq('id', proyectoId);
    } else {
      await client.from('proyectos').update({'lider_id': null})
          .eq('id', proyectoId).eq('lider_id', perfilId);
    }
  }

  Future<void> quitarMiembroEquipo({
    required String miembroId,
    required String proyectoId,
    required String perfilId,
  }) async {
    await client.from('proyecto_equipo').delete().eq('id', miembroId);
    await client.from('proyectos').update({'lider_id': null})
        .eq('id', proyectoId).eq('lider_id', perfilId);
  }

  Future<void> _degradarLideres(String proyectoId) async {
    await client
        .from('proyecto_equipo')
        .update({'rol_en_proyecto': 'Técnico'})
        .eq('proyecto_id', proyectoId)
        .eq('rol_en_proyecto', 'Líder');
  }

  // ═══════════════════════════════════════════════
  // ACTAS DE CONFORMIDAD / CIERRE
  // ═══════════════════════════════════════════════

  Future<Map<String, dynamic>> getProyectoCompleto(String proyectoId) async {
    final res = await client
        .from('proyectos')
        .select('*, clientes(*), direcciones_clientes(*)')
        .eq('id', proyectoId)
        .single();
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>?> getActaProyecto(String proyectoId) async {
    return await client
        .from('actas_conformidad')
        .select('*')
        .eq('proyecto_id', proyectoId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getActas() async {
    final res = await client
        .from('actas_conformidad')
        .select('*')
        .order('fecha_cierre', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Sube firma + PDF, registra el acta y marca el proyecto como Completado.
  Future<Map<String, dynamic>> registrarActaYCerrarProyecto({
    required Map<String, dynamic> proyecto,
    required String codigoActa,
    required Uint8List pdfBytes,
    required Uint8List firmaPng,
    required String firmanteNombre,
    String? firmanteDocumento,
    String? firmanteCargo,
    String? observaciones,
    required List<Map<String, dynamic>> equipoSnapshot,
    required DateTime fechaCierre,
    String? perfilId,
  }) async {
    final storage = client.storage.from(bucketActas);
    final base = '${proyecto['codigo_proyecto'] ?? proyecto['id']}';
    final firmaPath = '$base/firma_$codigoActa.png';
    final pdfPath = '$base/$codigoActa.pdf';

    await storage.uploadBinary(firmaPath, firmaPng,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: true));
    await storage.uploadBinary(pdfPath, pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
    // El bucket `actas` es PRIVADO (contiene DNI y firmas): solo se guarda la ruta.

    final cliente = proyecto['clientes'] as Map<String, dynamic>?;
    final acta = await client
        .from('actas_conformidad')
        .upsert({
          'codigo_acta': codigoActa,
          'proyecto_id': proyecto['id'],
          'codigo_proyecto': proyecto['codigo_proyecto'],
          'nombre_obra': proyecto['nombre_obra'],
          'cliente_id': proyecto['cliente_id'],
          'cliente_razon_social': cliente?['razon_social'],
          'cliente_ruc': cliente?['ruc_cliente'],
          'firmante_nombre': firmanteNombre,
          'firmante_documento': firmanteDocumento,
          'firmante_cargo': firmanteCargo,
          'observaciones': observaciones,
          'equipo': equipoSnapshot,
          'firma_path': firmaPath,
          'pdf_path': pdfPath,
          'fecha_cierre': fechaCierre.toIso8601String(),
          if (perfilId != null) 'generado_por': perfilId,
        }, onConflict: 'proyecto_id')
        .select()
        .single();

    await client.from('proyectos').update({
      'estado': 'Completado',
      'fecha_cierre_real': fechaCierre.toIso8601String().substring(0, 10),
    }).eq('id', proyecto['id']);

    return Map<String, dynamic>.from(acta);
  }

  Future<Uint8List> descargarActaPdf(String pdfPath) async {
    return await client.storage.from(bucketActas).download(pdfPath);
  }

  // ═══════════════════════════════════════════════
  // PROYECTOS
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getProyectos() async {
    final res = await client
        .from('proyectos')
        .select('*, clientes(razon_social), hitos_proyecto(completado)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Proyectos visibles para el perfil: Admin/Supervisor ven todos; el Técnico
  /// solo las obras donde está asignado (además lo refuerza RLS en BD).
  Future<List<Map<String, dynamic>>> getProyectosParaPerfil(Perfil perfil) async {
    if (perfil.puedeGestionar) return getProyectos();
    final asign = await client
        .from('proyecto_equipo')
        .select('proyecto_id')
        .eq('perfil_id', perfil.id);
    final ids = List<Map<String, dynamic>>.from(asign)
        .map((e) => e['proyecto_id'].toString())
        .toList();
    if (ids.isEmpty) return [];
    final res = await client
        .from('proyectos')
        .select('*, clientes(razon_social), hitos_proyecto(completado)')
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // ═══════════════════════════════════════════════════════
  // MATERIALES / METRADOS INSTALADOS
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getMaterialesProyecto(String proyectoId) async {
    final res = await client
        .from('proyecto_materiales')
        .select('*')
        .eq('proyecto_id', proyectoId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> actualizarCantidadInstalada(String materialId, double cantidad) async {
    await client
        .from('proyecto_materiales')
        .update({'cantidad_instalada': cantidad}).eq('id', materialId);
  }

  // ═══════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCotizacionesResumen() async {
    final res = await client
        .from('cotizaciones')
        .select('id, codigo_cotizacion, estado, precio_total, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// IDs de proyectos que ya tienen acta firmada.
  Future<Set<String>> getProyectosConActa() async {
    final res = await client.from('actas_conformidad').select('proyecto_id');
    return List<Map<String, dynamic>>.from(res)
        .map((e) => e['proyecto_id'].toString())
        .toSet();
  }

  // ═══════════════════════════════════════════════
  // MÓDULO CLIENTES
  // ═══════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getClientes() async {
    final res = await client
        .from('clientes')
        .select('*')
        .order('razon_social', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> getClienteDetalle(String clienteId) async {
    final res = await client
        .from('clientes')
        .select('*')
        .eq('id', clienteId)
        .maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> getProyectosPorCliente(
      String clienteId) async {
    final res = await client
        .from('proyectos')
        .select('codigo_proyecto, nombre_obra, estado, created_at')
        .eq('cliente_id', clienteId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }
}
