// lib/screens/catalogo/catalogo_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/catalogo_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';

const _cBg = Color(0xFF060C18);
const _cSurface = Color(0xFF0D1526);
const _cCard = Color(0xFF111F35);
const _cBlue = Color(0xFF2979FF);
const _cCyan = Color(0xFF00E5FF);
const _cTeal = Color(0xFF00BFA5);
const _cAmber = Color(0xFFFFB300);
const _cText = Colors.white;
const _cSub = Color(0xFF8899AA);
const _cDivider = Color(0xFF1A2840);

class CatalogoScreen extends StatefulWidget {
  final Perfil? user;
  const CatalogoScreen({super.key, this.user});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _service = SupabaseService.instance;
  final _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

  List<Map<String, dynamic>> _materiales = [];
  bool _isLoading = true;
  bool _desdeCache = false;
  String _filtroCategoria = 'Todos';

  Perfil get _usuarioActual =>
      widget.user ?? AuthService.instance.perfil ?? Perfil.vacio;

  bool get _puedeEditar => _usuarioActual.puedeGestionar;

  final List<String> _categorias = const [
    'Todos',
    'cableado',
    'conectividad',
    'gabinete_rack',
    'equipo_activo',
    'canalizacion',
    'mano_obra',
    'otros'
  ];

  static const List<(String, String)> _unidades = [
    ('und', 'und (Unidad)'),
    ('m', 'm (Metro)'),
    ('ml', 'ml (Metro lineal)'),
    ('caja_305m', 'Caja 305 m'),
    ('Caja', 'Caja'),
    ('Global', 'Global'),
    ('rollo', 'rollo'),
    ('kg', 'kg'),
    ('jgo', 'jgo'),
  ];

  /// Opciones del desplegable + el valor actual si no estaba en la lista.
  static List<(String, String)> _opcionesConValor(
      List<(String, String)> opciones, String actual) {
    if (opciones.any((o) => o.$1 == actual)) return opciones;
    return [...opciones, (actual, actual)];
  }

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  Future<void> _cargarCatalogo() async {
    setState(() => _isLoading = true);
    try {
      final res = await CatalogoRepository.instance.obtener(
        soloActivos: !_puedeEditar,
      );
      if (mounted) {
        setState(() {
          _materiales = res.items;
          _desdeCache = res.desdeCache;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        mostrarError(context, 'Error al cargar catálogo: $e');
      }
    }
  }

  /// Activa o desactiva un insumo sin abrir el formulario (baja lógica).
  Future<void> _alternarActivo(Map<String, dynamic> item, bool activo) async {
    try {
      await _service.toggleActivoCatalogo(item.id, activo);
      if (mounted) {
        mostrarOk(context, activo ? 'Insumo activado' : 'Insumo desactivado');
      }
      await _cargarCatalogo();
    } catch (e) {
      if (mounted) mostrarError(context, 'No se pudo cambiar el estado: $e');
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtroCategoria == 'Todos') return _materiales;
    return _materiales.where((m) => m.categoria == _filtroCategoria).toList();
  }

  void _mostrarFormulario([Map<String, dynamic>? item]) {
    if (!_puedeEditar) {
      mostrarAviso(
        context,
        'Acceso de solo lectura para técnicos. Los cambios requieren rol Supervisor o Admin.',
      );
      return;
    }

    final bool esEdicion = item != null;
    final formKey = GlobalKey<FormState>();

    final descCtrl = TextEditingController(text: item?.descripcion ?? '');
    final costoCtrl = TextEditingController(
      text: item != null
          ? (item.costoBase % 1 == 0
              ? item.costoBase.toInt().toString()
              : item.costoBase.toString())
          : '0',
    );
    final ventaCtrl = TextEditingController(
      text: item != null
          ? (item.precioVentaDefault % 1 == 0
              ? item.precioVentaDefault.toInt().toString()
              : item.precioVentaDefault.toString())
          : '0',
    );

    String unidadSel = item?.unidadMedida ?? 'und';
    String catSel = item?.categoria ?? 'conectividad';
    bool activo = item?.activo ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _cSub.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      esEdicion ? 'Editar Insumo del Catálogo' : 'Nuevo Insumo',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _cText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppField(
                      label: 'Descripción del Material / Insumo',
                      controller: descCtrl,
                      hint: 'Ej. Bobina Cable UTP Cat 6A LSZH 305m',
                      prefixIcon: Icons.inventory_2_outlined,
                      inputFormatters: [Formatters.texto],
                      validator: (v) {
                        final req = Validators.requerido(v);
                        if (req != null) return req;
                        return Validators.textoMin(3)(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppField(
                            label: 'Costo Base (S/.)',
                            controller: costoCtrl,
                            prefixIcon: Icons.attach_money,
                            inputFormatters: [Formatters.decimal],
                            validator: Validators.decimal,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppField(
                            label: 'Precio Venta (S/.)',
                            controller: ventaCtrl,
                            prefixIcon: Icons.price_change_outlined,
                            inputFormatters: [Formatters.decimal],
                            validator: Validators.decimal,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _cCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _cDivider),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: unidadSel,
                              decoration: const InputDecoration(
                                labelText: 'Unidad de Medida',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              dropdownColor: _cCard,
                              style: GoogleFonts.inter(
                                  color: _cText, fontSize: 13),
                              // Incluye siempre el valor guardado: un valor fuera
                              // de la lista hace fallar al DropdownButton.
                              items: _opcionesConValor(_unidades, unidadSel)
                                  .map((u) => DropdownMenuItem(
                                      value: u.$1, child: Text(u.$2)))
                                  .toList(),
                              onChanged: (v) =>
                                  setModalState(() => unidadSel = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _cCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _cDivider),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: catSel,
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              dropdownColor: _cCard,
                              style: GoogleFonts.inter(
                                  color: _cText, fontSize: 13),
                              items: _opcionesConValor(
                                      _categorias
                                          .where((c) => c != 'Todos')
                                          .map((c) => (c, c))
                                          .toList(),
                                      catSel)
                                  .map((c) => DropdownMenuItem(
                                      value: c.$1, child: Text(c.$2)))
                                  .toList(),
                              onChanged: (v) => setModalState(() => catSel = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Insumo Activo en Catálogo',
                        style: GoogleFonts.inter(color: _cText, fontSize: 14),
                      ),
                      value: activo,
                      activeThumbColor: _cTeal,
                      onChanged: (v) => setModalState(() => activo = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final c = double.tryParse(costoCtrl.text.trim()) ?? 0.0;
                          final p = double.tryParse(ventaCtrl.text.trim()) ?? 0.0;

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);

                          try {
                            if (esEdicion) {
                              await _service.actualizarInsumo(
                                item.id,
                                {
                                  'descripcion': descCtrl.text.trim(),
                                  'costo_base': c,
                                  'precio_venta_default': p,
                                  'unidad_medida': unidadSel,
                                  'categoria': catSel,
                                  'activo': activo,
                                },
                              );
                              if (mounted) mostrarOk(context, 'Insumo actualizado');
                            } else {
                              await _service.crearInsumo({
                                'descripcion': descCtrl.text.trim(),
                                'categoria': catSel,
                                'unidad_medida': unidadSel,
                                'costo_base': c,
                                'precio_venta_default': p,
                                'activo': activo,
                              });
                              if (mounted) mostrarOk(context, 'Insumo registrado');
                            }
                            _cargarCatalogo();
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              mostrarError(context, 'Error al guardar insumo: $e');
                            }
                          }
                        },
                        child: Text(
                          esEdicion ? 'Guardar Cambios' : 'Crear Insumo',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cSurface,
        elevation: 0,
        title: Text(
          _puedeEditar
              ? 'Catálogo de Precios y Materiales'
              : 'Catálogo de Precios (Lectura)',
          style: GoogleFonts.inter(
            color: _cText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _cCyan),
            tooltip: 'Recargar',
            onPressed: _cargarCatalogo,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _cDivider, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _cCyan))
          : Column(
              children: [
                if (_desdeCache) _buildCacheBanner(),
                _buildFiltroChips(),
                Expanded(
                  child: filtrados.isEmpty
                      ? Center(
                          child: Text(
                            'No hay insumos en esta categoría.',
                            style: GoogleFonts.inter(color: _cSub),
                          ),
                        )
                      : RefreshIndicator(
                          color: _cCyan,
                          backgroundColor: _cSurface,
                          onRefresh: _cargarCatalogo,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtrados.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtrados[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _cCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: item.activo
                                        ? _cDivider
                                        : Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _cBlue
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.sku,
                                                  style: GoogleFonts.inter(
                                                    color: _cCyan,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.descripcion,
                                                  style: GoogleFonts.inter(
                                                    color: _cText,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!item.activo) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'INACTIVO',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.redAccent,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Costo Base: ${_currency.format(item.costoBase)} / ${item.unidadMedida}  ·  Venta: ${_currency.format(item.precioVentaDefault)}',
                                            style: GoogleFonts.inter(
                                              color: _cSub,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_puedeEditar) ...[
                                      Tooltip(
                                        message: item.activo
                                            ? 'Activo: disponible en el cotizador'
                                            : 'Inactivo: no aparece en el cotizador',
                                        child: Switch(
                                          value: item.activo,
                                          activeThumbColor: _cTeal,
                                          onChanged: (v) =>
                                              _alternarActivo(item, v),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: _cCyan, size: 18),
                                        onPressed: () =>
                                            _mostrarFormulario(item),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: _puedeEditar
          ? FloatingActionButton(
              backgroundColor: _cBlue,
              onPressed: () => _mostrarFormulario(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCacheBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _cAmber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: _cAmber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo Offline: Mostrando catálogo desde caché local SQLite.',
              style: GoogleFonts.inter(color: _cAmber, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: _cSurface,
        border: Border(bottom: BorderSide(color: _cDivider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categorias.map((cat) {
            final sel = _filtroCategoria == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: sel ? Colors.white : _cSub,
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: sel,
                onSelected: (_) => setState(() => _filtroCategoria = cat),
                selectedColor: _cBlue,
                backgroundColor: _cCard,
                side: BorderSide(color: sel ? _cBlue : _cDivider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
