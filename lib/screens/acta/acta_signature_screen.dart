// lib/screens/acta/acta_signature_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:signature/signature.dart';
import '../../core/validators.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';
import 'acta_preview_screen.dart';

const _cBg = Color(0xFF060C18);
const _cSurface = Color(0xFF0D1526);
const _cViolet = Color(0xFF7C3AED);
const _cCyan = Color(0xFF00E5FF);
const _cTeal = Color(0xFF00BFA5);
const _cText = Colors.white;
const _cSub = Color(0xFF8899AA);
const _cDivider = Color(0xFF1A2840);

class ActaSignatureScreen extends StatefulWidget {
  final String nombreProyecto;
  final Map<String, dynamic> proyecto;
  final List<Map<String, dynamic>> equipo;

  const ActaSignatureScreen({
    super.key,
    required this.nombreProyecto,
    required this.proyecto,
    required this.equipo,
  });

  @override
  State<ActaSignatureScreen> createState() => _ActaSignatureScreenState();
}

class _ActaSignatureScreenState extends State<ActaSignatureScreen> {
  final _service = SupabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  // Controlador de firma con fondo transparente (PNG export)
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: null, // Transparente según norma
  );

  final _nombreFirmanteController = TextEditingController();
  final _documentoController = TextEditingController();
  final _cargoController = TextEditingController();
  final _obsController = TextEditingController();

  bool _cargando = false;
  Uint8List? _firmaPngGuardada;

  @override
  void dispose() {
    _signatureController.dispose();
    _nombreFirmanteController.dispose();
    _documentoController.dispose();
    _cargoController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _guardarTrazoFirma() async {
    if (_signatureController.isEmpty) {
      mostrarAviso(context, 'Debe dibujar la firma antes de guardarla');
      return;
    }
    final png = await _signatureController.toPngBytes();
    if (png != null && mounted) {
      setState(() => _firmaPngGuardada = png);
      mostrarOk(context, 'Firma capturada y validada en memoria');
    }
  }

  void _limpiarTrazo() {
    _signatureController.clear();
    setState(() => _firmaPngGuardada = null);
  }

  Future<void> _generarYSubirActa() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_signatureController.isEmpty && _firmaPngGuardada == null) {
      mostrarAviso(context, 'Debe dibujar y registrar la firma del cliente');
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Obtener firma transparente
      final firmaPng = _firmaPngGuardada ?? await _signatureController.toPngBytes();
      if (firmaPng == null) throw Exception('Error al capturar la firma');

      // 2. Obtener hitos, materiales y evidencias
      final proyectoId = widget.proyecto['id'].toString();
      final hitos = await _service.getHitosConEvidencias(proyectoId);
      final materiales = await _service.getMaterialesProyecto(proyectoId);
      final evidencias = await _service.getEvidenciasProyecto(proyectoId);

      // Coordenadas GPS del último registro in situ si existen
      Map<String, dynamic>? coordsInSitu;
      if (evidencias.isNotEmpty) {
        final conCoords = evidencias.firstWhere(
          (e) => e['latitud'] != null && e['longitud'] != null,
          orElse: () => <String, dynamic>{},
        );
        if (conCoords.isNotEmpty) {
          coordsInSitu = {
            'latitud': conCoords['latitud'],
            'longitud': conCoords['longitud'],
            'precision_m': conCoords['precision_m'],
          };
        }
      }

      // 3. Generar código de Acta correlativo
      final now = DateTime.now();
      final ms = now.millisecondsSinceEpoch.toString();
      final codigoActa =
          'AC-${now.year}${now.month.toString().padLeft(2, '0')}-${ms.substring(ms.length - 4)}';

      final perfilId = AuthService.instance.perfil?.id;

      // Responsable
      String responsable = 'EJARAD TIC';
      final lider = widget.equipo.firstWhere(
        (e) => e['rol_en_proyecto'] == 'Líder',
        orElse: () => <String, dynamic>{},
      );
      if (lider.isNotEmpty) {
        final p = lider['perfiles'];
        if (p is Map<String, dynamic>) {
          responsable = '${p['nombre']} ${p['apellido'] ?? ''}'.trim();
        }
      }

      final equipoSnapshot = widget.equipo.map((e) {
        final p = e['perfiles'] is Map<String, dynamic> ? e['perfiles'] : {};
        return {
          'nombre': '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}'.trim(),
          'rol': e['rol_en_proyecto'] ?? 'Técnico',
          'cargo': p['cargo'] ?? 'Técnico de Redes',
        };
      }).toList();

      // 4. Compilar PDF As-Built Local Nativo
      final latNodo = (widget.proyecto['latitud_nodo'] as num?)?.toDouble();
      final lngNodo = (widget.proyecto['longitud_nodo'] as num?)?.toDouble();

      final pdfBytes = await PdfService.generarActaConformidad(
        codigoActa: codigoActa,
        proyecto: widget.proyecto,
        hitos: hitos,
        equipo: equipoSnapshot,
        firmanteNombre: _nombreFirmanteController.text.trim(),
        firmanteDocumento: _documentoController.text.trim().isEmpty
            ? null
            : _documentoController.text.trim(),
        firmanteCargo: _cargoController.text.trim().isEmpty
            ? null
            : _cargoController.text.trim(),
        observaciones: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        firmaPng: firmaPng,
        fechaCierre: now,
        responsableEmpresa: responsable,
        materiales: materiales,
        latitudNodo: latNodo,
        longitudNodo: lngNodo,
        coordenadasGps: coordsInSitu,
      );

      // 5. Registrar en BD y Storage privado
      await _service.registrarActaYCerrarProyecto(
        proyecto: widget.proyecto,
        codigoActa: codigoActa,
        pdfBytes: pdfBytes,
        firmaPng: firmaPng,
        firmanteNombre: _nombreFirmanteController.text.trim(),
        firmanteDocumento: _documentoController.text.trim().isEmpty
            ? null
            : _documentoController.text.trim(),
        firmanteCargo: _cargoController.text.trim().isEmpty
            ? null
            : _cargoController.text.trim(),
        observaciones: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        equipoSnapshot: equipoSnapshot,
        fechaCierre: now,
        perfilId: perfilId,
      );

      if (!mounted) return;

      mostrarOk(context, 'Acta generada y proyecto cerrado exitosamente');

      // 6. Previsualización e interacción (WhatsApp / Impresión)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActaPreviewScreen(
            titulo: 'Acta de Conformidad As-Built',
            codigoActa: codigoActa,
            pdfBytes: pdfBytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        mostrarError(context, 'Error al generar acta: $e');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cSurface,
        title: Text(
          'Cierre y Firma Digital',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _cText,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _cDivider),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROYECTO',
                      style: GoogleFonts.inter(
                        color: _cCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.nombreProyecto,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _cText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Al firmar este documento, el cliente confirma la recepción a entera satisfacción del 100% de la infraestructura instalada según los metrados e hitos técnicos adjuntos.',
                      style: GoogleFonts.inter(
                        color: _cSub,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Campos del Firmante con Validaciones Estrictas
                    Text(
                      'Datos del Conformante / Cliente',
                      style: GoogleFonts.inter(
                        color: _cText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      label: 'Nombre completo del firmante',
                      controller: _nombreFirmanteController,
                      hint: 'Ej. Ing. Carlos Mendoza Ruiz',
                      prefixIcon: Icons.person,
                      inputFormatters: [Formatters.letras],
                      validator: (v) {
                        final req = Validators.requerido(v);
                        if (req != null) return req;
                        final min = Validators.textoMin(3)(v);
                        if (min != null) return min;
                        return Validators.soloLetras(v);
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppField(
                            label: 'DNI / RUC',
                            controller: _documentoController,
                            hint: '8 u 11 dígitos',
                            prefixIcon: Icons.badge,
                            inputFormatters: [Formatters.digitos(11)],
                            validator: Validators.rucODni,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppField(
                            label: 'Cargo (Opcional)',
                            controller: _cargoController,
                            hint: 'Ej. Administrador',
                            prefixIcon: Icons.work_outline,
                            inputFormatters: [Formatters.texto],
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      label: 'Observaciones finales (Opcional)',
                      controller: _obsController,
                      hint: 'Detalles adicionales o condiciones de recepción...',
                      prefixIcon: Icons.comment_outlined,
                      maxLines: 2,
                      inputFormatters: [Formatters.texto],
                    ),
                    const SizedBox(height: 24),

                    // Encabezado de Lienzo de Firma: título arriba y botones
                    // debajo, para que no se desborde en pantallas angostas.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Firma Digital Táctil',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: _cText,
                            fontSize: 15,
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _limpiarTrazo,
                              icon: const Icon(Icons.clear, size: 14, color: Colors.redAccent),
                              label: Text(
                                'Limpiar Trazo',
                                style: GoogleFonts.inter(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: _guardarTrazoFirma,
                              icon: const Icon(Icons.check, size: 14, color: _cTeal),
                              label: Text(
                                'Guardar Firma',
                                style: GoogleFonts.inter(
                                  color: _cTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Lienzo de Firma Digital Táctil
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _firmaPngGuardada != null ? _cTeal : _cDivider,
                            width: 2,
                          ),
                        ),
                        child: Signature(
                          controller: _signatureController,
                          height: 200,
                          backgroundColor: const Color(0xFFF1F5F9), // Fondo visible para trazo negro
                        ),
                      ),
                    ),
                    if (_firmaPngGuardada != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified, color: _cTeal, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Firma capturada en formato PNG transparente',
                            style: GoogleFonts.inter(color: _cTeal, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 30),

                    // Botón Generar Dossier PDF
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cViolet,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: Text(
                          'Generar Acta As-Built y Cerrar Proyecto',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _generarYSubirActa,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
