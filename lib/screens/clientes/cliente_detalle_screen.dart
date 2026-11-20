// lib/screens/clientes/cliente_detalle_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';

const _dBg      = Color(0xFF060C18);
const _dSurface = Color(0xFF0D1526);
const _dCard    = Color(0xFF111F35);
const _dCyan    = Color(0xFF00ACC1);
const _dBlue    = Color(0xFF2979FF);
const _dTeal    = Color(0xFF00BFA5);
const _dText    = Colors.white;
const _dSub     = Color(0xFF8899AA);
const _dDivider = Color(0xFF1A2840);

class ClienteDetalleScreen extends StatefulWidget {
  final String clienteId;
  final Perfil user;
  const ClienteDetalleScreen({
    super.key, required this.clienteId, required this.user});
  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  final _svc = SupabaseService();
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _proyectos = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final c = await _svc.getClienteDetalle(widget.clienteId);
      final p = await _svc.getProyectosPorCliente(widget.clienteId);
      setState(() { _cliente = c; _proyectos = p; _cargando = false; });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dBg,
      appBar: AppBar(
        backgroundColor: _dSurface,
        title: Text(_cliente?['razon_social'] ?? 'Ficha de Cliente',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _dText)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _dDivider)),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _dCyan))
          : _cliente == null
          ? Center(child: Text('No se encontró el cliente',
              style: GoogleFonts.inter(color: _dSub)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _avatarHeader(),
                const SizedBox(height: 18),
                _seccion('DATOS GENERALES', Icons.badge_outlined),
                const SizedBox(height: 10),
                _datoCard(),
                const SizedBox(height: 20),
                _seccion('PROYECTOS ASOCIADOS', Icons.account_tree_outlined),
                const SizedBox(height: 6),
                Text(
                  'El detalle técnico de cada proyecto está en el módulo de Operaciones.',
                  style: GoogleFonts.inter(fontSize: 11, color: _dSub),
                ),
                const SizedBox(height: 10),
                if (_proyectos.isEmpty)
                  _emptyProyectos()
                else
                  ..._proyectos.map(_proyectoChip),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _avatarHeader() {
    final razon = _cliente!['razon_social'] ?? '';
    final initial = razon.isNotEmpty ? razon[0].toUpperCase() : '?';
    return Row(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF006064), _dCyan],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: Text(initial,
            style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(razon, style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w800, color: _dText)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _dTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _dTeal.withValues(alpha: 0.35)),
          ),
          child: Text('${_proyectos.length} proyecto${_proyectos.length == 1 ? '' : 's'}',
              style: GoogleFonts.inter(fontSize: 11, color: _dTeal, fontWeight: FontWeight.w600)),
        ),
      ])),
    ]);
  }

  Widget _datoCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _dCard, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _dCyan.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      _fila(Icons.badge_outlined, 'RUC / DNI', _cliente!['ruc_cliente'] ?? '—'),
      _divider(),
      _fila(Icons.person_outline, 'Contacto', _cliente!['contacto_nombre'] ?? '—'),
      _divider(),
      _fila(Icons.phone_outlined, 'Teléfono', _cliente!['telefono'] ?? '—'),
      _divider(),
      _fila(Icons.email_outlined, 'Correo', _cliente!['correo'] ?? '—'),
    ]),
  );

  Widget _fila(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: _dCyan, size: 18),
      const SizedBox(width: 10),
      Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: _dSub)),
      Expanded(child: Text(value,
          style: GoogleFonts.inter(fontSize: 13, color: _dText, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _divider() =>
      Divider(height: 1, color: _dDivider);

  Widget _seccion(String label, IconData icon) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: _dCyan, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Icon(icon, color: _dCyan, size: 16),
    const SizedBox(width: 6),
    Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: _dSub, letterSpacing: 1.1)),
  ]);

  Widget _emptyProyectos() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _dCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dDivider)),
    child: Center(child: Text('Sin proyectos registrados aún',
        style: GoogleFonts.inter(fontSize: 13, color: _dSub))),
  );

  Widget _proyectoChip(Map<String, dynamic> p) {
    final estado = p['estado'] ?? '—';
    final Color estadoColor = estado == 'En Proceso'
        ? _dTeal : estado == 'Finalizado' ? _dBlue : _dSub;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _dCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: estadoColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['codigo_proyecto'] ?? '—',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _dText)),
          const SizedBox(height: 3),
          Text(p['nombre_obra'] ?? '',
              style: GoogleFonts.inter(fontSize: 12, color: _dSub),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: estadoColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(estado, style: GoogleFonts.inter(
              fontSize: 11, color: estadoColor, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

