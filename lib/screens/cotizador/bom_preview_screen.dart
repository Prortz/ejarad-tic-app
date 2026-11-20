// lib/screens/cotizador/bom_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/engine/tia568_calculator.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/catalogo_repository.dart';
import '../../services/pdf_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';
import '../proyectos/proyectos_list_screen.dart';

// ─── Paleta tech ─────────────────────────────────
const _kBg = Color(0xFF080D1A);
const _kSurface = Color(0xFF111827);
const _kCard = Color(0xFF1A2236);
const _kBlue = Color(0xFF2979FF);
const _kCyan = Color(0xFF00E5FF);
const _kTeal = Color(0xFF00BFA5);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFFF5252);
const _kText = Colors.white;
const _kSub = Color(0xFF8899AA);
const _kDivider = Color(0xFF1E2D45);

// ═══════════════════════════════════════════════
// Modelo de ítem del BOM
// ═══════════════════════════════════════════════
class BomItem {
  String descripcion;
  String unidad;
  double cantidad;
  double precioUnitario;
  bool esPersonalizado;
  String? catalogoId;
  String? sku;

  BomItem({
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    required this.precioUnitario,
    this.esPersonalizado = false,
    this.catalogoId,
    this.sku,
  });

  double get subtotal => cantidad * precioUnitario;
}

// ═══════════════════════════════════════════════
// BomPreviewScreen
// ═══════════════════════════════════════════════
class BomPreviewScreen extends StatefulWidget {
  final ResultadoCalculoTIA568 resultado;
  final ParametrosEntrada params;
  final String categoriaCable;
  final String tipoCanalizacion;
  final String rackSeleccionado;
  final String switchPuertos;
  final bool incluirGabineteIntermedio;
  final String rucCliente;
  final String razonSocial;
  final String contacto;
  final String telefono;
  final String correo;
  final String provincia;
  final String distrito;
  final String direccion;
  final String referencia;
  final String? clienteIdExistente;
  final double? latitudNodo;
  final double? longitudNodo;

  const BomPreviewScreen({
    super.key,
    required this.resultado,
    required this.params,
    required this.categoriaCable,
    required this.tipoCanalizacion,
    required this.rackSeleccionado,
    required this.switchPuertos,
    this.incluirGabineteIntermedio = false,
    required this.rucCliente,
    required this.razonSocial,
    required this.contacto,
    required this.telefono,
    required this.correo,
    required this.provincia,
    required this.distrito,
    required this.direccion,
    required this.referencia,
    this.clienteIdExistente,
    this.latitudNodo,
    this.longitudNodo,
  });

  @override
  State<BomPreviewScreen> createState() => _BomPreviewScreenState();
}

class _BomPreviewScreenState extends State<BomPreviewScreen> {
  final _svc = SupabaseService.instance;
  final _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

  List<BomItem> _items = [];
  double _margen = 30.0;
  double _imprevistosPorcentaje = 5.0; // 5 % por defecto (criterio de la empresa, editable)
  bool _guardando = false;
  bool _cargandoCatalogo = true;
  String? _proximoCodigo;

  @override
  void initState() {
    super.initState();
    _inicializarBOM();
  }

  /// Texto de la categoría del cable elegido (Cat 5e / Cat 6 / Cat 6A).
  String get _catCobre {
    final c = widget.categoriaCable.toLowerCase();
    if (c.contains('6a')) return 'Cat 6A';
    if (c.contains('5e')) return 'Cat 5e';
    return 'Cat 6';
  }

  /// Componente de conectividad de la MISMA categoría que el cable (ANSI/TIA-568.2-E:
  /// la categoría del canal la fija el componente de menor categoría). Si no hay
  /// uno en el catálogo devuelve null y se usa un ítem referencial con precio base.
  Map<String, dynamic>? _componente(
      List<Map<String, dynamic>> catalogo, String busqueda) {
    const otras = {'6a', 'cat6a', '5e', 'cat5e'};
    Map<String, dynamic>? buscar({Set<String> algunoDe = const {}, Set<String> excluidos = const {}}) =>
        CatalogoRepository.buscarMejor(catalogo, busqueda,
            categoria: 'conectividad', algunoDe: algunoDe, excluidos: excluidos);
    switch (_catCobre) {
      case 'Cat 6A':
        return buscar(algunoDe: {'6a', 'cat6a'});
      case 'Cat 5e':
        // Un componente Cat 6 es válido en un enlace Cat 5e (el canal queda en 5e).
        return buscar(algunoDe: {'5e', 'cat5e'}) ?? buscar(excluidos: otras);
      default:
        return buscar(excluidos: otras);
    }
  }

  Future<void> _inicializarBOM() async {
    setState(() => _cargandoCatalogo = true);
    try {
      final res = await CatalogoRepository.instance.obtener(soloActivos: true);
      final catalogo = res.items;

      final r = widget.resultado;
      final lista = <BomItem>[];

      // 1. Cable
      // El cable debe ser de la categoría pedida: sin esto "Cat 5e UTP" tomaba
      // el cable Cat 6 del catálogo por coincidir en "cat" y "utp".
      final matchCable = CatalogoRepository.buscarMejor(
        catalogo,
        widget.categoriaCable,
        categoria: 'cableado',
        algunoDe: switch (_catCobre) {
          'Cat 6A' => {'6a', 'cat6a'},
          'Cat 5e' => {'5e', 'cat5e'},
          _ => const <String>{},
        },
        excluidos: _catCobre == 'Cat 6'
            ? const {'6a', 'cat6a', '5e', 'cat5e'}
            : const <String>{},
      );
      lista.add(BomItem(
        descripcion: matchCable?.descripcion ??
            'Cable ${widget.categoriaCable} — Bobina 305m',
        unidad: matchCable?.unidadMedida ?? 'Caja',
        cantidad: r.bobinasRequeridas.toDouble(),
        precioUnitario: matchCable?.precioVentaDefault ?? 120.0,
        catalogoId: matchCable?.id,
        sku: matchCable?.sku,
      ));

      // 2. Jacks RJ-45
      final matchJack = _componente(catalogo, 'Jack RJ45 Keystone');
      lista.add(BomItem(
        descripcion: matchJack?.descripcion ?? 'Jack RJ45 Keystone $_catCobre',
        unidad: matchJack?.unidadMedida ?? 'und',
        cantidad: r.jacksRequeridos.toDouble(),
        precioUnitario: matchJack?.precioVentaDefault ?? 4.50,
        catalogoId: matchJack?.id,
        sku: matchJack?.sku,
      ));

      // 3. Patch Cords
      final matchPatch = _componente(catalogo, 'Patch Cord');
      lista.add(BomItem(
        descripcion: matchPatch?.descripcion ?? 'Patch Cord $_catCobre 1.0m',
        unidad: matchPatch?.unidadMedida ?? 'und',
        cantidad: r.patchCordsRequeridos.toDouble(),
        precioUnitario: matchPatch?.precioVentaDefault ?? 6.00,
        catalogoId: matchPatch?.id,
        sku: matchPatch?.sku,
      ));

      // 4. Patch Panels
      if (r.patchPanels24p > 0) {
        final matchPP24 = _componente(catalogo, 'Patch Panel 24');
        lista.add(BomItem(
          descripcion: matchPP24?.descripcion ??
              'Patch Panel Modular 24 Puertos $_catCobre',
          unidad: matchPP24?.unidadMedida ?? 'und',
          cantidad: r.patchPanels24p.toDouble(),
          precioUnitario: matchPP24?.precioVentaDefault ?? 85.00,
          catalogoId: matchPP24?.id,
          sku: matchPP24?.sku,
        ));
      }

      if (r.patchPanels48p > 0) {
        final matchPP48 = _componente(catalogo, 'Patch Panel 48');
        lista.add(BomItem(
          descripcion: matchPP48?.descripcion ??
              'Patch Panel Modular 48 Puertos $_catCobre',
          unidad: matchPP48?.unidadMedida ?? 'und',
          cantidad: r.patchPanels48p.toDouble(),
          precioUnitario: matchPP48?.precioVentaDefault ?? 150.00,
          catalogoId: matchPP48?.id,
          sku: matchPP48?.sku,
        ));
      }

      // 5. Organizadores Horizontales
      if (r.organizadoresRequeridos > 0) {
        final matchOrg = CatalogoRepository.buscarMejor(
          catalogo,
          'Organizador',
          categoria: 'conectividad',
        );
        lista.add(BomItem(
          descripcion:
              matchOrg?.descripcion ?? 'Organizador de Cables Horizontal 1U',
          unidad: matchOrg?.unidadMedida ?? 'und',
          cantidad: r.organizadoresRequeridos.toDouble(),
          precioUnitario: matchOrg?.precioVentaDefault ?? 35.00,
          catalogoId: matchOrg?.id,
          sku: matchOrg?.sku,
        ));
      }

      // 6. Rack Principal
      final matchRack = CatalogoRepository.buscarMejor(
        catalogo,
        widget.rackSeleccionado,
        categoria: 'gabinete_rack',
      );
      lista.add(BomItem(
        descripcion: matchRack?.descripcion ?? widget.rackSeleccionado,
        unidad: matchRack?.unidadMedida ?? 'und',
        cantidad: 1.0,
        precioUnitario: matchRack?.precioVentaDefault ?? 180.00,
        catalogoId: matchRack?.id,
        sku: matchRack?.sku,
      ));

      // 7. Gabinete Intermedio adicional sugerido si distancia > 90m
      if (widget.incluirGabineteIntermedio) {
        final matchIdf = CatalogoRepository.buscarMejor(
          catalogo,
          'Mural 6U',
          categoria: 'gabinete_rack',
        );
        lista.add(BomItem(
          descripcion: matchIdf?.descripcion ??
              'Gabinete Intermedio (IDF) Mural 6U para enlace >90m',
          unidad: matchIdf?.unidadMedida ?? 'und',
          cantidad: 1.0,
          precioUnitario: matchIdf?.precioVentaDefault ?? 140.00,
          catalogoId: matchIdf?.id,
          sku: matchIdf?.sku,
        ));
      }

      // 8. Switch Activo
      final matchSwitch = CatalogoRepository.buscarMejor(
        catalogo,
        widget.switchPuertos,
        categoria: 'equipo_activo',
      );
      lista.add(BomItem(
        descripcion:
            matchSwitch?.descripcion ?? 'Switch ${widget.switchPuertos}',
        unidad: matchSwitch?.unidadMedida ?? 'und',
        cantidad: r.switchesRequeridos.toDouble(),
        precioUnitario: matchSwitch?.precioVentaDefault ?? 350.00,
        catalogoId: matchSwitch?.id,
        sku: matchSwitch?.sku,
      ));

      // 9. Canalización
      final matchCanal = CatalogoRepository.buscarMejor(
        catalogo,
        widget.tipoCanalizacion,
        categoria: 'canalizacion',
      );
      lista.add(BomItem(
        descripcion: matchCanal?.descripcion ??
            'Canalización: ${widget.tipoCanalizacion}',
        unidad: matchCanal?.unidadMedida ?? 'ml',
        cantidad: (r.metradoCableTotal * 0.6).roundToDouble(),
        precioUnitario: matchCanal?.precioVentaDefault ?? 3.50,
        catalogoId: matchCanal?.id,
        sku: matchCanal?.sku,
      ));

      // 10. Mano de Obra
      lista.add(BomItem(
        descripcion: 'Mano de Obra — Cuadrilla Técnica Certificada',
        unidad: 'Global',
        cantidad: 1.0,
        precioUnitario: r.costoManoObraTotal,
        esPersonalizado: false,
      ));

      // El correlativo COT-AAAA-NNN se asigna al GUARDAR: reservarlo al abrir
      // esta pantalla dejaba huecos en la numeración.
      if (mounted) {
        setState(() {
          _items = lista;
          _cargandoCatalogo = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  double get _costoMateriales => _items
      .where((i) => !i.descripcion.startsWith('Mano de Obra'))
      .fold(0.0, (s, i) => s + i.subtotal);

  double get _costoManoObra => widget.resultado.costoManoObraTotal;

  double get _costoBaseTotal => _costoMateriales + _costoManoObra;

  double get _imprevistos =>
      _costoBaseTotal * (_imprevistosPorcentaje / 100);

  double get _costoNetoConImprevistos => _costoBaseTotal + _imprevistos;

  double get _margenMonto => _costoNetoConImprevistos * (_margen / 100);

  double get _subtotalConMargen => _costoNetoConImprevistos + _margenMonto;

  double get _igv => _subtotalConMargen * 0.18;

  double get _total => _subtotalConMargen + _igv;

  Future<void> _guardarCotizacion() async {
    // La BD exige distancia_promedio entre 10 y 90 m (enlace permanente ANSI/TIA-568).
    if (TIA568Calculator.excedeLimite(widget.params.distanciaPromedio)) {
      mostrarError(context,
          'No se puede guardar: el enlace supera 90 m. Segmenta con un gabinete intermedio (IDF) y recalcula con la distancia por tramo.');
      return;
    }
    setState(() => _guardando = true);
    try {
      // 1. Resolver o crear cliente
      String clienteId;
      if (widget.clienteIdExistente != null) {
        clienteId = widget.clienteIdExistente!;
      } else {
        clienteId = await _svc.crearOActualizarCliente(
          ruc: widget.rucCliente,
          razonSocial: widget.razonSocial,
          contactoNombre: widget.contacto,
          telefono: widget.telefono,
          correo: widget.correo,
          direccion: widget.direccion,
          distrito: widget.distrito,
          provincia: widget.provincia,
          referencia: widget.referencia,
        );
      }

      final direccionId = await _svc.resolverDireccion(
        clienteId: clienteId,
        direccion: widget.direccion,
        distrito: widget.distrito,
        provincia: widget.provincia,
        referencia: widget.referencia,
      );

      // 2. Correlativo único COT-AAAA-NNN
      final codigoCot =
          _proximoCodigo ?? await _svc.siguienteCodigoCotizacion();
      _proximoCodigo = codigoCot;

      // 3. Header de cotización con desglose completo
      final header = {
        'codigo_cotizacion': codigoCot,
        'cliente_id': clienteId,
        'direccion_id': direccionId,
        'distancia_promedio': widget.params.distanciaPromedio,
        'puntos_totales': widget.params.puntosTotales,
        'categoria_cable': widget.categoriaCable,
        'tipo_canalizacion': widget.tipoCanalizacion,
        'gabinete_rack': widget.rackSeleccionado,
        'switch_puertos': widget.switchPuertos,
        'dias_ejecucion': widget.params.diasEjecucion,
        'tecnicos_cuadrilla': widget.params.tecnicosCuadrilla,
        'metrado_cable_total': widget.resultado.metradoCableTotal,
        'bobinas_requeridas': widget.resultado.bobinasRequeridas,
        'jacks_requeridos': widget.resultado.jacksRequeridos,
        'patch_cords_requeridos': widget.resultado.patchCordsRequeridos,
        'costo_materiales': double.parse(_costoMateriales.toStringAsFixed(2)),
        'costo_mano_obra': double.parse(_costoManoObra.toStringAsFixed(2)),
        'imprevistos_porcentaje': _imprevistosPorcentaje,
        'imprevistos': double.parse(_imprevistos.toStringAsFixed(2)),
        'margen_comercial_porcentaje': _margen,
        'subtotal': double.parse(_subtotalConMargen.toStringAsFixed(2)),
        'igv': double.parse(_igv.toStringAsFixed(2)),
        'precio_total': double.parse(_total.toStringAsFixed(2)),
        'estado': 'Aprobada',
        'latitud_nodo': widget.latitudNodo,
        'longitud_nodo': widget.longitudNodo,
        'creado_por': AuthService.instance.perfil?.id,
      };

      final detalles = _items.map((i) => {
            'descripcion': i.descripcion,
            'unidad': i.unidad,
            'cantidad': i.cantidad,
            'precio_unitario': i.precioUnitario,
            'subtotal': i.subtotal,
            'es_personalizado': i.esPersonalizado,
            if (i.catalogoId != null) 'catalogo_id': i.catalogoId,
          }).toList();

      // 4. Guardado relacional en cotizaciones y cotizacion_detalles
      final cotizacionId = await _svc.crearCotizacionConDetalles(
        cotizacionHeader: header,
        detallesBOM: detalles,
      );

      // 5. Aprobación y generación del proyecto
      await _svc.aprobarYCrearProyecto(cotizacionId);

      if (!mounted) return;
      mostrarOk(
          context, '¡Cotización $codigoCot guardada y obra aperturada con éxito! ✓');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProyectosListScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        mostrarError(context, 'Error al guardar cotización: $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _generarPDF() async {
    try {
      // Antes de guardar no existe correlativo: el PDF sale como proforma.
      final codigo = _proximoCodigo ?? 'PROFORMA';
      await PdfService.generarCotizacion(
        codigoCotizacion: codigo,
        razonSocial: widget.razonSocial,
        ruc: widget.rucCliente,
        direccion: '${widget.distrito}, ${widget.provincia}',
        items: _items.map((i) => {
              'descripcion': i.descripcion,
              'unidad': i.unidad,
              'cantidad': i.cantidad,
              'precio_unitario': i.precioUnitario,
              'subtotal': i.subtotal,
            }).toList(),
        margen: _margen,
        subtotal: _subtotalConMargen,
        igv: _igv,
        total: _total,
        puntosTotales: widget.params.puntosTotales,
        categoriaCable: widget.categoriaCable,
        imprevistos: _imprevistos,
        imprevistosPorcentaje: _imprevistosPorcentaje,
      );
    } catch (e) {
      if (mounted) mostrarError(context, 'Error al generar PDF: $e');
    }
  }

  void _agregarItemManual() {
    final formKey = GlobalKey<FormState>();
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');
    final precCtrl = TextEditingController(text: '10.0');
    String unidad = 'und';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _kDivider),
          ),
          title: Text(
            'Agregar Insumo al BOM',
            style: GoogleFonts.inter(
              color: _kText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppField(
                    label: 'Descripción del Insumo',
                    controller: descCtrl,
                    hint: 'Ej. Canaleta ranurada 40x25',
                    prefixIcon: Icons.edit_note,
                    inputFormatters: [Formatters.texto],
                    validator: (v) {
                      final req = Validators.requerido(v);
                      if (req != null) return req;
                      return Validators.textoMin(3)(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          label: 'Cantidad',
                          controller: cantCtrl,
                          prefixIcon: Icons.numbers,
                          inputFormatters: [Formatters.decimal],
                          validator: Validators.decimal,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kDivider),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: unidad,
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            dropdownColor: _kCard,
                            style: GoogleFonts.inter(
                                color: _kText, fontSize: 13),
                            items: const [
                              DropdownMenuItem(value: 'und', child: Text('und')),
                              DropdownMenuItem(value: 'm', child: Text('m')),
                              DropdownMenuItem(value: 'ml', child: Text('ml')),
                              DropdownMenuItem(value: 'Caja', child: Text('Caja')),
                              DropdownMenuItem(value: 'Global', child: Text('Global')),
                              DropdownMenuItem(value: 'rollo', child: Text('rollo')),
                            ],
                            onChanged: (v) => setDState(() => unidad = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppField(
                    label: 'Precio Unitario (S/.)',
                    controller: precCtrl,
                    prefixIcon: Icons.attach_money,
                    inputFormatters: [Formatters.decimal],
                    validator: Validators.decimal,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.inter(color: _kSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final c = double.tryParse(cantCtrl.text.trim()) ?? 1.0;
                final p = double.tryParse(precCtrl.text.trim()) ?? 0.0;
                setState(() {
                  _items.add(BomItem(
                    descripcion: descCtrl.text.trim(),
                    unidad: unidad,
                    cantidad: c,
                    precioUnitario: p,
                    esPersonalizado: true,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _editarCantidadItem(int index) {
    final item = _items[index];
    final ctrl = TextEditingController(
      text: item.cantidad % 1 == 0
          ? item.cantidad.toInt().toString()
          : item.cantidad.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kDivider),
        ),
        title: Text(
          'Modificar Cantidad',
          style: GoogleFonts.inter(
              color: _kText, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.descripcion,
                style: GoogleFonts.inter(color: _kCyan, fontSize: 13),
              ),
              const SizedBox(height: 12),
              AppField(
                label: 'Cantidad (${item.unidad})',
                controller: ctrl,
                prefixIcon: Icons.straighten,
                inputFormatters: [Formatters.decimal],
                validator: Validators.decimal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _kSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nueva = double.tryParse(ctrl.text.trim()) ?? item.cantidad;
              setState(() => item.cantidad = nueva);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: _kBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presupuesto y BOM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                Text(
                    _proximoCodigo != null
                        ? 'Correlativo: $_proximoCodigo'
                        : 'Correlativo: se asigna al guardar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: _kCyan),
                  ),
              ],
            ),
          ),
        ]),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar ítem manual',
            icon: const Icon(Icons.add_circle_outline, color: _kCyan),
            onPressed: _agregarItemManual,
          ),
          IconButton(
            tooltip: 'Generar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: _kTeal),
            onPressed: _generarPDF,
          ),
        ],
      ),
      body: _cargandoCatalogo
          ? const Center(child: CircularProgressIndicator(color: _kCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _clienteCard(),
                const SizedBox(height: 16),
                _sectionHeader(
                    'Bill of Materials (BOM ANSI/TIA-568)', Icons.list_alt),
                const SizedBox(height: 10),
                ..._items.asMap().entries.map((e) => _bomItemRow(e.key, e.value)),
                const SizedBox(height: 16),
                _imprevistosYMargenCard(),
                const SizedBox(height: 16),
                _totalesCard(),
                const SizedBox(height: 24),
                _buildBotonAprobar(),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _clienteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.razonSocial.isEmpty ? 'Cliente B2B' : widget.razonSocial,
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.params.puntosTotales} pts',
                  style: GoogleFonts.inter(
                    color: _kCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'RUC/DNI: ${widget.rucCliente}  ·  ${widget.categoriaCable}',
            style: GoogleFonts.inter(color: _kSub, fontSize: 12),
          ),
          Text(
            'Ubicación: ${widget.distrito}, ${widget.provincia} (${widget.direccion})',
            style: GoogleFonts.inter(color: _kSub, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _kCyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _bomItemRow(int index, BomItem item) {
    final esManoObra = item.descripcion.startsWith('Mano de Obra');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esManoObra
              ? _kTeal.withValues(alpha: 0.3)
              : _kDivider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.catalogoId != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Catálogo',
                          style: GoogleFonts.inter(
                              color: _kTeal,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.descripcion,
                        style: GoogleFonts.inter(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.cantidad % 1 == 0 ? item.cantidad.toInt() : item.cantidad.toStringAsFixed(1)} ${item.unidad} × ${_currency.format(item.precioUnitario)}',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currency.format(item.subtotal),
            style: GoogleFonts.inter(
              color: esManoObra ? _kTeal : _kText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit, color: _kCyan, size: 16),
            tooltip: 'Cambiar cantidad',
            onPressed: () => _editarCantidadItem(index),
          ),
          if (item.esPersonalizado)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _kRed, size: 16),
              tooltip: 'Eliminar',
              onPressed: () => setState(() => _items.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _imprevistosYMargenCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Imprevistos de Obra: ${_imprevistosPorcentaje.toInt()}%',
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _currency.format(_imprevistos),
                style: GoogleFonts.inter(
                  color: _kAmber,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: _imprevistosPorcentaje,
            min: 0.0,
            max: 20.0,
            divisions: 20,
            activeColor: _kAmber,
            inactiveColor: _kDivider,
            onChanged: (v) => setState(() => _imprevistosPorcentaje = v),
          ),
          const Divider(color: _kDivider, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Margen de Utilidad Comercial: ${_margen.toInt()}%',
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _currency.format(_margenMonto),
                style: GoogleFonts.inter(
                  color: _kCyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: _margen,
            min: 10.0,
            max: 60.0,
            divisions: 50,
            activeColor: _kBlue,
            inactiveColor: _kDivider,
            onChanged: (v) => setState(() => _margen = v),
          ),
        ],
      ),
    );
  }

  Widget _totalesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _totalRow('Costo Insumos y Materiales', _currency.format(_costoMateriales)),
          const SizedBox(height: 4),
          _totalRow('Mano de Obra Cuadrilla', _currency.format(_costoManoObra)),
          const SizedBox(height: 4),
          _totalRow(
              'Imprevistos (${_imprevistosPorcentaje.toInt()}%)', _currency.format(_imprevistos)),
          const SizedBox(height: 4),
          _totalRow(
              'Margen Comercial (${_margen.toInt()}%)', _currency.format(_margenMonto)),
          const Divider(color: _kDivider, height: 16),
          _totalRow('Subtotal (Venta)', _currency.format(_subtotalConMargen),
              esBold: true),
          const SizedBox(height: 4),
          _totalRow('Impuesto General a las Ventas (IGV 18%)',
              _currency.format(_igv)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kTeal.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRECIO TOTAL (PEN)',
                  style: GoogleFonts.inter(
                    color: _kTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _currency.format(_total),
                  style: GoogleFonts.inter(
                    color: _kTeal,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool esBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: esBold ? _kText : _kSub,
            fontSize: esBold ? 13 : 12,
            fontWeight: esBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: esBold ? _kText : _kSub,
            fontSize: esBold ? 13 : 12,
            fontWeight: esBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBotonAprobar() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _guardando ? null : _guardarCotizacion,
        icon: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline),
        label: Text(
          _guardando
              ? 'Guardando Cotización y Aperturando Obra...'
              : 'Aprobar Cotización y Crear Proyecto',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
