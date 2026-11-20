// lib/config/theme.dart
// Paleta y helpers de UI compartidos (tema oscuro Ejarad TIC).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg      = Color(0xFF060C18);
  static const surface = Color(0xFF0D1526);
  static const card    = Color(0xFF111F35);
  static const cardAlt = Color(0xFF16263F);
  static const blue    = Color(0xFF2979FF);
  static const cyan    = Color(0xFF00E5FF);
  static const teal    = Color(0xFF00BFA5);
  static const violet  = Color(0xFF7C3AED);
  static const indigo  = Color(0xFF6366F1);
  static const orange  = Color(0xFFFF6B35);
  static const amber   = Color(0xFFF59E0B);
  static const red     = Color(0xFFEF4444);
  static const green   = Color(0xFF22C55E);
  static const text    = Colors.white;
  static const sub     = Color(0xFF8899AA);
  static const divider = Color(0xFF1A2840);
}

class AppUI {
  static TextStyle t(double size,
          {FontWeight weight = FontWeight.normal,
          Color color = AppColors.text,
          double? letterSpacing,
          double? height}) =>
      GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
          height: height);

  static PreferredSizeWidget appBar(String title,
          {IconData? icon,
          Color accent = AppColors.blue,
          List<Widget>? actions}) =>
      AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: t(17, weight: FontWeight.w700)),
          ),
        ]),
        actions: actions,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      );

  static Widget sectionLabel(String label,
          {Color accent = AppColors.blue, Widget? trailing}) =>
      Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: t(11,
                  weight: FontWeight.w700,
                  color: AppColors.sub,
                  letterSpacing: 1.1)),
        ),
        if (trailing != null) trailing,
      ]);

  static InputDecoration input(String label,
          {IconData? icon,
          Color accent = AppColors.blue,
          String? hint,
          String? helper,
          Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperStyle: t(11, color: AppColors.sub),
        hintStyle: t(13, color: AppColors.sub.withValues(alpha: 0.5)),
        labelStyle: t(12, color: AppColors.sub),
        prefixIcon: icon != null ? Icon(icon, color: accent, size: 18) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.card,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      );

  static BoxDecoration cardBox({Color? border, double radius = 16}) =>
      BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? AppColors.divider),
      );

  static Widget chip(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: t(10.5, weight: FontWeight.w700, color: color)),
        ]),
      );

  static void snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: t(13)),
        backgroundColor: error ? AppColors.red : AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Diálogo de confirmación estándar. Devuelve true si confirma.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    Color color = AppColors.blue,
    IconData icon = Icons.help_outline,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: t(16, weight: FontWeight.w700))),
        ]),
        content: Text(message, style: t(13.5, color: AppColors.sub, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: t(13, color: AppColors.sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: t(13, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return r == true;
  }

  static Widget primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color color = AppColors.blue,
    bool loading = false,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: color.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(icon, color: Colors.white, size: 20),
          label: Text(label, style: t(15, weight: FontWeight.w700)),
        ),
      );

  static Widget emptyState(IconData icon, String title, String subtitle) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.sub.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: t(15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: t(12.5, color: AppColors.sub, height: 1.4)),
          ]),
        ),
      );
}

/// Formato de fechas cortas: 04 oct 2026
String fmtFecha(dynamic iso, {bool hora = false}) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '—';
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final base = '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]} ${d.year}';
  if (!hora) return base;
  return '$base · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
