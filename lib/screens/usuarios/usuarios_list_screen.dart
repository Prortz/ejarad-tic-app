// lib/screens/usuarios/usuarios_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'usuario_form_screen.dart';

const _uBg      = Color(0xFF060C18);
const _uSurface = Color(0xFF0D1526);
const _uCard    = Color(0xFF111F35);
const _uViolet  = Color(0xFF7C3AED);
const _uTeal    = Color(0xFF00BFA5);
const _uText    = Colors.white;
const _uSub     = Color(0xFF8899AA);
const _uDivider = Color(0xFF1A2840);

class UsuariosListScreen extends StatefulWidget {
  final Perfil user;
  const UsuariosListScreen({super.key, required this.user});
  @override
  State<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends State<UsuariosListScreen> {
  String _filtroRol = 'Todos';
  final _roles = ['Todos', 'Admin', 'Técnico', 'Supervisor'];
  
  bool _isLoading = true;
  List<Perfil> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.instance.listarPerfiles();
      setState(() => _usuarios = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Perfil> get _filtrados => _filtroRol == 'Todos'
      ? _usuarios
      : _usuarios.where((u) => u.rol == _filtroRol).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _uBg,
      appBar: AppBar(
        backgroundColor: _uSurface,
        title: Row(children: [
          const Icon(Icons.people_alt_outlined, color: _uViolet, size: 20),
          const SizedBox(width: 8),
          Text('Usuarios', style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700, color: _uText)),
        ]),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _uDivider)),
      ),
      body: Column(children: [
        // Filtro de roles
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _roles.map((r) {
                final sel = _filtroRol == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filtroRol = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? _uViolet : _uCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? _uViolet : _uDivider),
                      ),
                      child: Text(r, style: GoogleFonts.inter(
                          fontSize: 12, color: sel ? _uText : _uSub,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _uViolet))
              : _filtrados.isEmpty
                  ? Center(child: Text('No hay usuarios.', style: GoogleFonts.inter(color: _uSub)))
                  : RefreshIndicator(
                      color: _uViolet,
                      onRefresh: _cargarUsuarios,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: _filtrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => GestureDetector(
                          onTap: () async {
                            if (!widget.user.esAdmin) return;
                            final refresh = await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => UsuarioFormScreen(perfilExistente: _filtrados[i])
                            ));
                            if (refresh == true) _cargarUsuarios();
                          },
                          child: _UsuarioCard(usuario: _filtrados[i]),
                        ),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: widget.user.esAdmin ? FloatingActionButton.extended(
        backgroundColor: _uViolet,
        onPressed: () async {
          final refresh = await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const UsuarioFormScreen()));
          if (refresh == true) _cargarUsuarios();
        },
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: Text('Nuevo usuario',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
      ) : null,
    );
  }
}

// ════════════════════════════════════════════════
// Card de usuario
// ════════════════════════════════════════════════
class _UsuarioCard extends StatelessWidget {
  final Perfil usuario;
  const _UsuarioCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final nombre = usuario.nombreCompleto;
    final userId = usuario.codigo;
    final cargo  = usuario.cargo;
    final rol    = usuario.rol;
    final activo = usuario.activo;
    final initial = usuario.iniciales;

    final Color rolColor = rol == 'Admin' ? const Color(0xFFFF6B35)
        : rol == 'Supervisor' ? const Color(0xFF2979FF)
        : _uTeal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _uCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _uDivider),
      ),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _uViolet.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _uViolet.withValues(alpha: 0.35)),
            ),
            child: Center(child: Text(initial, style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _uViolet))),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: activo ? _uTeal : _uSub,
                shape: BoxShape.circle,
                border: Border.all(color: _uCard, width: 2),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: _uText)),
          const SizedBox(height: 2),
          Text(cargo, style: GoogleFonts.inter(fontSize: 12, color: _uSub)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: rolColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(rol, style: GoogleFonts.inter(
                  fontSize: 10, color: rolColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Text('· Código: $userId',
                style: GoogleFonts.inter(fontSize: 10, color: _uSub)),
          ]),
        ])),
        Icon(activo ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: activo ? _uTeal : _uSub, size: 20),
      ]),
    );
  }
}

