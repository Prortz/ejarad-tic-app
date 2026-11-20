// lib/screens/trazabilidad/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/validators.dart';
import '../../widgets/app_field.dart';

const _kBg = Color(0xFF060C18);
const _kSurface = Color(0xFF0D1526);
const _kBlue = Color(0xFF2979FF);
const _kCyan = Color(0xFF00E5FF);
const _kText = Colors.white;
const _kSub = Color(0xFF8899AA);
const _kDivider = Color(0xFF1A2840);

class QrScannerScreen extends StatefulWidget {
  final String? titulo;
  const QrScannerScreen({super.key, this.titulo});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final valor = barcode.rawValue?.trim();
      if (valor != null && valor.isNotEmpty) {
        _scanned = true;
        Navigator.of(context).pop(valor);
        break;
      }
    }
  }

  Future<void> _ingresoManual() async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kDivider),
        ),
        title: Text(
          'Ingreso Manual de Serie / QR',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite el número de serie si el código está dañado o ilegible:',
                style: GoogleFonts.inter(color: _kSub, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AppField(
                label: 'Número de Serie / Código',
                controller: controller,
                hint: 'Ej. CAB-6A-2026-0042',
                prefixIcon: Icons.tag,
                inputFormatters: [Formatters.serie],
                validator: Validators.serie,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancelar', style: GoogleFonts.inter(color: _kSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Text(
              'Aceptar',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (resultado != null && resultado.isNotEmpty && mounted) {
      Navigator.of(context).pop(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: Text(
          widget.titulo ?? 'Escáner QR / Código de Barras',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? _kCyan : _kSub,
            ),
            tooltip: 'Linterna',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android, color: _kCyan),
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, color: Colors.orange, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo acceder a la cámara o la plataforma no soporta el escáner.',
                        style: GoogleFonts.inter(color: _kText, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
                        onPressed: _ingresoManual,
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Ingresar manualmente'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Cuadro de mira / Visor
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: _kCyan, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 1,
                      width: 240,
                      color: _kCyan.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Mensaje inferior y botón manual
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kSurface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Text(
                    'Apunte al código QR o de barras del hardware (rack, switch, bobina)',
                    style: GoogleFonts.inter(color: _kSub, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kCyan),
                      backgroundColor: _kSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _ingresoManual,
                    icon: const Icon(Icons.edit, color: _kCyan, size: 18),
                    label: Text(
                      'Ingreso manual por teclado',
                      style: GoogleFonts.inter(
                        color: _kCyan,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
