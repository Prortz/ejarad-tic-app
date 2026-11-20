// lib/services/catalogo_repository.dart
// Catálogo de precios con caché local (SQLite):
//  · Con red  → descarga el catálogo vigente y refresca la caché.
//  · Sin red  → entrega la última copia local para poder estimar sin conexión.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';

class CatalogoResultado {
  final List<Map<String, dynamic>> items;
  final bool desdeCache;
  CatalogoResultado(this.items, this.desdeCache);
}

class CatalogoRepository {
  CatalogoRepository._();
  static final CatalogoRepository instance = CatalogoRepository._();

  List<Map<String, dynamic>>? _memoria;

  /// [soloActivos]: true para estimaciones; false para la pantalla de gestión.
  Future<CatalogoResultado> obtener({bool soloActivos = true}) async {
    try {
      final res = await Supabase.instance.client
          .from('catalogo_precios')
          .select('*')
          .order('categoria', ascending: true)
          .order('descripcion', ascending: true);
      final todos = List<Map<String, dynamic>>.from(res);
      _memoria = todos;
      try {
        await LocalDb.instance.guardarCatalogo(todos);
      } catch (_) {}
      return CatalogoResultado(_filtrar(todos, soloActivos), false);
    } catch (_) {
      List<Map<String, dynamic>> local = _memoria ?? [];
      if (local.isEmpty) {
        try {
          local = await LocalDb.instance.leerCatalogo();
        } catch (_) {}
      }
      local = [...local]..sort((a, b) =>
          '${a['categoria']}${a['descripcion']}'.compareTo('${b['categoria']}${b['descripcion']}'));
      return CatalogoResultado(_filtrar(local, soloActivos), true);
    }
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> l, bool soloActivos) =>
      soloActivos ? l.where((e) => e['activo'] != false).toList() : l;

  /// Descarga inicial silenciosa (se invoca al iniciar sesión).
  Future<void> precargar() async {
    try {
      await obtener(soloActivos: false);
    } catch (_) {}
  }

  // ─────────────── Emparejamiento BOM ↔ catálogo ───────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');

  static Set<String> _tokens(String s) => _norm(s)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.length > 1)
      .toSet();

  /// Devuelve el insumo del catálogo que mejor coincide con [descripcion]
  /// dentro de [categoria] (o null si la coincidencia es débil).
  ///  · [obligatorios]: palabras que el insumo debe contener todas.
  ///  · [algunoDe]: el insumo debe contener al menos una (p. ej. {'6a', 'cat6a'}).
  ///  · [excluidos]: el insumo no debe contener ninguna.
  static Map<String, dynamic>? buscarMejor(
    List<Map<String, dynamic>> catalogo,
    String descripcion, {
    String? categoria,
    Set<String> obligatorios = const {},
    Set<String> algunoDe = const {},
    Set<String> excluidos = const {},
  }) {
    final buscados = _tokens(descripcion);
    if (buscados.isEmpty) return null;
    Map<String, dynamic>? mejor;
    var mejorPuntaje = 0.0;
    for (final it in catalogo) {
      if (categoria != null && it['categoria'] != categoria) continue;
      final tk = _tokens('${it['descripcion']} ${it['sku']}');
      if (obligatorios.isNotEmpty && !obligatorios.every(tk.contains)) continue;
      if (algunoDe.isNotEmpty && !algunoDe.any(tk.contains)) continue;
      if (excluidos.any(tk.contains)) continue;
      final comunes = buscados.intersection(tk).length;
      if (comunes == 0) continue;
      final puntaje = comunes / buscados.length;
      if (puntaje > mejorPuntaje) {
        mejorPuntaje = puntaje;
        mejor = it;
      }
    }
    return mejorPuntaje >= 0.5 ? mejor : null;
  }

  /// Búsqueda por SKU / código leído desde un QR (coincidencia exacta o contenida).
  static Map<String, dynamic>? buscarPorSku(
      List<Map<String, dynamic>> catalogo, String payload) {
    final p = payload.trim().toLowerCase();
    if (p.isEmpty) return null;
    for (final it in catalogo) {
      final sku = '${it['sku'] ?? ''}'.trim().toLowerCase();
      if (sku.isNotEmpty && (p == sku || p.contains(sku))) return it;
    }
    return null;
  }
}

extension CatalogoItemMapExt on Map<String, dynamic> {
  String get descripcion => (this['descripcion'] ?? '').toString();
  String get unidadMedida =>
      (this['unidad_medida'] ?? this['unidad'] ?? 'und').toString();
  double get precioVentaDefault {
    final v = this['precio_venta_default'] ?? this['precio_unitario'];
    return (v is num ? v.toDouble() : double.tryParse('$v')) ?? 0.0;
  }
  double get costoBase {
    final v = this['costo_base'];
    return (v is num ? v.toDouble() : double.tryParse('$v')) ?? 0.0;
  }
  String get id => (this['id'] ?? '').toString();
  String get sku => (this['sku'] ?? '').toString();
  String get categoria => (this['categoria'] ?? 'otros').toString();
  bool get activo => this['activo'] != false;
}
