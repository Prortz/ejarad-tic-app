// lib/screens/usuarios/usuario_form_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_field.dart';

const _fBg = Color(0xFF060C18);
const _fSurface = Color(0xFF0D1526);
const _fCard = Color(0xFF111F35);
const _fViolet = Color(0xFF7C3AED);
const _fCyan = Color(0xFF00E5FF);
const _fText = Colors.white;
const _fSub = Color(0xFF8899AA);
const _fDivider = Color(0xFF1A2840);

class UsuarioFormScreen extends StatefulWidget {
  final Perfil? perfilExistente;
  const UsuarioFormScreen({super.key, this.perfilExistente});
  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _cargo = 'Técnico de Campo';
  String _rol = 'Técnico';
  bool _activo = true;
  String _codigoUsuario = '';
  bool _isSaving = false;

  final _cargos = const [
    'Técnico de Campo',
    'Técnico Senior',
    'Jefe de Proyectos',
    'Administrador'
  ];
  final _roles = const ['Técnico', 'Supervisor', 'Admin'];

  @override
  void initState() {
    super.initState();
    _nombreCtrl.addListener(_generarId);
    _apellidoCtrl.addListener(_generarId);
    if (widget.perfilExistente != null) {
      final p = widget.perfilExistente!;
      _nombreCtrl.text = p.nombre;
      _apellidoCtrl.text = p.apellido ?? '';
      _dniCtrl.text = p.dni ?? '';
      _telCtrl.text = p.telefono ?? '';
      _correoCtrl.text = p.correo ?? '';
      _cargo = _cargos.contains(p.cargo) ? p.cargo : 'Técnico de Campo';
      _rol = _roles.contains(p.rol) ? p.rol : 'Técnico';
      _activo = p.activo;
      _codigoUsuario = p.codigo;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl,
      _apellidoCtrl,
      _dniCtrl,
      _telCtrl,
      _correoCtrl,
      _passwordCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generarId() {
    if (widget.perfilExistente != null) return;
    final gen = Perfil.generarCodigo(_nombreCtrl.text, _apellidoCtrl.text);
    if (gen.isNotEmpty) {
      setState(() => _codigoUsuario = gen);
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final esEdicion = widget.perfilExistente != null;
    if (!esEdicion && _passwordCtrl.text.length < 6) {
      mostrarError(context, 'Contraseña mínimo 6 caracteres');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (esEdicion) {
        await AuthService.instance.actualizarUsuario(
          userId: widget.perfilExistente!.userId,
          email: _correoCtrl.text.trim(),
          password:
              _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text.trim() : null,
          nombre: _nombreCtrl.text.trim(),
          apellido: _apellidoCtrl.text.trim(),
          dni: _dniCtrl.text.trim(),
          telefono: _telCtrl.text.trim(),
          cargo: _cargo,
          rol: _rol,
          codigoUsuario: _codigoUsuario,
          activo: _activo,
        );
      } else {
        await AuthService.instance.crearUsuario(
          email: _correoCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          nombre: _nombreCtrl.text.trim(),
          apellido: _apellidoCtrl.text.trim(),
          dni: _dniCtrl.text.trim(),
          telefono: _telCtrl.text.trim(),
          cargo: _cargo,
          rol: _rol,
          codigoUsuario: _codigoUsuario,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        mostrarError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.perfilExistente != null;

    return Scaffold(
      backgroundColor: _fBg,
      appBar: AppBar(
        backgroundColor: _fSurface,
        elevation: 0,
        title: Text(
          esEdicion ? 'Editar Personal' : 'Nuevo Usuario Corporativo',
          style: GoogleFonts.inter(
            color: _fText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _fDivider),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (_codigoUsuario.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _fViolet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: _fViolet.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: _fViolet, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CÓDIGO IDENTIFICADOR EJARAD',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: _fSub,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        Text(_codigoUsuario,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: _fCyan,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            _seccion('ACCESO Y CREDENCIALES'),
            const SizedBox(height: 10),
            AppField(
              label: 'Correo electrónico corporativo',
              controller: _correoCtrl,
              hint: 'usuario@ejarad.com',
              prefixIcon: Icons.email_outlined,
              enabled: !esEdicion,
              inputFormatters: [Formatters.correo],
              validator: Validators.correo,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            AppField(
              label: esEdicion ? 'Nueva Contraseña (opcional)' : 'Contraseña de Acceso',
              controller: _passwordCtrl,
              hint: 'Mínimo 6 caracteres',
              prefixIcon: Icons.lock_outline,
              isObscure: true,
              validator: esEdicion ? null : Validators.password,
            ),

            const SizedBox(height: 20),
            _seccion('DATOS PERSONALES'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: AppField(
                  label: 'Nombres',
                  controller: _nombreCtrl,
                  hint: 'Ej. Juan Carlos',
                  prefixIcon: Icons.person_outline,
                  inputFormatters: [Formatters.letras],
                  validator: (v) {
                    final req = Validators.requerido(v);
                    if (req != null) return req;
                    return Validators.soloLetras(v);
                  },
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppField(
                  label: 'Apellidos',
                  controller: _apellidoCtrl,
                  hint: 'Ej. Pérez Ruiz',
                  prefixIcon: Icons.person_outline,
                  inputFormatters: [Formatters.letras],
                  validator: (v) {
                    final req = Validators.requerido(v);
                    if (req != null) return req;
                    return Validators.soloLetras(v);
                  },
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: AppField(
                  label: 'DNI',
                  controller: _dniCtrl,
                  hint: '8 dígitos exactos',
                  prefixIcon: Icons.badge_outlined,
                  inputFormatters: [Formatters.digitos(8)],
                  validator: Validators.dni,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppField(
                  label: 'Teléfono Celular',
                  controller: _telCtrl,
                  hint: '9 dígitos (9xxxxxxx)',
                  prefixIcon: Icons.phone_outlined,
                  inputFormatters: [Formatters.digitos(9)],
                  validator: Validators.celular,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ]),

            const SizedBox(height: 20),
            _seccion('ROL Y CARGO'),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _fCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _cargo,
                  isExpanded: true,
                  dropdownColor: _fCard,
                  icon: const Icon(Icons.keyboard_arrow_down, color: _fViolet),
                  style: GoogleFonts.inter(color: _fText, fontSize: 14),
                  items: _cargos
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _cargo = v!),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _roles.map((r) {
                final sel = _rol == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _rol = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _fViolet : _fCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? _fViolet : _fDivider),
                      ),
                      child: Text(
                        r,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: sel ? _fText : _fSub,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _seccion('ESTADO'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _fCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fDivider),
              ),
              child: Row(children: [
                const Icon(Icons.toggle_on_outlined,
                    color: _fViolet, size: 20),
                const SizedBox(width: 10),
                Text('Usuario activo',
                    style: GoogleFonts.inter(fontSize: 14, color: _fText)),
                const Spacer(),
                Switch.adaptive(
                  value: _activo,
                  activeThumbColor: _fViolet,
                  onChanged: (v) => setState(() => _activo = v),
                ),
              ]),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _fViolet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _guardar,
                child: Text(
                  _isSaving
                      ? 'Guardando...'
                      : (esEdicion ? 'Actualizar Personal' : 'Crear Usuario'),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String t) => Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _fSub,
          letterSpacing: 1,
        ),
      );
}
