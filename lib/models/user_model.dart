// lib/models/user_model.dart
// Perfil de usuario autenticado (tabla public.perfiles ↔ auth.users).

class Perfil {
  final String id;
  final String userId;
  final String nombre;
  final String? apellido;
  final String? dni;
  final String? telefono;
  final String? correo;
  final String cargo;
  final String rol; // 'Admin' | 'Supervisor' | 'Técnico'
  final String? codigoUsuario;
  final bool activo;
  final DateTime? createdAt;

  const Perfil({
    required this.id,
    required this.userId,
    required this.nombre,
    this.apellido,
    this.dni,
    this.telefono,
    this.correo,
    this.cargo = 'Técnico de Campo',
    this.rol = 'Técnico',
    this.codigoUsuario,
    this.activo = true,
    this.createdAt,
  });

  static const roles = ['Técnico', 'Supervisor', 'Admin'];

  bool get esAdmin => rol == 'Admin';
  bool get esSupervisor => rol == 'Supervisor';
  bool get esTecnico => !puedeGestionar;

  /// Admin o Supervisor: puede gestionar catálogo, equipos y cierres.
  bool get puedeGestionar => rol == 'Admin' || rol == 'Supervisor';

  String get nombreCompleto => [nombre, apellido]
      .where((s) => s != null && s.trim().isNotEmpty)
      .join(' ');

  String get iniciales {
    final parts = nombreCompleto.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : '?';
  }

  /// Código visible del usuario (ej. "mijuarel"). Si no hay, usa el correo.
  String get codigo =>
      (codigoUsuario != null && codigoUsuario!.isNotEmpty)
          ? codigoUsuario!
          : (correo?.split('@').first ?? (id.isNotEmpty ? id.substring(0, id.length >= 6 ? 6 : id.length) : 'EJR'));

  static final vacio = Perfil(
    id: '',
    userId: '',
    nombre: '',
    cargo: 'Técnico de Campo',
    rol: 'Técnico',
  );

  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'user_id':
        return userId;
      case 'nombre':
        return nombre;
      case 'apellido':
        return apellido;
      case 'dni':
        return dni;
      case 'telefono':
        return telefono;
      case 'correo':
      case 'email':
        return correo;
      case 'cargo':
        return cargo;
      case 'rol':
        return rol;
      case 'codigo_usuario':
        return codigoUsuario;
      case 'activo':
        return activo;
      default:
        return null;
    }
  }

  factory Perfil.fromMap(Map<String, dynamic> m) => Perfil(
        id: m['id'].toString(),
        userId: (m['user_id'] ?? m['id']).toString(),
        nombre: (m['nombre'] ?? '').toString(),
        apellido: m['apellido'] as String?,
        dni: m['dni'] as String?,
        telefono: m['telefono'] as String?,
        correo: m['correo'] as String?,
        cargo: (m['cargo'] as String?) ?? 'Técnico de Campo',
        rol: (m['rol'] as String?) ?? 'Técnico',
        codigoUsuario: m['codigo_usuario'] as String?,
        activo: m['activo'] != false,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      );

  /// Genera un ID corto estilo "mijuarel": 2 letras del nombre + 3 del
  /// apellido + 2 últimas del nombre.
  static String generarCodigo(String nombre, String apellido) {
    String limpiar(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàä]'), 'a')
        .replaceAll(RegExp('[éèë]'), 'e')
        .replaceAll(RegExp('[íìï]'), 'i')
        .replaceAll(RegExp('[óòö]'), 'o')
        .replaceAll(RegExp('[úùü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp('[^a-z ]'), '');
    final n = limpiar(nombre).split(' ').first;
    final a = limpiar(apellido).split(' ').first;
    final parteN = n.length >= 2 ? n.substring(0, 2) : n;
    final parteA = a.length >= 3 ? a.substring(0, 3) : a;
    final sufijo = n.length >= 4 ? n.substring(n.length - 2) : '';
    return '$parteN$parteA$sufijo';
  }
}
