import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../cotizador/cotizador_screen.dart';
import '../proyectos/proyectos_list_screen.dart';
import '../catalogo/catalogo_screen.dart';
import '../welcome/welcome_screen.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

// ──────────────────────────────────────────────
// Paleta tech oscura
// ──────────────────────────────────────────────
const _kBg          = Color(0xFF080D1A);
const _kSurface     = Color(0xFF111827);
const _kCard        = Color(0xFF1A2236);
const _kBlue        = Color(0xFF2979FF);
const _kCyan        = Color(0xFF00E5FF);
const _kTeal        = Color(0xFF00BFA5);
const _kIndigo      = Color(0xFF7C3AED);
const _kText        = Colors.white;
const _kSubtext     = Color(0xFF8899AA);
const _kDivider     = Color(0xFF1E2D45);

class HomeScreen extends StatelessWidget {
  final Perfil? user;
  const HomeScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kCyan,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Control Técnico',
              style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kText),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tarjeta de usuario ──────────────────
            _UserCard(user: user),
            const SizedBox(height: 26),

            // ── Título sección opciones ─────────────
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Panel de Operaciones',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kSubtext,
                          letterSpacing: 0.8)),
                ],
              ),
            ),

            // ── Opciones del menú según rol ───────────────────
            if (user?.puedeGestionar ?? false) ...[
              _MenuCard(
                title: 'Cotizador Paramétrico',
                subtitle: 'ANSI/TIA-568 · Desglose BOM',
                icon: Icons.calculate_outlined,
                accentColor: _kBlue,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CotizadorScreen())),
              ),
              const SizedBox(height: 12),
            ],
            _MenuCard(
              title: (user?.puedeGestionar ?? false)
                  ? 'Gestión de Obras'
                  : 'Mis Obras Asignadas',
              subtitle: 'Hitos técnicos · Trazabilidad GPS / QR / Fotos',
              icon: Icons.alt_route_rounded,
              accentColor: _kTeal,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProyectosListScreen(user: user))),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              title: (user?.puedeGestionar ?? false)
                  ? 'Catálogo de Precios'
                  : 'Catálogo de Precios (Lectura)',
              subtitle: (user?.puedeGestionar ?? false)
                  ? 'Costos base · Precios unitarios'
                  : 'Consulta de insumos y materiales',
              icon: Icons.sell_outlined,
              accentColor: _kIndigo,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CatalogoScreen(user: user))),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// TARJETA DE USUARIO
// ══════════════════════════════════════════════
class _UserCard extends StatelessWidget {
  final Perfil? user;
  const _UserCard({this.user});

  @override
  Widget build(BuildContext context) {
    final name   = user?.nombre ?? 'Técnico';
    final userCode = user?.codigo ?? 'EJR-0000';
    final initials = _initials(name);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B3E), Color(0xFF1A2A55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _kBlue.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con logo empresa
          Row(
            children: [
              Text('EJARAD TIC',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kCyan,
                      letterSpacing: 2)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _kBlue.withValues(alpha: 0.5), width: 1),
                ),
                child: Text('TECH',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                        letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: _kCyan, size: 20),
                onPressed: () async {
                  await AuthService.instance.cerrarSesion();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Avatar + datos
          Row(
            children: [
              // Avatar con iniciales
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kBlue, Color(0xFF00B0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(initials,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kText),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 12, color: _kCyan),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(userCode,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _kSubtext,
                                  letterSpacing: 1),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge activo
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00BFA5))),
                    const SizedBox(width: 5),
                    Text('ACTIVO',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00BFA5),
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          // Separador
          Container(height: 1, color: _kBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 14),

          // Pie de tarjeta
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 14, color: _kSubtext),
              const SizedBox(width: 6),
              Text('Campo · Redes · Infraestructura',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _kSubtext, letterSpacing: 0.4)),
              const Spacer(),
              Text('v1.0', style: GoogleFonts.inter(fontSize: 11, color: _kSubtext)),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

// ══════════════════════════════════════════════
// TARJETA DE MENÚ (opción)
// ══════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: accentColor.withValues(alpha: 0.2), width: 1),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Ícono con fondo accent
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kText)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _kSubtext)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 15, color: accentColor.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

