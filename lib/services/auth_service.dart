// lib/services/auth_service.dart
// Sesión (Supabase Auth) + perfil actual + gestión de usuarios (Admin).
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthFlowException implements Exception {
  final String message;
  AuthFlowException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _c => Supabase.instance.client;

  /// Perfil del usuario que inició sesión (null si no hay sesión).
  Perfil? perfil;

  bool get haySesion => _c.auth.currentSession != null;

  // ═══════════════════════════════════════════════
  // SESIÓN
  // ═══════════════════════════════════════════════

  Future<Perfil> iniciarSesion(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(
          email: email.trim().toLowerCase(), password: password);
    } on AuthException catch (e) {
      throw AuthFlowException(_traducirAuth(e.message));
    }
    return cargarPerfil();
  }

  Future<Perfil> cargarPerfil() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw AuthFlowException('No hay sesión activa.');

    final res =
        await _c.from('perfiles').select().eq('user_id', uid).maybeSingle();
    if (res == null) {
      await cerrarSesion();
      throw AuthFlowException(
          'Tu cuenta no tiene un perfil asignado. Contacta al administrador.');
    }
    final p = Perfil.fromMap(res);
    if (!p.activo) {
      await cerrarSesion();
      throw AuthFlowException(
          'Tu usuario está desactivado. Contacta al administrador.');
    }
    perfil = p;
    return p;
  }

  Future<void> cerrarSesion() async {
    perfil = null;
    try {
      await _c.auth.signOut();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════
  // RECUPERACIÓN DE CONTRASEÑA (código de un solo uso por correo)
  // ═══════════════════════════════════════════════
  // Flujo en tres pasos, sin enlaces profundos:
  //   1) enviarRecuperacion      → Supabase envía un código al correo
  //   2) verificarCodigoRecuperacion → el código abre una sesión temporal
  //   3) cambiarContrasenaRecuperada → fija la nueva contraseña y cierra la sesión
  // Supabase no revela si el correo existe: la respuesta es la misma.

  Future<void> enviarRecuperacion(String email) async {
    try {
      await _c.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (e) {
      throw AuthFlowException(_traducirAuth(e.message));
    }
  }

  Future<void> verificarCodigoRecuperacion(String email, String codigo) async {
    try {
      await _c.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim().toLowerCase(),
        token: codigo.trim(),
      );
    } on AuthException catch (e) {
      throw AuthFlowException(_traducirAuth(e.message));
    }
  }

  /// Fija la nueva contraseña (la sesión temporal viene del código) y cierra
  /// esa sesión: el usuario debe iniciar sesión con la contraseña nueva.
  Future<void> cambiarContrasenaRecuperada(String nueva) async {
    try {
      await _c.auth.updateUser(UserAttributes(password: nueva));
    } on AuthException catch (e) {
      throw AuthFlowException(_traducirAuth(e.message));
    }
    await cerrarSesion();
  }

  String _traducirAuth(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Credenciales no válidas';
    }
    if (m.contains('banned')) return 'Tu usuario está desactivado.';
    if (m.contains('email not confirmed')) {
      return 'El correo aún no ha sido confirmado.';
    }
    if (m.contains('token has expired') || m.contains('otp_expired') ||
        m.contains('invalid token')) {
      return 'El código es incorrecto o ya venció. Solicita uno nuevo.';
    }
    if (m.contains('same_password') || m.contains('different from the old')) {
      return 'La nueva contraseña debe ser distinta a la anterior.';
    }
    if (m.contains('weak_password') || m.contains('weak password') ||
        m.contains('at least')) {
      return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
    }
    if (m.contains('security purposes') || m.contains('over_email_send_rate')) {
      return 'Espera un minuto antes de pedir otro código.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    if (m.contains('network') || m.contains('socket') ||
        m.contains('host lookup')) {
      return 'Sin conexión. Revisa tu internet.';
    }
    return msg;
  }

  // ═══════════════════════════════════════════════
  // GESTIÓN DE USUARIOS (Edge Function admin-users)
  // ═══════════════════════════════════════════════

  /// Admin: lee `perfiles` completo (incluye DNI). Resto de roles: vista
  /// `perfiles_publico` (sin DNI) — Privilegio Mínimo / Ley N° 29733.
  Future<List<Perfil>> listarPerfiles({bool soloActivos = false}) async {
    final esAdmin = perfil?.esAdmin ?? false;
    List<dynamic> res;
    try {
      var q = _c.from(esAdmin ? 'perfiles' : 'perfiles_publico').select();
      if (soloActivos) q = q.eq('activo', true);
      res = await q.order('nombre', ascending: true);
    } catch (_) {
      var q = _c.from('perfiles').select();
      if (soloActivos) q = q.eq('activo', true);
      res = await q.order('nombre', ascending: true);
    }
    return List<Map<String, dynamic>>.from(res).map(Perfil.fromMap).toList();
  }

  /// Verifica antes de llamar a la Edge Function que el DNI y el código de
  /// usuario no estén en uso (si no, Supabase Auth responde un genérico
  /// "Database error creating new user"). Solo el Admin lee `perfiles` completo.
  Future<void> _validarUnicos({String? dni, String? codigo, String? excluirUserId}) async {
    Future<bool> existe(String filtro) async {
      var q = _c.from('perfiles').select('user_id').or(filtro);
      if (excluirUserId != null) q = q.neq('user_id', excluirUserId);
      final r = await q.limit(1);
      return (r as List).isNotEmpty;
    }

    final d = dni?.trim() ?? '';
    if (d.isNotEmpty && await existe('dni.eq.$d,numero_documento.eq.$d')) {
      throw AuthFlowException('Ya existe un usuario registrado con el DNI $d.');
    }
    final c = codigo?.trim() ?? '';
    if (c.isNotEmpty && await existe('codigo_usuario.eq.$c')) {
      throw AuthFlowException('El código de usuario $c ya está asignado a otra persona.');
    }
  }

  Future<void> crearUsuario({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    String? dni,
    String? telefono,
    required String cargo,
    required String rol,
    required String codigoUsuario,
  }) async {
    await _validarUnicos(dni: dni, codigo: codigoUsuario);
    await _invoke({
        'action': 'create',
        'email': email,
        'password': password,
        'nombre': nombre,
        'apellido': apellido,
        'dni': dni,
        'telefono': telefono,
        'cargo': cargo,
        'rol': rol,
        'codigo_usuario': codigoUsuario,
      });
  }

  Future<void> actualizarUsuario({
    required String userId,
    String? email,
    String? password,
    String? nombre,
    String? apellido,
    String? dni,
    String? telefono,
    String? cargo,
    String? rol,
    String? codigoUsuario,
    bool? activo,
  }) async {
    await _validarUnicos(dni: dni, codigo: codigoUsuario, excluirUserId: userId);
    await _invoke({
      'action': 'update',
      'user_id': userId,
      'email': ?email,
      if (password != null && password.isNotEmpty) 'password': password,
      'nombre': ?nombre,
      'apellido': ?apellido,
      'dni': ?dni,
      'telefono': ?telefono,
      'cargo': ?cargo,
      'rol': ?rol,
      'codigo_usuario': ?codigoUsuario,
      'activo': ?activo,
    });
    // Si me edité a mí mismo, refresco mi perfil en memoria.
    if (userId == _c.auth.currentUser?.id) {
      try {
        await cargarPerfil();
      } catch (_) {}
    }
  }

  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      await _c.functions.invoke('admin-users', body: body);
    } on FunctionException catch (e) {
      final d = e.details;
      String msg;
      if (e.status == 404) {
        msg = 'La función "admin-users" no está desplegada en Supabase.';
      } else if (d is Map && d['error'] != null) {
        msg = d['error'].toString();
        if (RegExp(r'database error|duplicate key|unique', caseSensitive: false)
            .hasMatch(msg)) {
          msg = 'No se pudo guardar: el DNI, el código de usuario o el correo ya están registrados.';
        }
      } else {
        msg = e.reasonPhrase ?? 'Error ${e.status}';
      }
      throw AuthFlowException(msg);
    }
  }
}
