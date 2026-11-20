// lib/screens/proyectos/proyectos_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/sync_status_chip.dart';
import 'proyecto_detail_screen.dart';

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

class ProyectosListScreen extends StatefulWidget {
  final Perfil? user;
  const ProyectosListScreen({super.key, this.user});

  @override
  State<ProyectosListScreen> createState() => _ProyectosListScreenState();
}

class _ProyectosListScreenState extends State<ProyectosListScreen> {
  final _service = SupabaseService.instance;
  List<Map<String, dynamic>> _proyectos = [];
  bool _cargando = true;

  String _filtroTexto = '';
  String _filtroEstado = 'Todos';

  Perfil get _usuarioActual =>
      widget.user ?? AuthService.instance.perfil ?? Perfil.vacio;

  @override
  void initState() {
    super.initState();
    _cargarProyectos();
  }

  Future<void> _cargarProyectos() async {
    setState(() => _cargando = true);
    try {
      final data =
          await _service.getProyectosParaPerfil(_usuarioActual);
      if (mounted) {
        setState(() {
          _proyectos = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar obras: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _proyectosFiltrados {
    return _proyectos.where((p) {
      final query = _filtroTexto.trim().toLowerCase();
      if (query.isNotEmpty) {
        final obra = (p['nombre_obra'] ?? '').toString().toLowerCase();
        final cod = (p['codigo_proyecto'] ?? '').toString().toLowerCase();
        final cli =
            (p['clientes']?['razon_social'] ?? '').toString().toLowerCase();
        if (!obra.contains(query) && !cod.contains(query) && !cli.contains(query)) {
          return false;
        }
      }

      final estado = (p['estado'] ?? '').toString();
      if (_filtroEstado != 'Todos' && estado != _filtroEstado) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _proyectosFiltrados;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          _usuarioActual.puedeGestionar ? 'Gestión de Obras' : 'Mis Obras Asignadas',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          const SyncStatusChip(),
          IconButton(
            icon: const Icon(Icons.refresh, color: _kCyan),
            onPressed: _cargarProyectos,
            tooltip: 'Recargar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _kCyan))
          : Column(
              children: [
                _buildBarraFiltros(),
                Expanded(
                  child: filtrados.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: _kCyan,
                          backgroundColor: _kSurface,
                          onRefresh: _cargarProyectos,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtrados.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = filtrados[index];
                              final estado = p['estado'] ?? 'En Proceso';
                              final hitos =
                                  p['hitos_proyecto'] as List<dynamic>? ?? [];
                              final totalHitos = hitos.length;
                              final completos = hitos
                                  .where((h) => h['completado'] == true)
                                  .length;
                              final avance = totalHitos > 0
                                  ? completos / totalHitos
                                  : 0.0;
                              final cliente = p['clientes']?['razon_social'] ??
                                  'Sin cliente';

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
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _kDivider),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProyectoDetailScreen(
                                          proyecto: p,
                                          user: _usuarioActual,
                                        ),
                                      ),
                                    ).then((_) => _cargarProyectos());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _kBlue
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                p['codigo_proyecto'] ?? 'S/C',
                                                style: GoogleFonts.inter(
                                                  color: _kCyan,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: badgeColor
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: badgeColor
                                                        .withValues(alpha: 0.4)),
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
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          p['nombre_obra'] ?? 'Sin nombre',
                                          style: GoogleFonts.inter(
                                            color: _kText,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cliente,
                                          style: GoogleFonts.inter(
                                              color: _kSub, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: avance,
                                                  backgroundColor: _kDivider,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    avance == 1.0
                                                        ? _kTeal
                                                        : _kBlue,
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarraFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kDivider)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _filtroTexto = v),
            style: GoogleFonts.inter(color: _kText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar obra por nombre, código o cliente...',
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip('Todos'),
                const SizedBox(width: 6),
                _buildChip('En Proceso'),
                const SizedBox(width: 6),
                _buildChip('Pendiente'),
                const SizedBox(width: 6),
                _buildChip('Completado'),
                const SizedBox(width: 6),
                _buildChip('Pausado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String estado) {
    final sel = _filtroEstado == estado;
    return ChoiceChip(
      label: Text(
        estado,
        style: GoogleFonts.inter(
          color: sel ? Colors.white : _kSub,
          fontSize: 11,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: sel,
      onSelected: (_) => setState(() => _filtroEstado = estado),
      selectedColor: _kBlue,
      backgroundColor: _kCard,
      side: BorderSide(color: sel ? _kBlue : _kDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alt_route_rounded, size: 54, color: _kSub),
            const SizedBox(height: 12),
            Text(
              'Sin obras encontradas',
              style: GoogleFonts.inter(
                color: _kText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _usuarioActual.puedeGestionar
                  ? 'Apruebe una cotización paramétrica para generar una nueva obra.'
                  : 'Aún no se le han asignado órdenes de trabajo en el sistema.',
              style: GoogleFonts.inter(color: _kSub, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
