// lib/screens/trazabilidad/evidencia_form_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/validators.dart';
import '../../services/catalogo_repository.dart';
import '../../services/image_service.dart';
import '../../services/location_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/app_field.dart';
import 'qr_scanner_screen.dart';

const _kBg = Color(0xFF060C18);
const _kSurface = Color(0xFF0D1526);
const _kCard = Color(0xFF111F35);
const _kBlue = Color(0xFF2979FF);
const _kCyan = Color(0xFF00E5FF);
const _kTeal = Color(0xFF00BFA5);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFFF5252);
const _kText = Colors.white;
const _kSub = Color(0xFF8899AA);
const _kDivider = Color(0xFF1A2840);

class EvidenciaFormScreen extends StatefulWidget {
  final String proyectoId;
  final String hitoId;
  final String? hitoTitulo;
  final String? codigoProyecto;

  const EvidenciaFormScreen({
    super.key,
    required this.proyectoId,
    required this.hitoId,
    this.hitoTitulo,
    this.codigoProyecto,
  });

  @override
  State<EvidenciaFormScreen> createState() => _EvidenciaFormScreenState();
}

class _EvidenciaFormScreenState extends State<EvidenciaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _comentarioCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _picker = ImagePicker();

  FotoComprimida? _foto;
  GpsCaptura? _gps;
  bool _obteniendoGps = false;
  bool _guardando = false;
  String? _qrPayload;
  String? _insumoReconocido; // insumo del catálogo que coincide con el SKU leído

  @override
  void initState() {
    super.initState();
    _capturarGps();
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _serieCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarGps() async {
    setState(() => _obteniendoGps = true);
    final captura = await LocationService.capturar();
    if (!mounted) return;
    setState(() {
      _gps = captura;
      _obteniendoGps = false;
    });

    if (captura.estado == GpsEstado.servicioDeshabilitado ||
        captura.estado == GpsEstado.permisoDenegadoPermanente) {
      _mostrarAlertaGps(captura);
    }
  }

  void _mostrarAlertaGps(GpsCaptura captura) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kDivider),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: _kAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ubicación GPS Requerida',
                maxLines: 2,
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          captura.mensaje ?? 'Se requiere activar la ubicación GPS en el dispositivo.',
          style: GoogleFonts.inter(color: _kSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Ignorar', style: GoogleFonts.inter(color: _kSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
            onPressed: () {
              Navigator.of(ctx).pop();
              LocationService.abrirAjustes(captura.estado);
            },
            child: Text(
              'Abrir Ajustes',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tomarFoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      // Compresión local superior al 70%
      final comprimida = await ImageService.comprimir(picked);
      if (!mounted) return;
      setState(() {
        _foto = comprimida;
      });
    } catch (e) {
      if (mounted) {
        mostrarError(context, 'Error al capturar fotografía: $e');
      }
    }
  }

  Future<void> _escanearQr() async {
    final valor = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          titulo: 'Escanear Serie / QR de Hardware',
        ),
      ),
    );
    if (valor != null && valor.isNotEmpty && mounted) {
      setState(() {
        _qrPayload = valor;
        _serieCtrl.text = valor;
        _insumoReconocido = null;
      });
      mostrarOk(context, 'Código detectado: $valor');
      // Valida el código contra el catálogo (con caché local si no hay red).
      try {
        final cat = await CatalogoRepository.instance.obtener(soloActivos: false);
        final it = CatalogoRepository.buscarPorSku(cat.items, valor);
        if (mounted && it != null) {
          setState(() => _insumoReconocido = '${it.sku} · ${it.descripcion}');
        }
      } catch (_) {}
    }
  }

  Future<void> _guardarEvidencia() async {
    if (_foto == null) {
      mostrarAviso(context, 'Debe capturar o seleccionar una fotografía de evidencia');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);

    try {
      final estado = await EvidenciaRepository.instance.guardar(
        proyectoId: widget.proyectoId,
        hitoId: widget.hitoId,
        bytes: _foto!.bytes,
        comentario: _comentarioCtrl.text.trim(),
        gps: _gps,
        numeroSerie: _serieCtrl.text.trim().isNotEmpty
            ? _serieCtrl.text.trim().toUpperCase()
            : null,
        qrPayload: _qrPayload,
      );

      if (!mounted) return;

      final mensaje = estado == EstadoGuardado.sincronizado
          ? 'Evidencia y foto sincronizadas correctamente con el servidor'
          : 'Guardado offline en el dispositivo. Se sincronizará automáticamente al detectar conexión';

      if (estado == EstadoGuardado.sincronizado) {
        mostrarOk(context, mensaje);
      } else {
        mostrarAviso(context, mensaje);
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        mostrarError(context, 'Error al guardar evidencia: $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
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
          'Registro de Trazabilidad',
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kDivider, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.hitoTitulo != null) ...[
              _buildHitoHeader(),
              const SizedBox(height: 16),
            ],
            _buildFotoSection(),
            const SizedBox(height: 16),
            _buildGpsSection(),
            const SizedBox(height: 16),
            _buildHardwareSection(),
            const SizedBox(height: 16),
            _buildComentarioSection(),
            const SizedBox(height: 24),
            _buildGuardarButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHitoHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDivider),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag, color: _kCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HITO ASOCIADO',
                  style: GoogleFonts.inter(
                    color: _kSub,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.hitoTitulo!,
                  style: GoogleFonts.inter(
                    color: _kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evidencia Fotográfica',
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_foto != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${(_foto!.reduccion * 100).toStringAsFixed(0)}% compresión',
                    style: GoogleFonts.inter(
                      color: _kTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_foto == null) ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kDivider),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo, color: _kCyan, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Tome o seleccione una foto de la evidencia técnica',
                      style: GoogleFonts.inter(color: _kSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _tomarFoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(
                      'Cámara',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kDivider),
                      backgroundColor: _kCard,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _tomarFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library,
                        size: 18, color: _kCyan),
                    label: Text(
                      'Galería',
                      style: GoogleFonts.inter(
                        color: _kText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Vista previa con métricas de compresión
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _foto!.bytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricInfo('Original', FotoComprimida.formato(_foto!.pesoOriginal)),
                  _metricInfo('Comprimido', FotoComprimida.formato(_foto!.pesoFinal)),
                  _metricInfo('Ahorro', '${(_foto!.reduccion * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => setState(() => _foto = null),
                    icon: const Icon(Icons.delete, color: _kRed, size: 16),
                    label: Text(
                      'Descartar',
                      style: GoogleFonts.inter(color: _kRed, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _tomarFoto(ImageSource.camera),
                    icon: const Icon(Icons.refresh, color: _kCyan, size: 16),
                    label: Text(
                      'Repetir Foto',
                      style: GoogleFonts.inter(color: _kCyan, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: _kSub, fontSize: 10),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsSection() {
    final ok = _gps?.ok ?? false;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ok ? _kTeal.withValues(alpha: 0.3) : _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    ok ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: ok ? _kTeal : _kAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Geolocalización In Situ',
                    style: GoogleFonts.inter(
                      color: _kText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: _obteniendoGps
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kCyan),
                      )
                    : const Icon(Icons.refresh, size: 18, color: _kCyan),
                tooltip: 'Recalcular GPS',
                onPressed: _obteniendoGps ? null : _capturarGps,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (ok) ...[
            Text(
              'Lat: ${_gps!.latitud!.toStringAsFixed(6)} | Lng: ${_gps!.longitud!.toStringAsFixed(6)}',
              style: GoogleFonts.inter(
                color: _kText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Margen de precisión: ±${_gps!.precisionM!.toStringAsFixed(1)} metros',
              style: GoogleFonts.inter(color: _kTeal, fontSize: 11),
            ),
          ] else ...[
            Text(
              _gps?.mensaje ?? 'Obteniendo coordenadas satelitales...',
              style: GoogleFonts.inter(color: _kAmber, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHardwareSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: _kCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'Hardware / Serie (Opcional)',
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppField(
            label: 'Número de Serie / Código QR',
            controller: _serieCtrl,
            hint: 'Ej. RACK-42U-001 o SN-CAB6A',
            prefixIcon: Icons.tag,
            inputFormatters: [Formatters.serie],
            validator: Validators.serie,
            textCapitalization: TextCapitalization.characters,
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code, color: _kCyan),
              tooltip: 'Escanear con cámara',
              onPressed: _escanearQr,
            ),
          ),
          if (_insumoReconocido != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: _kTeal, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Reconocido en catálogo: $_insumoReconocido',
                    style: GoogleFonts.inter(color: _kTeal, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComentarioSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas de Campo / Observación',
            style: GoogleFonts.inter(
              color: _kText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AppField(
            label: 'Descripción del trabajo realizado',
            controller: _comentarioCtrl,
            hint: 'Detalle de la instalación, canalizado o conexionado...',
            prefixIcon: Icons.notes,
            maxLines: 3,
            inputFormatters: [Formatters.texto],
            validator: Validators.requerido,
          ),
        ],
      ),
    );
  }

  Widget _buildGuardarButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _guardando ? null : _guardarEvidencia,
        icon: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.cloud_upload),
        label: Text(
          _guardando ? 'Guardando...' : 'Registrar Evidencia de Campo',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
