// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../proyectos/proyecto_detail_screen.dart';

const _kBg = Color(0xFF060C18);
const _kSurface = Color(0xFF0D1526);
const _kCard = Color(0xFF111F35);
const _kBlue = Color(0xFF2979FF);
const _kCyan = Color(0xFF00E5FF);
const _kTeal = Color(0xFF00BFA5);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFFF5252);
const _kText = Colors.white;
const _kSub = Color(0xFF8899AA);
const _kDivider = Color(0xFF1A2840);

class DashboardScreen extends StatefulWidget {
  final Perfil user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService.instance;
  final _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  bool _cargando = true;
  String? _error;
  int _tiempoCargaMs = 0;

  List<Map<String, dynamic>> _proyectos = [];
  List<Map<String, dynamic>> _cotizaciones = [];
  Set<String> _proyectosConActa = {};

  // Filtros dinámicos
  String _filtroTexto = '';
  String _filtroEstado = 'Todos';
  DateTimeRange? _filtroRangoFechas;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final futures = await Future.wait([
        _service.getProyectos(),
        _service.getCotizacionesResumen(),
        _service.getProyectosConActa(),
      ]);
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _proyectos = futures[0] as List<Map<String, dynamic>>;
          _cotizaciones = futures[1] as List<Map<String, dynamic>>;
          _proyectosConActa = futures[2] as Set<String>;
          _tiempoCargaMs = stopwatch.elapsedMilliseconds;
          _cargando = false;
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _error = 'Error al cargar métricas: $e';
          _tiempoCargaMs = stopwatch.elapsedMilliseconds;
          _cargando = false;
        });
      }
    }
  }

  // Cálculos de KPIs
  int get _totalEnProceso =>
      _proyectos.where((p) => (p['estado'] ?? '') == 'En Proceso').length;

  int get _totalCompletados =>
      _proyectos.where((p) => (p['estado'] ?? '') == 'Completado').length;

  int get _totalCotizaciones => _cotizaciones.length;

  double get _montoTotalCotizado => _cotizaciones.fold<double>(
        0.0,
        (sum, c) => sum + ((c['precio_total'] as num?)?.toDouble() ?? 0.0),
      );

  // Proyectos listos para acta o pendientes de firma (todos los hitos al 100% pero sin acta firmada)
  List<Map<String, dynamic>> get _proyectosPendientesActa {
    return _proyectos.where((p) {
      final id = p['id']?.toString() ?? '';
      final yaTieneActa = _proyectosConActa.contains(id);
      if (yaTieneActa) return false;

      final hitos = p['hitos_proyecto'] as List<dynamic>? ?? [];
      if (hitos.isEmpty) return false;
      final todosCompletos = hitos.every((h) => h['completado'] == true);
      return todosCompletos;
    }).toList();
  }

  // Filtrado de proyectos para la lista
  List<Map<String, dynamic>> get _proyectosFiltrados {
    return _proyectos.where((p) {
      // Filtro texto
      final query = _filtroTexto.trim().toLowerCase();
      if (query.isNotEmpty) {
        final obra = (p['nombre_obra'] ?? '').toString().toLowerCase();
        final cod = (p['codigo_proyecto'] ?? '').toString().toLowerCase();
        final cliente =
            (p['clientes']?['razon_social'] ?? '').toString().toLowerCase();
        if (!obra.contains(query) && !cod.contains(query) && !cliente.contains(query)) {
          return false;
        }
      }

      // Filtro estado
      final estado = (p['estado'] ?? '').toString();
      if (_filtroEstado != 'Todos') {
        if (_filtroEstado == 'Pendiente Acta') {
          final id = p['id']?.toString() ?? '';
          if (_proyectosConActa.contains(id)) return false;
          final hitos = p['hitos_proyecto'] as List<dynamic>? ?? [];
          if (hitos.isEmpty || !hitos.every((h) => h['completado'] == true)) {
            return false;
          }
        } else if (estado != _filtroEstado) {
          return false;
        }
      }

      // Filtro fechas (created_at)
      if (_filtroRangoFechas != null) {
        final createdStr = p['created_at']?.toString();
        if (createdStr != null) {
          final fecha = DateTime.tryParse(createdStr);
          if (fecha != null) {
            final inicio = DateTime(
                _filtroRangoFechas!.start.year,
                _filtroRangoFechas!.start.month,
                _filtroRangoFechas!.start.day);
            final fin = DateTime(
                _filtroRangoFechas!.end.year,
                _filtroRangoFechas!.end.month,
                _filtroRangoFechas!.end.day,
                23,
                59,
                59);
            if (fecha.isBefore(inicio) || fecha.isAfter(fin)) return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Future<void> _seleccionarRangoFechas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: _filtroRangoFechas ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _kBlue,
              onPrimary: Colors.white,
              surface: _kSurface,
              onSurface: _kText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _filtroRangoFechas = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          'Dashboard Gerencial',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _kCyan),
            tooltip: 'Actualizar métricas',
            onPressed: _cargarDatos,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kDivider, height: 1),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kCyan))
          : _error != null
              ? _buildErrorView()
              : RefreshIndicator(
                  color: _kCyan,
                  backgroundColor: _kSurface,
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBenchmarkBar(),
                      const SizedBox(height: 16),
                      _buildKpiGrid(),
                      const SizedBox(height: 20),
                      _buildFiltrosBar(),
                      const SizedBox(height: 16),
                      _buildProyectosListHeader(),
                      const SizedBox(height: 8),
                      _buildProyectosList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBenchmarkBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDivider),
      ),
      child: Row(
        children: [
          Icon(
            _tiempoCargaMs < 2000 ? Icons.bolt : Icons.timer,
            color: _tiempoCargaMs < 2000 ? _kTeal : _kAmber,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rendimiento ISO/IEC 25010: Consulta en ${_tiempoCargaMs}ms (< 2.0s normado)',
              style: GoogleFonts.inter(
                color: _kSub,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ÓPTIMO',
              style: GoogleFonts.inter(
                color: _kTeal,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                titulo: 'En Proceso',
                valor: '$_totalEnProceso',
                subtitulo: 'Obras activas',
                icono: Icons.engineering,
                color: _kBlue,
                onTap: () => setState(() => _filtroEstado = 'En Proceso'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                titulo: 'Pendientes Firma',
                valor: '${_proyectosPendientesActa.length}',
                subtitulo: 'Hitos 100% sin acta',
                icono: Icons.draw,
                color: _kAmber,
                onTap: () => setState(() => _filtroEstado = 'Pendiente Acta'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                titulo: 'Estimaciones',
                valor: '$_totalCotizaciones',
                subtitulo: _currency.format(_montoTotalCotizado),
                icono: Icons.calculate,
                color: _kCyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                titulo: 'Completados',
                valor: '$_totalCompletados',
                subtitulo: 'Actas cerradas',
                icono: Icons.verified,
                color: _kTeal,
                onTap: () => setState(() => _filtroEstado = 'Completado'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icono,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icono, color: color, size: 20),
                  ),
                  if (onTap != null)
                    const Icon(Icons.arrow_forward_ios,
                        size: 12, color: _kSub),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                valor,
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titulo,
                style: GoogleFonts.inter(
                  color: _kText.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: GoogleFonts.inter(
                  color: _kSub,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltrosBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, color: _kCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filtros Dinámicos de Obras',
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_filtroTexto.isNotEmpty ||
                  _filtroEstado != 'Todos' ||
                  _filtroRangoFechas != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filtroTexto = '';
                      _filtroEstado = 'Todos';
                      _filtroRangoFechas = null;
                    });
                  },
                  child: Text(
                    'Limpiar',
                    style: GoogleFonts.inter(color: _kRed, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Buscador de texto
          TextField(
            onChanged: (v) => setState(() => _filtroTexto = v),
            style: GoogleFonts.inter(color: _kText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por obra, código o cliente...',
              hintStyle: GoogleFonts.inter(color: _kSub, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _kSub, size: 18),
              filled: true,
              fillColor: _kCard,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kCyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Selector de fechas y chips de estado
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _seleccionarRangoFechas,
                  icon: const Icon(Icons.calendar_today, size: 14, color: _kCyan),
                  label: Text(
                    _filtroRangoFechas == null
                        ? 'Cualquier fecha'
                        : '${_dateFormat.format(_filtroRangoFechas!.start)} - ${_dateFormat.format(_filtroRangoFechas!.end)}',
                    style: GoogleFonts.inter(color: _kText, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _filtroRangoFechas != null ? _kCyan : _kDivider,
                    ),
                    backgroundColor: _kCard,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildEstadoChip('Todos'),
                const SizedBox(width: 6),
                _buildEstadoChip('En Proceso'),
                const SizedBox(width: 6),
                _buildEstadoChip('Pendiente'),
                const SizedBox(width: 6),
                _buildEstadoChip('Pendiente Acta'),
                const SizedBox(width: 6),
                _buildEstadoChip('Completado'),
                const SizedBox(width: 6),
                _buildEstadoChip('Pausado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    final seleccionado = _filtroEstado == estado;
    return ChoiceChip(
      label: Text(
        estado,
        style: GoogleFonts.inter(
          color: seleccionado ? Colors.white : _kSub,
          fontSize: 11,
          fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: seleccionado,
      onSelected: (_) => setState(() => _filtroEstado = estado),
      selectedColor: _kBlue,
      backgroundColor: _kCard,
      side: BorderSide(color: seleccionado ? _kBlue : _kDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildProyectosListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Obras Encontradas (${_proyectosFiltrados.length})',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Total: ${_proyectos.length}',
          style: GoogleFonts.inter(color: _kSub, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProyectosList() {
    final lista = _proyectosFiltrados;
    if (lista.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kDivider),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.search_off, color: _kSub, size: 36),
              const SizedBox(height: 8),
              Text(
                'No se encontraron obras con los filtros aplicados',
                style: GoogleFonts.inter(color: _kSub, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = lista[index];
        final hitos = p['hitos_proyecto'] as List<dynamic>? ?? [];
        final totalHitos = hitos.length;
        final hitosCompletos =
            hitos.where((h) => h['completado'] == true).length;
        final avance = totalHitos > 0 ? (hitosCompletos / totalHitos) : 0.0;
        final estado = (p['estado'] ?? 'En Proceso').toString();
        final cliente = p['clientes']?['razon_social'] ?? 'Sin cliente';
        final codigo = p['codigo_proyecto'] ?? 'S/C';

        Color badgeColor;
        switch (estado) {
          case 'Completado':
            badgeColor = _kTeal;
            break;
          case 'En Proceso':
            badgeColor = _kBlue;
            break;
          case 'Pausado':
            badgeColor = _kAmber;
            break;
          case 'Cancelado':
            badgeColor = _kRed;
            break;
          default:
            badgeColor = _kCyan;
        }

        return Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kDivider),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            title: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    codigo,
                    style: GoogleFonts.inter(
                      color: _kCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p['nombre_obra'] ?? 'Sin nombre',
                    style: GoogleFonts.inter(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  cliente,
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: avance,
                          backgroundColor: _kDivider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            avance == 1.0 ? _kTeal : _kBlue,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(avance * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        color: _kText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                estado,
                style: GoogleFonts.inter(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProyectoDetailScreen(proyecto: p, user: widget.user),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Error desconocido',
              style: GoogleFonts.inter(color: _kText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
            ),
          ],
        ),
      ),
    );
  }
}
