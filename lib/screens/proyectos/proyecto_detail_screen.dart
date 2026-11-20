// lib/screens/proyectos/proyecto_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';
import '../../widgets/sync_status_chip.dart';
import '../acta/acta_preview_screen.dart';
import '../acta/acta_signature_screen.dart';
import '../trazabilidad/evidencia_form_screen.dart';

const _cBg = Color(0xFF060C18);
const _cSurface = Color(0xFF0D1526);
const _cCard = Color(0xFF111F35);
const _cViolet = Color(0xFF7C3AED);
const _cBlue = Color(0xFF2979FF);
const _cCyan = Color(0xFF00E5FF);
const _cTeal = Color(0xFF00BFA5);
const _cText = Colors.white;
const _cSub = Color(0xFF8899AA);
const _cDivider = Color(0xFF1A2840);

class ProyectoDetailScreen extends StatefulWidget {
  final String proyectoId;
  final Map<String, dynamic>? proyecto;
  final Perfil? user;

  ProyectoDetailScreen({
    super.key,
    String? proyectoId,
    this.proyecto,
    this.user,
  }) : proyectoId = proyectoId ?? (proyecto?['id']?.toString() ?? '');

  @override
  State<ProyectoDetailScreen> createState() => _ProyectoDetailScreenState();
}

class _ProyectoDetailScreenState extends State<ProyectoDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseService.instance;

  Map<String, dynamic>? _proyecto;
  List<Map<String, dynamic>> _hitos = [];
  List<Map<String, dynamic>> _equipo = [];
  List<Map<String, dynamic>> _materiales = [];
  Map<String, dynamic>? _acta;
  bool _cargando = true;

  late TabController _tabController;

  static const List<Color> _hitosColores = [
    Color(0xFF0284C7), // Azul
    Color(0xFF0D9488), // Verde azulado
    Color(0xFF4F46E5), // Indigo
    Color(0xFF16A34A), // Verde
  ];

  Perfil get _usuarioActual =>
      widget.user ?? AuthService.instance.perfil ?? Perfil.vacio;

  bool get _puedeGestionar => _usuarioActual.puedeGestionar;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _cargarDetalle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    setState(() => _cargando = true);
    try {
      // Consultas independientes en paralelo: un solo tiempo de red en vez de
      // seis viajes consecutivos al servidor (us-east-1).
      final (proyecto, hitos, equipo, acta, materiales) = await (
        _service.getProyectoCompleto(widget.proyectoId),
        _service.getHitosConEvidencias(widget.proyectoId),
        _service.getEquipoProyecto(widget.proyectoId),
        _service.getActaProyecto(widget.proyectoId),
        _service.getMaterialesProyecto(widget.proyectoId),
      ).wait;

      if (mounted) {
        setState(() {
          _proyecto = proyecto;
          _hitos = hitos;
          _equipo = equipo;
          _acta = acta;
          _materiales = materiales;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        mostrarError(context, 'Error al cargar detalles de la obra: $e');
      }
    }
  }

  int get _hitosCompletados =>
      _hitos.where((h) => h['completado'] == true).length;
  bool get _todosCompletados =>
      _hitos.isNotEmpty && _hitosCompletados == _hitos.length;

  Future<void> _abrirRegistroEvidencia(Map<String, dynamic> hito) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EvidenciaFormScreen(
          proyectoId: widget.proyectoId,
          hitoId: hito['id']?.toString() ?? '',
          hitoTitulo: hito['nombre_fase']?.toString(),
          codigoProyecto: _proyecto?['codigo_proyecto']?.toString(),
        ),
      ),
    );

    if (ok == true && mounted) {
      _cargarDetalle();
    }
  }

  void _mostrarOpcionesHito(Map<String, dynamic> hito) {
    final estado = _proyecto?['estado'];
    if (estado == 'Completado' || estado == 'Cancelado') {
      mostrarAviso(
          context, 'Obra $estado. No se pueden modificar los hitos.');
      return;
    }

    if (hito['completado'] == true) {
      final evidencias =
          List<Map<String, dynamic>>.from(hito['evidencias_proyecto'] ?? []);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _cSurface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hito['nombre_fase'],
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _cText,
                ),
              ),
              const SizedBox(height: 10),
              if (hito['completado_sin_evidencia'] == true)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Completado SIN EVIDENCIA.\nMotivo: ${hito['motivo_sin_evidencia']}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                )
              else if (evidencias.isNotEmpty)
                Text(
                  '${evidencias.length} evidencia(s) registradas con GPS / QR.',
                  style: GoogleFonts.inter(color: _cSub, fontSize: 13),
                ),
              if (_puedeGestionar && evidencias.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final ev in evidencias)
                  _tileEvidencia(ctx, hito, ev, evidencias.length),
              ],
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_a_photo, color: _cCyan),
                title: Text(
                  'Agregar evidencia adicional',
                  style: GoogleFonts.inter(color: _cText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirRegistroEvidencia(hito);
                },
              ),
              if (_puedeGestionar && _proyecto?['estado'] != 'Completado') ...[
                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.redAccent),
                  title: Text(
                    'Reabrir Hito',
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _service.reabrirHito(hito['id']);
                    _cargarDetalle();
                  },
                ),
              ],
            ],
          ),
        ),
      );
      return;
    }

    // No completado: opciones
    showModalBottomSheet(
      context: context,
      backgroundColor: _cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar Hito Técnico',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _cText,
              ),
            ),
            Text(
              hito['nombre_fase'],
              style: GoogleFonts.inter(fontSize: 13, color: _cSub),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cCyan.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: _cCyan),
              ),
              title: Text(
                'Registrar Evidencia (Foto, GPS y QR)',
                style: GoogleFonts.inter(
                    color: _cText, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Captura in situ, compresión >70% y coordenadas',
                style: GoogleFonts.inter(color: _cSub, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _abrirRegistroEvidencia(hito);
              },
            ),
            const Divider(color: _cDivider, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber),
              ),
              title: Text(
                'Completar sin evidencia',
                style: GoogleFonts.inter(
                    color: Colors.amber, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Exige justificación técnica auditada (mín. 10 caracteres)',
                style: GoogleFonts.inter(
                    color: Colors.amber.withValues(alpha: 0.7), fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarDialogoSinEvidencia(hito);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileEvidencia(BuildContext ctx, Map<String, dynamic> hito,
      Map<String, dynamic> ev, int total) {
    final url = ev['foto_url']?.toString();
    final fecha =
        DateTime.tryParse('${ev['capturado_en'] ?? ev['created_at'] ?? ''}')
            ?.toLocal();
    final serie = ev['numero_serie']?.toString() ?? '';
    final nota = ev['comentario']?.toString().trim() ?? '';
    final detalle = [
      if (fecha != null) DateFormat('dd/MM/yyyy HH:mm').format(fecha),
      if (serie.isNotEmpty) 'Serie $serie',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: (url == null || url.isEmpty)
              ? const Icon(Icons.image_not_supported_outlined, color: _cSub)
              : Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, color: _cSub)),
        ),
      ),
      title: Text(nota.isEmpty ? 'Evidencia fotográfica' : nota,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: _cText, fontSize: 13)),
      subtitle: Text(detalle,
          style: GoogleFonts.inter(color: _cSub, fontSize: 11)),
      trailing: IconButton(
        tooltip: 'Eliminar evidencia',
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        onPressed: () {
          Navigator.pop(ctx);
          _eliminarEvidencia(hito, ev, total);
        },
      ),
    );
  }

  /// Solo Admin/Supervisor y con la obra abierta (el acta As-Built cierra la
  /// trazabilidad). Si el hito se queda sin evidencias, vuelve a Pendiente.
  Future<void> _eliminarEvidencia(
      Map<String, dynamic> hito, Map<String, dynamic> ev, int total) async {
    final ultima = total <= 1 && hito['completado_sin_evidencia'] != true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cDivider),
        ),
        title: Text('Eliminar evidencia',
            style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          ultima
              ? 'La foto se borra de forma permanente. Como es la única evidencia, el hito volverá a Pendiente.'
              : 'La foto y su registro (GPS y serie) se borran de forma permanente.',
          style: GoogleFonts.inter(color: _cText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _cSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cargando = true);
    try {
      await _service.eliminarEvidencia(ev);
      if (ultima) await _service.reabrirHito(hito['id'].toString());
      if (mounted) mostrarOk(context, 'Evidencia eliminada');
    } catch (e) {
      if (mounted) mostrarError(context, 'No se pudo eliminar: $e');
    }
    await _cargarDetalle();
  }

  void _mostrarDialogoSinEvidencia(Map<String, dynamic> hito) {
    final formKey = GlobalKey<FormState>();
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cDivider),
        ),
        title: Text(
          'Omitir Evidencia Técnica',
          style: GoogleFonts.inter(
              color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Confirmar hito sin evidencia fotográfica in situ? Esta acción quedará registrada en el dossier As-Built.',
                style: GoogleFonts.inter(color: _cText, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AppField(
                label: 'Motivo técnico auditado',
                controller: motivoCtrl,
                hint: 'Ej. Área restringida con prohibición de cámaras fotográficas...',
                prefixIcon: Icons.warning_amber,
                maxLines: 3,
                inputFormatters: [Formatters.texto],
                validator: (v) {
                  final req = Validators.requerido(v);
                  if (req != null) return req;
                  return Validators.textoMin(10)(v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _cSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx);
              setState(() => _cargando = true);
              try {
                await _service.completarHitoSinEvidencia(
                  hitoId: hito['id'].toString(),
                  perfilId: _usuarioActual.id,
                  motivo: motivoCtrl.text.trim(),
                );
                await _cargarDetalle();
                if (mounted) {
                  mostrarOk(context, 'Hito completado sin evidencia');
                }
              } catch (e) {
                if (mounted) mostrarError(context, 'Error: $e');
                setState(() => _cargando = false);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  /// Rol del miembro en la obra. Solo puede haber un Líder: al elegirlo, el
  /// servicio degrada al anterior y actualiza proyectos.lider_id.
  Future<String?> _elegirRolEquipo(String nombre) {
    Widget opcion(BuildContext ctx, String rol, IconData icono, String detalle) =>
        ListTile(
          leading: Icon(icono, color: rol == 'Líder' ? Colors.amber : _cCyan),
          title: Text(rol,
              style: GoogleFonts.inter(
                  color: _cText, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(detalle,
              style: GoogleFonts.inter(color: _cSub, fontSize: 12)),
          onTap: () => Navigator.pop(ctx, rol),
        );

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cDivider),
        ),
        title: Text('Rol de $nombre en la obra',
            style: GoogleFonts.inter(
                color: _cText, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            opcion(ctx, 'Líder', Icons.star_rounded,
                'Responsable de la cuadrilla (uno por obra)'),
            opcion(ctx, 'Técnico', Icons.engineering_outlined,
                'Ejecuta hitos y registra evidencias'),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarRolMiembro(Map<String, dynamic> item, String nombre) async {
    final rol = await _elegirRolEquipo(nombre);
    if (rol == null || rol == item['rol_en_proyecto'] || !mounted) return;
    setState(() => _cargando = true);
    try {
      await _service.cambiarRolMiembro(
        miembroId: item['id'].toString(),
        proyectoId: widget.proyectoId,
        perfilId: item['perfil_id'].toString(),
        rol: rol,
      );
      if (mounted) mostrarOk(context, '$nombre ahora es $rol');
    } catch (e) {
      if (mounted) mostrarError(context, 'No se pudo cambiar el rol: $e');
    }
    _cargarDetalle();
  }

  Future<void> _quitarMiembro(Map<String, dynamic> item, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cDivider),
        ),
        title: Text('Quitar de la obra',
            style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
          '$nombre dejará de ver esta obra y de registrar evidencias en ella. Sus evidencias ya registradas se conservan.',
          style: GoogleFonts.inter(color: _cText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _cSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cargando = true);
    try {
      await _service.quitarMiembroEquipo(
        miembroId: item['id'].toString(),
        proyectoId: widget.proyectoId,
        perfilId: item['perfil_id'].toString(),
      );
      if (mounted) mostrarOk(context, '$nombre fue quitado del equipo');
    } catch (e) {
      if (mounted) mostrarError(context, 'No se pudo quitar: $e');
    }
    _cargarDetalle();
  }

  void _mostrarAgregarEquipo() async {
    final perfiles =
        await AuthService.instance.listarPerfiles(soloActivos: true);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asignar Personal a la Obra',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _cText,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: perfiles.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: _cDivider, height: 1),
                itemBuilder: (context, index) {
                  final p = perfiles[index];
                  final yaAsignado =
                      _equipo.any((e) => e['perfil_id'] == p['id']);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _cDivider,
                      child: Text(
                        (p['nombre'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                        style: GoogleFonts.inter(color: _cCyan),
                      ),
                    ),
                    title: Text(
                      '${p['nombre']} ${p['apellido'] ?? ''}',
                      style: GoogleFonts.inter(color: _cText, fontSize: 14),
                    ),
                    subtitle: Text(
                      p['email'] ?? '',
                      style: GoogleFonts.inter(color: _cSub, fontSize: 12),
                    ),
                    trailing: yaAsignado
                        ? const Icon(Icons.check_circle, color: _cTeal, size: 20)
                        : const Icon(Icons.add_circle_outline,
                            color: _cCyan, size: 20),
                    onTap: yaAsignado
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            final rol = await _elegirRolEquipo(
                                '${p['nombre']} ${p['apellido'] ?? ''}');
                            if (rol == null || !mounted) return;
                            setState(() => _cargando = true);
                            try {
                              await _service.agregarMiembroEquipo(
                                proyectoId: widget.proyectoId,
                                perfilId: p['id'].toString(),
                                rol: rol,
                              );
                              if (mounted) {
                                mostrarOk(this.context, 'Personal asignado como $rol');
                              }
                            } catch (e) {
                              if (mounted) {
                                mostrarError(this.context, 'No se pudo asignar: $e');
                              }
                            }
                            _cargarDetalle();
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Columnas reales de proyecto_materiales: item_descripcion y unidad.
  static String _nombreMaterial(Map<String, dynamic> m) =>
      (m['item_descripcion'] ?? m['descripcion'] ?? 'Material').toString();
  static String _unidadMaterial(Map<String, dynamic> m) =>
      (m['unidad'] ?? m['unidad_medida'] ?? 'und').toString();
  static String _num(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _editarCantidadInstalada(Map<String, dynamic> material) async {
    final formKey = GlobalKey<FormState>();
    final presupuestado =
        (material['cantidad_presupuestada'] as num?)?.toDouble() ?? 0.0;
    final unidad = _unidadMaterial(material);
    final inicial = (material['cantidad_instalada'] as num?)?.toDouble() ?? 0.0;
    final ctrl = TextEditingController(text: _num(inicial));
    var excede = inicial > presupuestado;

    final resultado = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cDivider),
        ),
        title: Text(
          'Actualizar Metrado Instalado',
          style: GoogleFonts.inter(
              color: _cText, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nombreMaterial(material),
                style: GoogleFonts.inter(
                    color: _cCyan, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Presupuestado: ${_num(presupuestado)} $unidad',
                style: GoogleFonts.inter(color: _cSub, fontSize: 12),
              ),
              const SizedBox(height: 12),
              AppField(
                label: 'Cantidad Real Instalada ($unidad)',
                controller: ctrl,
                prefixIcon: Icons.straighten,
                inputFormatters: [Formatters.decimal],
                validator: Validators.decimal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final n = double.tryParse(v.trim()) ?? 0;
                  if ((n > presupuestado) != excede) {
                    setD(() => excede = n > presupuestado);
                  }
                },
              ),
              if (excede) ...[
                const SizedBox(height: 10),
                _alertaExceso(
                    'Supera lo presupuestado. Se guardará igual, pero quedará '
                    'marcado como exceso en el As-Built.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _cSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _cBlue),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final d = double.tryParse(ctrl.text.trim());
                if (d != null) Navigator.pop(ctx, d);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      )),
    );

    if (resultado != null && mounted) {
      setState(() => _cargando = true);
      try {
        await _service.actualizarCantidadInstalada(
            material['id'].toString(), resultado);
        await _cargarDetalle();
        if (mounted) mostrarOk(context, 'Metrado As-Built actualizado');
      } catch (e) {
        if (mounted) mostrarError(context, 'Error al actualizar metrado: $e');
        setState(() => _cargando = false);
      }
    }
  }

  Widget _alertaExceso(String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto,
                  style: GoogleFonts.inter(color: Colors.amber, fontSize: 11.5)),
            ),
          ],
        ),
      );

  Future<void> _abrirActaPdf() async {
    final pdfPath = _acta?['pdf_path']?.toString();
    if (pdfPath == null || pdfPath.isEmpty) {
      mostrarAviso(context, 'Ruta de archivo de acta no disponible');
      return;
    }
    setState(() => _cargando = true);
    try {
      final bytes = await _service.descargarActaPdf(pdfPath);
      if (!mounted) return;
      setState(() => _cargando = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActaPreviewScreen(
            titulo: 'Acta de Conformidad As-Built',
            codigoActa: _acta?['codigo_acta'] ?? 'ACTA',
            pdfBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        mostrarError(context, 'Error al descargar acta PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: _cBg,
        body: Center(child: CircularProgressIndicator(color: _cCyan)),
      );
    }

    final nombre = _proyecto?['nombre_obra'] ?? 'Proyecto';
    final codigo = _proyecto?['codigo_proyecto'] ?? '—';
    final estado = _proyecto?['estado'] ?? 'En Proceso';
    final progreso = _hitos.isEmpty ? 0.0 : _hitosCompletados / _hitos.length;
    final cliente =
        _proyecto?['clientes']?['razon_social'] ?? 'Cliente Desconocido';

    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              codigo,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _cText,
              ),
            ),
            Text(
              cliente,
              style: GoogleFonts.inter(fontSize: 11, color: _cCyan),
            ),
          ],
        ),
        actions: [
          const SyncStatusChip(),
          if (_puedeGestionar &&
              estado != 'Completado' &&
              estado != 'Cancelado')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _cText),
              color: _cCard,
              onSelected: (value) async {
                setState(() => _cargando = true);
                try {
                  if (value == 'Pausar') {
                    await _service.cambiarEstadoProyecto(
                        widget.proyectoId, 'Pausado');
                  } else if (value == 'Reanudar') {
                    await _service.cambiarEstadoProyecto(
                        widget.proyectoId, 'En Proceso');
                  } else if (value == 'Cancelar') {
                    await _service.cambiarEstadoProyecto(
                        widget.proyectoId, 'Cancelado');
                  }
                  await _cargarDetalle();
                } catch (e) {
                  if (mounted) mostrarError(context, 'Error: $e');
                  setState(() => _cargando = false);
                }
              },
              itemBuilder: (context) => [
                if (estado == 'En Proceso')
                  PopupMenuItem(
                    value: 'Pausar',
                    child: Text('Pausar Proyecto',
                        style: GoogleFonts.inter(color: Colors.amber)),
                  ),
                if (estado == 'Pausado')
                  PopupMenuItem(
                    value: 'Reanudar',
                    child: Text('Reanudar Proyecto',
                        style: GoogleFonts.inter(color: _cCyan)),
                  ),
                PopupMenuItem(
                  value: 'Cancelar',
                  child: Text('Cancelar Proyecto',
                      style: GoogleFonts.inter(color: Colors.redAccent)),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _cCyan,
          labelColor: _cCyan,
          unselectedLabelColor: _cSub,
          tabs: const [
            Tab(text: 'Hitos'),
            Tab(text: 'Materiales As-Built'),
            Tab(text: 'Equipo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: HITOS Y CONTROL TÉCNICO
          RefreshIndicator(
            onRefresh: _cargarDetalle,
            color: _cCyan,
            child: ListView(
              padding: const EdgeInsets.all(16).copyWith(bottom: 100),
              children: [
                // Header del progreso
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _cText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _cCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estado,
                              style: GoogleFonts.inter(
                                color: _cCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Progreso de Certificación',
                              style: GoogleFonts.inter(
                                  color: _cSub, fontSize: 12)),
                          Text(
                            '${(progreso * 100).toInt()}%',
                            style: GoogleFonts.inter(
                              color: _cTeal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progreso,
                          minHeight: 8,
                          backgroundColor: _cBg,
                          valueColor: const AlwaysStoppedAnimation<Color>(_cTeal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'HITOS TÉCNICOS',
                  style: GoogleFonts.inter(
                    color: _cSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _hitos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final hito = _hitos[index];
                    final completado = hito['completado'] == true;
                    final color = _hitosColores[index % _hitosColores.length];
                    final evidencias = List<Map<String, dynamic>>.from(
                        hito['evidencias_proyecto'] ?? []);

                    return Container(
                      decoration: BoxDecoration(
                        color: _cCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: completado
                              ? _cTeal.withValues(alpha: 0.5)
                              : _cDivider,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: completado
                              ? _cTeal
                              : color.withValues(alpha: 0.2),
                          child: Icon(
                            completado ? Icons.check : Icons.circle_outlined,
                            color: completado ? Colors.black : color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          hito['nombre_fase'] ?? 'Hito',
                          style: GoogleFonts.inter(
                            color: _cText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: completado
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          completado
                              ? (hito['completado_sin_evidencia'] == true
                                  ? 'Completado sin evidencia'
                                  : '${evidencias.length} evidencias fotográficas')
                              : 'Tocar para registrar evidencias',
                          style: GoogleFonts.inter(
                            color: completado ? _cTeal : _cSub,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 14, color: _cSub),
                        onTap: () => _mostrarOpcionesHito(hito),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // TAB 2: MATERIALES AS-BUILT
          RefreshIndicator(
            onRefresh: _cargarDetalle,
            color: _cCyan,
            child: ListView(
              padding: const EdgeInsets.all(16).copyWith(bottom: 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cDivider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: _cCyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Metrados y Lista de Materiales As-Built. Puede ajustar la cantidad instalada real tocando el ícono de edición.',
                          style: GoogleFonts.inter(color: _cSub, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_materiales.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No hay materiales registrados para esta obra.',
                        style: GoogleFonts.inter(color: _cSub),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _materiales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final m = _materiales[index];
                      final p =
                          (m['cantidad_presupuestada'] as num?)?.toDouble() ??
                              0.0;
                      final i =
                          (m['cantidad_instalada'] as num?)?.toDouble() ?? 0.0;
                      final unidad = _unidadMaterial(m);
                      final excede = i > p;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: excede
                                  ? Colors.amber.withValues(alpha: 0.6)
                                  : _cDivider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _nombreMaterial(m),
                                    style: GoogleFonts.inter(
                                      color: _cText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Presupuestado: ${_num(p)} $unidad  |  Instalado: ${_num(i)} $unidad',
                                    style: GoogleFonts.inter(
                                      color: _cSub,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: p > 0
                                          ? (i / p).clamp(0.0, 1.0)
                                          : 0.0,
                                      minHeight: 4,
                                      backgroundColor: _cDivider,
                                      color: excede ? Colors.amber : _cTeal,
                                    ),
                                  ),
                                  if (excede) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '⚠ Exceso: +${_num(i - p)} $unidad sobre lo presupuestado',
                                      style: GoogleFonts.inter(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: _cCyan, size: 18),
                              tooltip: 'Editar cantidad instalada',
                              onPressed: () => _editarCantidadInstalada(m),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // TAB 3: EQUIPO ASIGNADO
          RefreshIndicator(
            onRefresh: _cargarDetalle,
            color: _cCyan,
            child: ListView(
              padding: const EdgeInsets.all(16).copyWith(bottom: 100),
              children: [
                if (_equipo.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No hay miembros asignados al equipo de obra.',
                        style: GoogleFonts.inter(color: _cSub),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _equipo.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _equipo[index];
                      final p = item['perfiles'] is Map<String, dynamic>
                          ? item['perfiles']
                          : {};
                      final rol = item['rol_en_proyecto'] ?? 'Técnico';
                      final esLider = rol == 'Líder';
                      final nombre =
                          '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}'.trim();
                      final puedeGestionar =
                          AuthService.instance.perfil?.puedeGestionar ?? false;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cDivider),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _cViolet.withValues(alpha: 0.2),
                              child: Text(
                                (p['nombre'] ?? 'T')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: GoogleFonts.inter(color: _cViolet),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}',
                                    style: GoogleFonts.inter(
                                      color: _cText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    p['cargo'] ?? 'Técnico de Redes',
                                    style: GoogleFonts.inter(
                                      color: _cSub,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: puedeGestionar
                                  ? () => _cambiarRolMiembro(item, nombre)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (esLider ? Colors.amber : _cCyan)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (esLider)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 13),
                                      ),
                                    Text(
                                      rol,
                                      style: GoogleFonts.inter(
                                        color: esLider ? Colors.amber : _cCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (puedeGestionar)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(Icons.edit,
                                            color: (esLider
                                                    ? Colors.amber
                                                    : _cCyan)
                                                .withValues(alpha: 0.7),
                                            size: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (puedeGestionar &&
                                estado != 'Completado' &&
                                estado != 'Cancelado')
                              IconButton(
                                tooltip: 'Quitar de la obra',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.person_remove_outlined,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _quitarMiembro(item, nombre),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                if (_puedeGestionar &&
                    estado != 'Completado' &&
                    estado != 'Cancelado')
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _cCyan),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.person_add, color: _cCyan),
                      label: Text(
                        'Añadir Personal a la Obra',
                        style: GoogleFonts.inter(
                          color: _cCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _mostrarAgregarEquipo,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (estado == 'Completado' &&
              _acta != null &&
              _acta!['pdf_path'] != null)
          ? FloatingActionButton.extended(
              backgroundColor: _cCyan,
              onPressed: _abrirActaPdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
              label: Text(
                'Ver Acta As-Built PDF',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : (_todosCompletados &&
                  estado != 'Completado' &&
                  estado != 'Cancelado')
              ? FloatingActionButton.extended(
                  backgroundColor: _cViolet,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActaSignatureScreen(
                          nombreProyecto: nombre,
                          proyecto: _proyecto!,
                          equipo: _equipo,
                        ),
                      ),
                    );
                    _cargarDetalle();
                  },
                  icon: const Icon(Icons.draw, color: Colors.white),
                  label: Text(
                    'Generar Acta y Firmar',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
    );
  }
}
