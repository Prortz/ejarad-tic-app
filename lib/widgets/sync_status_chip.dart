// lib/widgets/sync_status_chip.dart
// Indicador de evidencias pendientes de sincronizar (modo offline) con acción manual.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!LocalDb.soportado) return const SizedBox.shrink();
    final svc = SyncService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: svc.sincronizando,
      builder: (context, sync, child) => ValueListenableBuilder<int>(
        valueListenable: svc.pendientes,
        builder: (context, n, child) {
          if (n == 0 && !sync) return const SizedBox.shrink();
          final color = sync ? const Color(0xFF2979FF) : const Color(0xFFFFB300);
          return GestureDetector(
            onTap: sync ? null : () => svc.sincronizar(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                sync
                    ? SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(Icons.cloud_upload_outlined, size: 13, color: color),
                const SizedBox(width: 5),
                Text(sync ? 'Sincronizando…' : '$n pendiente${n == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
