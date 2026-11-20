// lib/screens/modulos/modulos_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/catalogo_repository.dart';
import '../../services/sync_service.dart';
import '../../widgets/sync_status_chip.dart';
import '../home/home_screen.dart';
import '../clientes/clientes_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../usuarios/usuarios_list_screen.dart';
import '../welcome/welcome_screen.dart';

const _kBg      = Color(0xFF060C18);
const _kSurface = Color(0xFF0D1526);
const _kCard    = Color(0xFF111F35);
const _kBlue    = Color(0xFF2979FF);
const _kCyan    = Color(0xFF00E5FF);
const _kTeal    = Color(0xFF00BFA5);
const _kViolet  = Color(0xFF7C3AED);
const _kAmber   = Color(0xFFFFB300);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8899AA);
const _kDivider = Color(0xFF1A2840);

class ModulosScreen extends StatefulWidget {
  final Perfil user;
  const ModulosScreen({super.key, required this.user});

  @override
  State<ModulosScreen> createState() => _ModulosScreenState();
}

class _ModulosScreenState extends State<ModulosScreen> {
  Perfil get user => widget.user;

  @override
  void initState() {
    super.initState();
    // Offline-first: descarga inicial del catálogo y arranque de la
    // sincronización en segundo plano (store-and-forward).
    CatalogoRepository.instance.precargar();
    SyncService.instance.iniciar();
  }

  String get _descripcionRol {
    switch (user.rol) {
      case 'Admin':
        return '${user.cargo} — Administrador';
      case 'Supervisor':
        return '${user.cargo} — Supervisor';
      default:
        return '${user.cargo} — Técnico';
    }
  }

  Color get _rolColor => user.esAdmin
      ? const Color(0xFFFF6B35)
      : user.esSupervisor
          ? _kBlue
          : _kTeal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildUserCard(),
                  const SizedBox(height: 28),
                  _sectionLabel('MÓDULOS DEL SISTEMA'),
                  const SizedBox(height: 14),
                  if (user.puedeGestionar) ...[
                    _ModuloCard(
                      titulo: 'Dashboard',
                      subtitulo: 'Indicadores · Obras · Actas pendientes',
                      icono: Icons.insights_outlined,
                      gradientColors: const [Color(0xFF8E24AA), Color(0xFFE040FB)],
                      accentColor: const Color(0xFFE040FB),
                      badges: const ['Monitoreo', 'Filtros', 'KPIs'],
                      onTap: () => Navigator.push(
                          context, _fade(DashboardScreen(user: user))),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _ModuloCard(
                    titulo: 'Operaciones',
                    subtitulo: user.puedeGestionar
                        ? 'Cotizador · Proyectos · Catálogo de precios'
                        : 'Mis obras asignadas · Trazabilidad · Catálogo (lectura)',
                    icono: Icons.account_tree_outlined,
                    gradientColors: const [Color(0xFF1565C0), Color(0xFF2979FF)],
                    accentColor: _kBlue,
                    badges: user.puedeGestionar
                        ? const ['Cotizaciones', 'Proyectos', 'Catálogo']
                        : const ['Mis obras', 'GPS · QR · Fotos', 'Firma'],
                    onTap: () => Navigator.push(
                        context, _fade(HomeScreen(user: user))),
                  ),
                  if (user.puedeGestionar) ...[
                    const SizedBox(height: 14),
                    _ModuloCard(
                      titulo: 'Clientes',
                      subtitulo: 'Registro · Ficha · Proyectos asociados',
                      icono: Icons.business_outlined,
                      gradientColors: const [Color(0xFF006064), Color(0xFF00ACC1)],
                      accentColor: _kCyan,
                      badges: const ['Lista', 'Ficha', 'Historial'],
                      onTap: () => Navigator.push(
                          context, _fade(ClientesListScreen(user: user))),
                    ),
                    const SizedBox(height: 14),
                    _ModuloCard(
                      titulo: 'Usuarios',
                      subtitulo: user.esAdmin
                          ? 'Trabajadores · Roles · Contratos'
                          : 'Personal (solo lectura)',
                      icono: Icons.people_alt_outlined,
                      gradientColors: const [Color(0xFF4A148C), Color(0xFF7C3AED)],
                      accentColor: _kViolet,
                      badges: const ['Personal', 'Roles', 'Contratos'],
                      onTap: () => Navigator.push(
                          context, _fade(UsuariosListScreen(user: user))),
                    ),
                  ],
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kCard, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kDivider),
                      ),
                      child: Text('EJARAD TIC v1.0',
                          style: GoogleFonts.inter(fontSize: 11, color: _kSub)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
    decoration: const BoxDecoration(
      color: _kSurface,
      border: Border(bottom: BorderSide(color: _kDivider)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kBlue, _kCyan],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.router_outlined, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EJARAD TIC', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: _kText, letterSpacing: 1.2)),
          Text('Sistema de Trazabilidad',
              style: GoogleFonts.inter(fontSize: 11, color: _kSub)),
        ]),
      ),
      const SyncStatusChip(),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _rolColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _rolColor.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: _rolColor, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(user.rol, style: GoogleFonts.inter(
              fontSize: 11, color: _rolColor, fontWeight: FontWeight.w600)),
        ]),
      ),
      IconButton(
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout, color: _kCyan, size: 20),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: _kCard,
              title: Text('Cerrar sesión', style: GoogleFonts.inter(color: _kText)),
              content: Text(
                SyncService.instance.pendientes.value > 0
                    ? 'Tienes ${SyncService.instance.pendientes.value} evidencia(s) sin sincronizar. '
                      'Se conservarán en el dispositivo y se enviarán cuando vuelvas a iniciar sesión con conexión.'
                    : '¿Deseas salir de tu cuenta?',
                style: GoogleFonts.inter(color: _kSub, fontSize: 13),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Salir')),
              ],
            ),
          );
          if (ok != true) return;
          await AuthService.instance.cerrarSesion();
          await SyncService.instance.refrescarContador();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        },
      ),
    ]),
  );

  Widget _buildUserCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B3E), Color(0xFF132040)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kBlue, _kCyan],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(
          user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        )),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(user.nombreCompleto, style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: _kText),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(_descripcionRol,
            style: GoogleFonts.inter(fontSize: 12, color: _kSub),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBlue.withValues(alpha: 0.35)),
          ),
          child: Text('ID: ${user.codigo}', style: GoogleFonts.inter(
              fontSize: 10, color: _kBlue,
              fontWeight: FontWeight.w600, letterSpacing: 0.5),
              overflow: TextOverflow.ellipsis),
        ),
      ])),
      Icon(user.esTecnico ? Icons.engineering_outlined : Icons.shield_outlined,
          color: user.esTecnico ? _kAmber : _kBlue, size: 22),
    ]),
  );

  Widget _sectionLabel(String label) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 1.2)),
  ]);

  PageRouteBuilder _fade(Widget screen) => PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, anim, secondaryAnim, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 250),
  );
}

// ════════════════════════════════════════════════
// Widget de Módulo con animación de press
// ════════════════════════════════════════════════
class _ModuloCard extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final List<Color> gradientColors;
  final Color accentColor;
  final List<String> badges;
  final VoidCallback onTap;
  const _ModuloCard({
    required this.titulo, required this.subtitulo, required this.icono,
    required this.gradientColors, required this.accentColor,
    required this.badges, required this.onTap,
  });
  @override
  State<_ModuloCard> createState() => _ModuloCardState();
}

class _ModuloCardState extends State<_ModuloCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.965)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
              color: widget.gradientColors[1].withValues(alpha: 0.08),
              blurRadius: 24, offset: const Offset(0, 8),
            )],
          ),
          child: Column(children: [
            // Banda superior con gradiente
            Container(
              height: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: widget.gradientColors),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradientColors,
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(widget.icono, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.titulo, style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _kText)),
                      const SizedBox(height: 3),
                      Text(widget.subtitulo, style: GoogleFonts.inter(
                          fontSize: 12, color: _kSub, height: 1.4)),
                    ],
                  )),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: widget.accentColor, size: 16),
                ]),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: widget.badges.map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: widget.accentColor.withValues(alpha: 0.28)),
                    ),
                    child: Text(b, style: GoogleFonts.inter(
                        fontSize: 11, color: widget.accentColor,
                        fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
