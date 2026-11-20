// lib/screens/auth/recuperar_contrasena_screen.dart
// Recuperación de contraseña en tres pasos con código de un solo uso:
//   1) correo → 2) código recibido por correo → 3) contraseña nueva.
// Al terminar devuelve el correo (Navigator.pop) para precargar el login.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_field.dart';
import '../welcome/welcome_screen.dart' show GradientButton, kCard, kCyan, kDeepNavy, kElectricBlue, kTextPrimary, kTextSecondary;

enum _Paso { correo, codigo, nueva }

class RecuperarContrasenaScreen extends StatefulWidget {
  final String correoInicial;
  const RecuperarContrasenaScreen({super.key, this.correoInicial = ''});

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  static const _esperaReenvio = 60; // Supabase exige 60 s entre códigos.

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoCtrl;
  final _codigoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  _Paso _paso = _Paso.correo;
  bool _cargando = false;
  bool _verPass = false;
  bool _terminado = false;
  String? _error;
  int _segundos = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _correoCtrl = TextEditingController(text: widget.correoInicial);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _correoCtrl.dispose();
    _codigoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    // Si salió después de validar el código y sin cambiar la contraseña, la
    // sesión temporal no debe quedar abierta.
    if (_paso == _Paso.nueva && !_terminado) {
      AuthService.instance.cerrarSesion();
    }
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    setState(() => _segundos = _esperaReenvio);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _segundos <= 1) {
        t.cancel();
        if (mounted) setState(() => _segundos = 0);
        return;
      }
      setState(() => _segundos--);
    });
  }

  /// Ejecuta una acción mostrando la carga y el error en el recuadro rojo.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _cargando = true);
    try {
      await accion();
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo completar la operación. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enviarCodigo({bool reenvio = false}) => _ejecutar(() async {
        await AuthService.instance.enviarRecuperacion(_correoCtrl.text);
        if (!mounted) return;
        _iniciarEspera();
        setState(() => _paso = _Paso.codigo);
        if (reenvio) mostrarOk(context, 'Te enviamos un código nuevo.');
      });

  Future<void> _verificarCodigo() => _ejecutar(() async {
        await AuthService.instance
            .verificarCodigoRecuperacion(_correoCtrl.text, _codigoCtrl.text);
        if (!mounted) return;
        _timer?.cancel();
        setState(() {
          _paso = _Paso.nueva;
          _segundos = 0;
        });
      });

  Future<void> _guardarContrasena() => _ejecutar(() async {
        await AuthService.instance.cambiarContrasenaRecuperada(_passCtrl.text);
        if (!mounted) return;
        _terminado = true;
        mostrarOk(context, 'Contraseña actualizada. Inicia sesión con la nueva.');
        Navigator.pop(context, _correoCtrl.text.trim());
      });

  void _cambiarCorreo() {
    _timer?.cancel();
    setState(() {
      _paso = _Paso.correo;
      _segundos = 0;
      _codigoCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titulo = switch (_paso) {
      _Paso.correo => 'Recupera tu acceso',
      _Paso.codigo => 'Revisa tu correo',
      _Paso.nueva => 'Crea tu nueva contraseña',
    };
    final detalle = switch (_paso) {
      _Paso.correo =>
        'Escribe el correo de tu cuenta. Si está registrado, te enviaremos un código de verificación.',
      _Paso.codigo =>
        'Ingresa el código que enviamos a ${_correoCtrl.text.trim()}. Revisa también la carpeta de correo no deseado.',
      _Paso.nueva =>
        'El código es válido. Elige una contraseña nueva para tu cuenta.',
    };

    return Scaffold(
      backgroundColor: kDeepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kTextPrimary),
        elevation: 0,
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: kElectricBlue))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _Indicador(paso: _paso),
                      const SizedBox(height: 24),
                      Text(titulo,
                          style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              height: 1.2)),
                      const SizedBox(height: 10),
                      Text(detalle,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: kTextSecondary, height: 1.5)),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ..._campos(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _campos() {
    switch (_paso) {
      case _Paso.correo:
        return [
          AppField(
            controller: _correoCtrl,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            formatters: Formatters.correo(),
            validator: Validators.correo,
            action: TextInputAction.done,
            onSubmitted: (_) => _enviarCodigo(),
          ),
          const SizedBox(height: 28),
          GradientButton(
              label: 'Enviar código',
              icon: Icons.send_rounded,
              onTap: () => _enviarCodigo()),
        ];
      case _Paso.codigo:
        return [
          AppField(
            controller: _codigoCtrl,
            label: 'Código de verificación',
            icon: Icons.pin_outlined,
            keyboard: TextInputType.number,
            formatters: Formatters.digitos(10),
            validator: Validators.codigoOtp,
            action: TextInputAction.done,
            onSubmitted: (_) => _verificarCodigo(),
          ),
          const SizedBox(height: 28),
          GradientButton(
              label: 'Verificar código',
              icon: Icons.verified_outlined,
              onTap: _verificarCodigo),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _cambiarCorreo,
                child: Text('Cambiar correo',
                    style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13)),
              ),
              TextButton(
                onPressed: _segundos > 0 ? null : () => _enviarCodigo(reenvio: true),
                child: Text(
                    _segundos > 0 ? 'Reenviar en ${_segundos}s' : 'Reenviar código',
                    style: GoogleFonts.inter(
                        color: _segundos > 0 ? kTextSecondary : kCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ];
      case _Paso.nueva:
        return [
          AppField(
            controller: _passCtrl,
            label: 'Contraseña nueva',
            icon: Icons.lock_outline,
            obscure: !_verPass,
            formatters: Formatters.sinEspacios(),
            validator: Validators.password,
            helper: 'Mínimo 6 caracteres',
            action: TextInputAction.next,
            suffix: IconButton(
              icon: Icon(
                  _verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kTextSecondary),
              onPressed: () => setState(() => _verPass = !_verPass),
            ),
          ),
          const SizedBox(height: 16),
          AppField(
            controller: _pass2Ctrl,
            label: 'Confirma la contraseña',
            icon: Icons.lock_reset_outlined,
            obscure: !_verPass,
            formatters: Formatters.sinEspacios(),
            validator: Validators.confirmacion(() => _passCtrl.text),
            action: TextInputAction.done,
            onSubmitted: (_) => _guardarContrasena(),
          ),
          const SizedBox(height: 28),
          GradientButton(
              label: 'Guardar contraseña',
              icon: Icons.check_circle_outline,
              onTap: _guardarContrasena),
        ];
    }
  }
}

/// Tres puntos: paso actual resaltado.
class _Indicador extends StatelessWidget {
  final _Paso paso;
  const _Indicador({required this.paso});

  @override
  Widget build(BuildContext context) {
    Widget punto(int i, String texto) {
      final activo = paso.index >= i;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: activo ? kElectricBlue : kCard,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(texto,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: activo ? kCyan : kTextSecondary,
                    fontWeight: paso.index == i ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
    }

    return Row(children: [
      punto(0, 'Correo'),
      const SizedBox(width: 8),
      punto(1, 'Código'),
      const SizedBox(width: 8),
      punto(2, 'Contraseña'),
    ]);
  }
}
