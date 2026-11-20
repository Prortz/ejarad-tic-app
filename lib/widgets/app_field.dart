// lib/widgets/app_field.dart
// Campo de texto validado, con el estilo oscuro de la app.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final Color accent;
  final Color fill;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final String? helper;
  final bool obscure;
  final bool enabled;
  final int maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextCapitalization capitalization;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final String? initialValue;

  AppField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    IconData? icon,
    IconData? prefixIcon,
    this.accent = const Color(0xFF2979FF),
    this.fill = const Color(0xFF1A2236),
    TextInputType? keyboard,
    TextInputType? keyboardType,
    dynamic formatters,
    dynamic inputFormatters,
    this.validator,
    this.helper,
    bool? obscure,
    bool? isObscure,
    this.enabled = true,
    this.maxLines = 1,
    Widget? suffix,
    Widget? suffixIcon,
    this.onChanged,
    TextCapitalization? capitalization,
    TextCapitalization? textCapitalization,
    this.action,
    this.onSubmitted,
    this.initialValue,
  })  : icon = prefixIcon ?? icon,
        keyboard = keyboardType ?? keyboard ?? TextInputType.text,
        formatters = _resolverFormatters(inputFormatters ?? formatters),
        obscure = isObscure ?? obscure ?? false,
        suffix = suffixIcon ?? suffix,
        capitalization = textCapitalization ??
            capitalization ??
            TextCapitalization.none;

  static List<TextInputFormatter>? _resolverFormatters(dynamic f) {
    if (f == null) return null;
    final res = <TextInputFormatter>[];
    void add(dynamic item) {
      if (item is TextInputFormatter) {
        res.add(item);
      } else if (item is Iterable) {
        for (final sub in item) {
          add(sub);
        }
      } else if (item is Function) {
        try {
          add(item());
        } catch (_) {}
      }
    }
    add(f);
    return res;
  }

  @override
  Widget build(BuildContext context) {
    const sub = Color(0xFF8899AA);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      obscureText: obscure,
      enabled: enabled,
      maxLines: obscure ? 1 : maxLines,
      onChanged: onChanged,
      textCapitalization: capitalization,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.inter(color: enabled ? Colors.white : sub, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        errorMaxLines: 2,
        labelStyle: GoogleFonts.inter(color: sub, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: sub.withValues(alpha: 0.6), fontSize: 13),
        helperStyle: GoogleFonts.inter(color: sub, fontSize: 11),
        errorStyle: GoogleFonts.inter(color: const Color(0xFFFF6B6B), fontSize: 11),
        prefixIcon: icon == null ? null : Icon(icon, color: accent, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: fill,
        isDense: true,
        enabledBorder: b(Colors.white.withValues(alpha: 0.1)),
        disabledBorder: b(Colors.white.withValues(alpha: 0.05)),
        focusedBorder: b(accent, 1.6),
        errorBorder: b(const Color(0xFFFF6B6B)),
        focusedErrorBorder: b(const Color(0xFFFF6B6B), 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}

/// SnackBar helpers consistentes.
void mostrarError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
}

void mostrarOk(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF00BFA5),
        behavior: SnackBarBehavior.floating));
}

void mostrarAviso(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.amber.shade800,
        behavior: SnackBarBehavior.floating));
}
