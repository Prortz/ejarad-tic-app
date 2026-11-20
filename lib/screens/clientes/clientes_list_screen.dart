// lib/screens/clientes/clientes_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';
import 'cliente_detalle_screen.dart';

const _cBg      = Color(0xFF060C18);
const _cSurface = Color(0xFF0D1526);
const _cCard    = Color(0xFF111F35);
const _cCyan    = Color(0xFF00ACC1);
const _cText    = Colors.white;
const _cSub     = Color(0xFF8899AA);
const _cDivider = Color(0xFF1A2840);

class ClientesListScreen extends StatefulWidget {
  final Perfil user;
  const ClientesListScreen({super.key, required this.user});
  @override
  State<ClientesListScreen> createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> {
  final _svc = SupabaseService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final data = await _svc.getClientes();
      setState(() { _clientes = data; _filtrados = data; _cargando = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtrados = _clientes.where((c) {
        final razon = (c['razon_social'] ?? '').toLowerCase();
        final ruc   = (c['ruc_cliente'] ?? '').toLowerCase();
        return razon.contains(q) || ruc.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cSurface,
        title: Row(children: [
          const Icon(Icons.business_outlined, color: _cCyan, size: 20),
          const SizedBox(width: 8),
          Text('Clientes', style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700, color: _cText)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _cDivider),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh, color: _cCyan),
            onPressed: _cargar,
          ),
        ],
      ),
      body: Column(children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(color: _cText, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, RUC o DNI...',
              hintStyle: GoogleFonts.inter(color: _cSub, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: _cCyan, size: 20),
              filled: true, fillColor: _cCard,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _cCyan.withValues(alpha: 0.2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _cCyan)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ),
        // Contador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${_filtrados.length} cliente${_filtrados.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 12, color: _cSub)),
          ]),
        ),
        // Lista
        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _cCyan,
        onPressed: () => _mostrarFormNuevoCliente(context),
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text('Nuevo cliente',
            style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: _cCyan));
    if (_error != null) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 10),
        Text(_error!, style: GoogleFonts.inter(color: _cSub, fontSize: 13)),
        const SizedBox(height: 14),
        TextButton(onPressed: _cargar,
            child: Text('Reintentar', style: GoogleFonts.inter(color: _cCyan))),
      ]),
    );
    if (_filtrados.isEmpty) return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.business_center_outlined, color: _cSub.withValues(alpha: 0.4), size: 56),
        const SizedBox(height: 12),
        Text('Sin clientes registrados',
            style: GoogleFonts.inter(fontSize: 15, color: _cSub)),
        const SizedBox(height: 6),
        Text('Toca + para agregar el primero',
            style: GoogleFonts.inter(fontSize: 13, color: _cSub.withValues(alpha: 0.6))),
      ]),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ClienteCard(
        cliente: _filtrados[i],
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => ClienteDetalleScreen(
              clienteId: _filtrados[i]['id'],
              user: widget.user,
            ),
          ));
          _cargar(); // Refrescar al volver
        },
      ),
    );
  }

  void _mostrarFormNuevoCliente(BuildContext ctx) {
    final formKey = GlobalKey<FormState>();
    final rucCtrl = TextEditingController();
    final razonCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final ctaCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: _cSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(bCtx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _cDivider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nuevo Cliente B2B',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _cText)),
                const SizedBox(height: 16),
                AppField(
                  label: 'RUC o DNI',
                  controller: rucCtrl,
                  hint: '8 u 11 dígitos numéricos',
                  prefixIcon: Icons.badge_outlined,
                  inputFormatters: [Formatters.digitos(11)],
                  validator: Validators.rucODni,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                AppField(
                  label: 'Razón Social',
                  controller: razonCtrl,
                  hint: 'Nombre de la empresa o cliente',
                  prefixIcon: Icons.business_outlined,
                  inputFormatters: [Formatters.texto],
                  validator: (v) {
                    final req = Validators.requerido(v);
                    if (req != null) return req;
                    return Validators.textoMin(3)(v);
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                AppField(
                  label: 'Nombre de Contacto',
                  controller: ctaCtrl,
                  hint: 'Persona de contacto autorizada',
                  prefixIcon: Icons.person_outline,
                  inputFormatters: [Formatters.letras],
                  validator: (v) {
                    final req = Validators.requerido(v);
                    if (req != null) return req;
                    return Validators.soloLetras(v);
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppField(
                      label: 'Teléfono / Celular',
                      controller: telCtrl,
                      hint: '9 dígitos (9xxxxxxx)',
                      prefixIcon: Icons.phone_outlined,
                      inputFormatters: [Formatters.digitos(9)],
                      validator: Validators.celular,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppField(
                      label: 'Correo Electrónico',
                      controller: correoCtrl,
                      hint: 'cliente@correo.com',
                      prefixIcon: Icons.email_outlined,
                      inputFormatters: [Formatters.correo],
                      validator: Validators.correo,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _cCyan,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: guardando
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setS(() => guardando = true);
                            try {
                              await _svc.crearCliente(
                                ruc: rucCtrl.text.trim(),
                                razonSocial: razonCtrl.text.trim(),
                                contacto: ctaCtrl.text.trim(),
                                telefono: telCtrl.text.trim(),
                                correo: correoCtrl.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(bCtx);
                              _cargar();
                            } catch (e) {
                              setS(() => guardando = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red));
                              }
                            }
                          },
                    child: Text(guardando ? 'Guardando...' : 'Guardar Cliente',
                        style: GoogleFonts.inter(
                            color: Colors.black, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Card de cliente en la lista
// ════════════════════════════════════════════════
class _ClienteCard extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final VoidCallback onTap;
  const _ClienteCard({required this.cliente, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final razon = cliente['razon_social'] ?? 'Sin nombre';
    final ruc   = cliente['ruc_cliente'] ?? '—';
    final tel   = cliente['telefono'] ?? '';
    final initials = razon.isNotEmpty ? razon[0].toUpperCase() : '?';

    return Material(
      color: _cCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _cCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cCyan.withValues(alpha: 0.3)),
              ),
              child: Center(child: Text(initials,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800, color: _cCyan))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(razon, style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _cText),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('RUC/DNI: $ruc', style: GoogleFonts.inter(fontSize: 12, color: _cSub)),
              if (tel.isNotEmpty)
                Text(tel, style: GoogleFonts.inter(fontSize: 12, color: _cSub)),
            ])),
            const Icon(Icons.chevron_right, color: _cCyan, size: 20),
          ]),
        ),
      ),
    );
  }
}

