// lib/services/image_service.dart
// Compresión local de fotografías de evidencia (flutter_image_compress).
// Objetivo: reducir ≥ 70 % el peso manteniendo legibilidad técnica
// (se limita el lado mayor a 800–1600 px, suficiente para rótulos y puertos).
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FotoComprimida {
  final Uint8List bytes;
  final int pesoOriginal;
  final bool comprimida;
  const FotoComprimida(this.bytes, this.pesoOriginal, this.comprimida);

  int get pesoFinal => bytes.length;
  double get reduccion =>
      pesoOriginal <= 0 ? 0 : (1 - pesoFinal / pesoOriginal).clamp(0, 1).toDouble();

  static String formato(int b) => b >= 1024 * 1024
      ? '${(b / 1024 / 1024).toStringAsFixed(2)} MB'
      : '${(b / 1024).toStringAsFixed(0)} KB';
}

class ImageService {
  ImageService._();

  static const double objetivoReduccion = 0.70;

  // (lado máximo, calidad) de menor a mayor compresión.
  static const _intentos = [(1600, 70), (1280, 60), (1024, 50), (800, 42)];

  static Future<FotoComprimida> comprimir(XFile foto) async {
    final original = await foto.readAsBytes();
    var mejor = original;
    var comprimida = false;
    try {
      for (final (lado, calidad) in _intentos) {
        final r = await FlutterImageCompress.compressWithList(
          original,
          minWidth: lado,
          minHeight: lado,
          quality: calidad,
          format: CompressFormat.jpeg,
        );
        if (r.isEmpty) continue;
        if (r.length < mejor.length) {
          mejor = r;
          comprimida = true;
        }
        if (1 - r.length / original.length >= objetivoReduccion) break;
      }
    } catch (_) {
      // Plataforma sin soporte nativo (p. ej. Windows/Web): se conserva el original.
    }
    return FotoComprimida(mejor, original.length, comprimida);
  }
}
