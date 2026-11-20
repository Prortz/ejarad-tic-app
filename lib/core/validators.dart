// lib/core/validators.dart
// Validadores y formateadores de entrada reutilizables.
// Regla: el formateador IMPIDE teclear caracteres inválidos y el validador
// verifica el valor completo (longitud, formato, rango) al avanzar/guardar.
import 'package:flutter/services.dart';

class Validators {
  Validators._();

  static final _reCorreo =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
  static final _reLetras = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s.'\-]*$");
  static final _reSerie = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-_/.:]*$');

  static String? requerido(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static String? Function(String?) textoMin(int min, [String campo = 'Este campo']) {
    return (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return '$campo es obligatorio';
      if (t.length < min) return '$campo debe tener al menos $min caracteres';
      return null;
    };
  }

  /// Nombres de personas / lugares: solo letras, espacios, punto, apóstrofo y guion.
  static String? soloLetras(String? v, [String campo = 'Este campo']) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '$campo es obligatorio';
    if (!_reLetras.hasMatch(t)) return '$campo solo admite letras';
    return null;
  }

  static String? dni(String? v, {bool obligatorio = true}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'El DNI es obligatorio' : null;
    if (!RegExp(r'^\d{8}$').hasMatch(t)) return 'El DNI debe tener 8 dígitos';
    return null;
  }

  static String? ruc(String? v, {bool obligatorio = true}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'El RUC es obligatorio' : null;
    if (!RegExp(r'^\d{11}$').hasMatch(t)) return 'El RUC debe tener 11 dígitos';
    if (!RegExp(r'^(10|15|16|17|20)').hasMatch(t)) {
      return 'RUC inválido (debe iniciar con 10, 15, 16, 17 o 20)';
    }
    return null;
  }

  /// RUC (11) o DNI (8).
  static String? rucODni(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'El RUC / DNI es obligatorio';
    if (t.length == 8) return dni(t);
    if (t.length == 11) return ruc(t);
    return 'Ingresa un DNI (8 dígitos) o un RUC (11 dígitos)';
  }

  /// Celular peruano: 9 dígitos que inician en 9.
  static String? celular(String? v, {bool obligatorio = true}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'El teléfono es obligatorio' : null;
    if (!RegExp(r'^9\d{8}$').hasMatch(t)) {
      return 'Teléfono inválido (9 dígitos, inicia con 9)';
    }
    return null;
  }

  static String? correo(String? v, {bool obligatorio = true}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'El correo es obligatorio' : null;
    if (t.length > 120 || !_reCorreo.hasMatch(t)) return 'Correo electrónico inválido';
    return null;
  }

  static String? password(String? v, {int min = 6, bool obligatorio = true}) {
    final t = v ?? '';
    if (t.isEmpty) return obligatorio ? 'La contraseña es obligatoria' : null;
    if (t.length < min) return 'Mínimo $min caracteres';
    if (t.length > 72) return 'Máximo 72 caracteres';
    return null;
  }

  /// Código de un solo uso que llega por correo (solo dígitos, 6 a 10).
  static String? codigoOtp(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Ingresa el código que recibiste';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'El código solo tiene dígitos';
    if (t.length < 6 || t.length > 10) return 'El código tiene entre 6 y 10 dígitos';
    return null;
  }

  /// Confirmación de contraseña: debe coincidir con la que se acaba de escribir.
  static String? Function(String?) confirmacion(String Function() original) {
    return (v) {
      if (v == null || v.isEmpty) return 'Confirma la contraseña';
      if (v != original()) return 'Las contraseñas no coinciden';
      return null;
    };
  }

  static String? entero(String? v, [String campo = 'Este campo', int min = 1, int max = 100000]) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '$campo es obligatorio';
    final n = int.tryParse(t);
    if (n == null) return '$campo debe ser un número entero';
    if (n < min) return '$campo debe ser mayor o igual a $min';
    if (n > max) return '$campo debe ser menor o igual a $max';
    return null;
  }

  static String? decimal(String? v, [String campo = 'Este campo', double min = 0, double max = 10000000]) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '$campo es obligatorio';
    final n = double.tryParse(t);
    if (n == null) return '$campo debe ser un número válido';
    if (n < min) return '$campo debe ser mayor o igual a ${_fmt(min)}';
    if (n > max) return '$campo debe ser menor o igual a ${_fmt(max)}';
    return null;
  }

  /// Número de serie / código QR (alfanumérico con - _ / . :).
  static String? serie(String? v, {bool obligatorio = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return obligatorio ? 'El número de serie es obligatorio' : null;
    if (t.length < 4) return 'Mínimo 4 caracteres';
    if (t.length > 64) return 'Máximo 64 caracteres';
    if (!_reSerie.hasMatch(t)) return 'Solo letras, números y - _ / . :';
    return null;
  }

  static String _fmt(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// Formateadores de teclado (bloquean caracteres no permitidos mientras se escribe).
class Formatters {
  Formatters._();

  /// Solo dígitos con longitud máxima.
  static List<TextInputFormatter> digitos(int maxLen) => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLen),
      ];

  /// Solo letras (con tildes/ñ), espacios, punto, apóstrofo y guion.
  static List<TextInputFormatter> letras({int maxLen = 60}) => [
        FilteringTextInputFormatter.allow(
            RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ\s.'\-]")),
        LengthLimitingTextInputFormatter(maxLen),
      ];

  /// Letras, números y signos básicos de texto libre (sin emojis/control).
  static List<TextInputFormatter> texto({int maxLen = 120}) => [
        FilteringTextInputFormatter.deny(RegExp(r'[<>{}\\\[\]|^~`]')),
        LengthLimitingTextInputFormatter(maxLen),
      ];

  static List<TextInputFormatter> correo({int maxLen = 120}) => [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(maxLen),
      ];

  static List<TextInputFormatter> serie({int maxLen = 64}) => [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_/.:]')),
        LengthLimitingTextInputFormatter(maxLen),
      ];

  static List<TextInputFormatter> decimal({int decimales = 2, int maxLen = 12}) => [
        _DecimalFormatter(decimales),
        LengthLimitingTextInputFormatter(maxLen),
      ];

  static List<TextInputFormatter> sinEspacios({int maxLen = 72}) => [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(maxLen),
      ];
}

class _DecimalFormatter extends TextInputFormatter {
  final int decimales;
  _DecimalFormatter(this.decimales);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final re = RegExp('^\\d*\\.?\\d{0,$decimales}\$');
    return re.hasMatch(t) ? newValue : oldValue;
  }
}
