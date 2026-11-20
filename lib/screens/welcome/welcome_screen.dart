import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../modulos/modulos_screen.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../auth/recuperar_contrasena_screen.dart';

// ────────────────────────────────────────────
// Colores de marca tech Ejarac TIC
// ────────────────────────────────────────────
const kDeepNavy    = Color(0xFF080D1A);
const kElectricBlue = Color(0xFF2979FF);
const kCyan        = Color(0xFF00E5FF);
const kSurface     = Color(0xFF111827);
const kCard        = Color(0xFF1A2236);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF8899AA);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    
    // Auto-login check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.instance.haySesion) {
        _goToLogin(autoLogin: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goToLogin({bool autoLogin = false}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(autoLogin: autoLogin)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepNavy,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _TechIcon(),
                  const SizedBox(height: 40),
                  Text('Ejarad TIC',
                      style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 10),
                  Text('Infraestructura · Redes · Proyectos',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: kTextSecondary,
                          letterSpacing: 1.3),
                      textAlign: TextAlign.center),
                  const Spacer(flex: 3),
                  GradientButton(
                    label: 'Iniciar Sesión',
                    icon: Icons.login_rounded,
                    onTap: () => _goToLogin(),
                  ),
                  const SizedBox(height: 16),
                  Text('Control técnico de campo (Supabase Auth)',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: kTextSecondary)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// LOGIN SCREEN REAL (Supabase)
// ────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final bool autoLogin;
  const LoginScreen({super.key, this.autoLogin = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _isLoading = false;
  bool _verPass = false;
  String? _errorAuth;

  @override
  void initState() {
    super.initState();
    if (widget.autoLogin) {
      _intentarAutoLogin();
    }
  }

  Future<void> _intentarAutoLogin() async {
    setState(() => _isLoading = true);
    try {
      final p = await AuthService.instance.cargarPerfil();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ModulosScreen(user: p)),
      );
    } catch (e) {
      // Falló autologin, limpiar y quedarse aquí
      AuthService.instance.cerrarSesion();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorAuth = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final p = await AuthService.instance
          .iniciarSesion(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ModulosScreen(user: p)),
      );
    } catch (e) {
      // Credenciales inválidas: NO se genera sesión ni token.
      if (mounted) {
        _passCtrl.clear();
        setState(() => _errorAuth = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recuperarContrasena() async {
    final correo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              RecuperarContrasenaScreen(correoInicial: _emailCtrl.text.trim())),
    );
    if (correo != null && mounted) {
      setState(() {
        _emailCtrl.text = correo;
        _passCtrl.clear();
        _errorAuth = null;
      });
    }
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: kTextSecondary),
        prefixIcon: Icon(icon, color: kElectricBlue),
        suffixIcon: suffix,
        errorStyle: GoogleFonts.inter(color: const Color(0xFFFF6B6B), fontSize: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kElectricBlue, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.8)),
        filled: true, fillColor: kCard,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kTextPrimary),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kElectricBlue))
          : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kElectricBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kElectricBlue.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: kCyan, size: 15),
                      const SizedBox(width: 6),
                      Text('Acceso Seguro',
                          style: GoogleFonts.inter(color: kCyan, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Inicia sesión',
                    style: GoogleFonts.inter(
                        fontSize: 30, fontWeight: FontWeight.w800, color: kTextPrimary, height: 1.2)),
                const SizedBox(height: 10),
                Text('Ingresa tus credenciales corporativas para acceder al sistema.',
                    style: GoogleFonts.inter(fontSize: 14, color: kTextSecondary, height: 1.5)),
                const SizedBox(height: 32),

                if (_errorAuth != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorAuth!,
                            style: GoogleFonts.inter(
                                color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  inputFormatters: Formatters.correo(),
                  validator: Validators.correo,
                  style: GoogleFonts.inter(color: kTextPrimary, fontSize: 16),
                  decoration: _deco('Correo electrónico', Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_verPass,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'La contraseña es obligatoria' : null,
                  style: GoogleFonts.inter(color: kTextPrimary, fontSize: 16),
                  decoration: _deco(
                    'Contraseña',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                          _verPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: kTextSecondary),
                      onPressed: () => setState(() => _verPass = !_verPass),
                    ),
                  ),
                  onFieldSubmitted: (_) => _login(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recuperarContrasena,
                    child: Text('¿Olvidaste tu contraseña?',
                        style: GoogleFonts.inter(
                            color: kCyan, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Ingresar',
                  icon: Icons.login_rounded,
                  onTap: _login,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// WIDGETS INTERNOS
// ────────────────────────────────────────────

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const GradientButton({super.key, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: Material(
        borderRadius: BorderRadius.circular(16), color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF2979FF), Color(0xFF00B0FF)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(color: kElectricBlue.withValues(alpha: 0.38), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechIcon extends StatefulWidget {
  const _TechIcon();
  @override
  State<_TechIcon> createState() => _TechIconState();
}

class _TechIconState extends State<_TechIcon> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 160, height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [kElectricBlue.withValues(alpha: 0.22), kDeepNavy.withValues(alpha: 0)]),
        ),
        child: Center(
          child: Container(
            width: 112, height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: kCard,
              border: Border.all(color: kElectricBlue.withValues(alpha: 0.55), width: 1.5),
              boxShadow: [BoxShadow(color: kElectricBlue.withValues(alpha: 0.28), blurRadius: 32, spreadRadius: 3)],
            ),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.hub_rounded, size: 54, color: kElectricBlue),
              Positioned(top: 13, right: 15, child: Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: kCyan))),
              Positioned(bottom: 15, left: 13, child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: kElectricBlue.withValues(alpha: 0.7)))),
            ]),
          ),
        ),
      ),
    );
  }
}
