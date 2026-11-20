// lib/screens/acta/acta_preview_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

const _kBg = Color(0xFF060C18);
const _kSurface = Color(0xFF0D1526);
const _kCyan = Color(0xFF00E5FF);
const _kText = Colors.white;
const _kDivider = Color(0xFF1A2840);

class ActaPreviewScreen extends StatelessWidget {
  final String titulo;
  final String codigoActa;
  final Uint8List pdfBytes;

  const ActaPreviewScreen({
    super.key,
    required this.titulo,
    required this.codigoActa,
    required this.pdfBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          titulo,
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: _kCyan),
            tooltip: 'Compartir Acta (WhatsApp / Correo)',
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: '$codigoActa.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print, color: _kCyan),
            tooltip: 'Imprimir Acta',
            onPressed: () async {
              await Printing.layoutPdf(
                onLayout: (_) async => pdfBytes,
                name: '$codigoActa.pdf',
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kDivider, height: 1),
        ),
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        useActions: false, // Usamos nuestros botones superiores
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: '$codigoActa.pdf',
      ),
    );
  }
}
