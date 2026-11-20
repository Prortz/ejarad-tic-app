// lib/screens/cotizador/cotizador_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/engine/tia568_calculator.dart';
import '../../core/validators.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_field.dart';
import 'bom_preview_screen.dart';

// ─── Paleta tech ────────────────────────────────
const _kBg = Color(0xFF080D1A);
const _kSurface = Color(0xFF111827);
const _kCard = Color(0xFF1A2236);
const _kBlue = Color(0xFF2979FF);
const _kCyan = Color(0xFF00E5FF);
const _kTeal = Color(0xFF00BFA5);
const _kAmber = Color(0xFFFFB300);
const _kText = Colors.white;
const _kSub = Color(0xFF8899AA);
const _kDivider = Color(0xFF1E2D45);

class CotizadorScreen extends StatefulWidget {
  const CotizadorScreen({super.key});

  @override
  State<CotizadorScreen> createState() => _CotizadorScreenState();
}

class _CotizadorScreenState extends State<CotizadorScreen> {
  int _currentStep = 0;
  final _svc = SupabaseService.instance;

  final _formStep0 = GlobalKey<FormState>();
  final _formStep1 = GlobalKey<FormState>();

  // ── Step 0: Datos del Cliente ─────────────────
  final _rucCtrl = TextEditingController();
  final _razonCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController(text: 'Piura');
  final _distritoCtrl = TextEditingController(text: 'Piura');
  final _direccionCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  bool _buscandoCliente = false;
  String? _clienteIdExistente;

  // ── Step 1: Puntos y distancia ────────────────
  final _puntosCtrl = TextEditingController(text: '24');
  final _distanciaCtrl = TextEditingController(text: '35');
  final _troncalCtrl = TextEditingController();
  bool _incluirGabineteIntermedio = false;

  double get _distanciaTotal => double.tryParse(_distanciaCtrl.text.trim()) ?? 0.0;
  double get _distanciaTroncal => double.tryParse(_troncalCtrl.text.trim()) ?? 0.0;

  /// Puertos del switch elegido ("24 Puertos PoE" → 24, "Core L3 24p" → 24).
  int get _puertosDelSwitch {
    final m = RegExp(r'(\d+)\s*(?:puertos|p)\b', caseSensitive: false)
        .firstMatch(_switchPuertos);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  /// Con IDF, el enlace horizontal se mide desde el gabinete intermedio.
  bool get _usaIdf =>
      _incluirGabineteIntermedio && TIA568Calculator.excedeLimite(_distanciaTotal);
  double get _distanciaHorizontal =>
      _usaIdf ? _distanciaTotal - _distanciaTroncal : _distanciaTotal;

  // ── Step 2: Cable y canalización ─────────────
  String _categoriaCable = 'Cat 6 UTP Interior';
  String _tipoCanalizacion = 'Canaleta Perimetral';

  // ── Step 3: Rack y switch ─────────────────────
  String _rackSeleccionado = 'Mural 9U';
  String _switchPuertos = '24 Puertos PoE';

  // ── Step 4: Cuadrilla + GPS ───────────────────
  int _diasEjecucion = 2;
  int _tecnicosCuadrilla = 2;
  GpsCaptura? _gps;
  bool _capturandoGPS = false;

  @override
  void dispose() {
    for (final c in [
      _rucCtrl,
      _razonCtrl,
      _contactoCtrl,
      _telefonoCtrl,
      _correoCtrl,
      _provinciaCtrl,
      _distritoCtrl,
      _direccionCtrl,
      _referenciaCtrl,
      _puntosCtrl,
      _distanciaCtrl,
      _troncalCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Autocompletar cliente por RUC ───────────
  Future<void> _buscarCliente() async {
    final ruc = _rucCtrl.text.trim();
    if (ruc.length < 8) return;
    setState(() => _buscandoCliente = true);
    try {
      final c = await _svc.buscarClientePorRuc(ruc);
      if (c != null && mounted) {
        setState(() {
          _razonCtrl.text = c['razon_social'] ?? '';
          _contactoCtrl.text = c['contacto_nombre'] ?? '';
          _telefonoCtrl.text = c['telefono'] ?? '';
          _correoCtrl.text = c['correo'] ?? '';
          _clienteIdExistente = c['id'] as String?;
        });
        mostrarOk(context, 'Cliente registrado encontrado y autocompletado ✓');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _buscandoCliente = false);
    }
  }

  // ─── Capturar GPS in situ ─────────────────────
  Future<void> _capturarGPS() async {
    setState(() => _capturandoGPS = true);
    final captura = await LocationService.capturar();
    if (!mounted) return;
    setState(() {
      _gps = captura;
      _capturandoGPS = false;
    });

    if (captura.ok) {
      mostrarOk(
        context,
        'GPS Nodo Central: ${captura.latitud!.toStringAsFixed(5)}, ${captura.longitud!.toStringAsFixed(5)} (±${captura.precisionM!.toStringAsFixed(1)}m)',
      );
    } else {
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
          captura.mensaje ?? 'Se requiere ubicación GPS.',
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
            child: Text('Abrir Ajustes',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool _validarPasoActual() {
    if (_currentStep == 0) {
      return _formStep0.currentState?.validate() ?? false;
    } else if (_currentStep == 1) {
      return _formStep1.currentState?.validate() ?? false;
    }
    return true;
  }

  // ─── Calcular y navegar a BOM Preview ────────
  void _calcularYVerBOM() {
    final puntos = int.tryParse(_puntosCtrl.text.trim()) ?? 24;

    final params = ParametrosEntrada(
      puntosTotales: puntos,
      distanciaPromedio: _distanciaHorizontal,
      distanciaTroncal: _usaIdf ? _distanciaTroncal : 0,
      puertosPorSwitch: _puertosDelSwitch,
      costoJornalTecnico: 70.0,
      diasEjecucion: _diasEjecucion,
      tecnicosCuadrilla: _tecnicosCuadrilla,
    );
    final resultado = TIA568Calculator.calcular(params);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BomPreviewScreen(
          resultado: resultado,
          params: params,
          categoriaCable: _categoriaCable,
          tipoCanalizacion: _tipoCanalizacion,
          rackSeleccionado: _rackSeleccionado,
          switchPuertos: _switchPuertos,
          incluirGabineteIntermedio: _usaIdf,
          // Datos cliente
          rucCliente: _rucCtrl.text.trim(),
          razonSocial: _razonCtrl.text.trim(),
          contacto: _contactoCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          provincia: _provinciaCtrl.text.trim(),
          distrito: _distritoCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          referencia: _referenciaCtrl.text.trim(),
          clienteIdExistente: _clienteIdExistente,
          latitudNodo: _gps?.latitud,
          longitudNodo: _gps?.longitud,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: Row(children: [
          const Icon(Icons.calculate_outlined, color: _kBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cotizador ANSI/TIA-568',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
        ]),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kDivider),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kBlue,
            surface: _kCard,
            onSurface: _kText,
          ),
          canvasColor: _kCard,
        ),
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          connectorColor: WidgetStateProperty.all(_kBlue.withValues(alpha: 0.4)),
          onStepContinue: () {
            if (!_validarPasoActual()) return;
            if (_currentStep < 4) {
              setState(() => _currentStep += 1);
            } else {
              _calcularYVerBOM();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            final esUltimo = _currentStep == 4;
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esUltimo ? _kTeal : _kBlue,
                        foregroundColor: esUltimo ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: details.onStepContinue,
                      icon: Icon(
                        esUltimo ? Icons.check_circle : Icons.arrow_forward,
                        size: 18,
                      ),
                      label: Text(
                        esUltimo ? 'Generar Presupuesto BOM' : 'Continuar',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kDivider),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: details.onStepCancel,
                      child: Text('Atrás',
                          style: GoogleFonts.inter(color: _kSub, fontSize: 14)),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: Text('Datos del Cliente B2B',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: _kText)),
              subtitle: Text('RUC, razón social y ubicación de obra',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _step0ClienteContent(),
            ),
            Step(
              title: Text('Puntos de Red y Distancia (ANSI/TIA-568)',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: _kText)),
              subtitle: Text('Metrado horizontal y validación ≤ 90m',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12)),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _step1PuntosContent(),
            ),
            Step(
              title: Text('Categoría de Cable y Canalización',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: _kText)),
              subtitle: Text('Cat 5e / Cat 6 / Cat 6A y canalización',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12)),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _step2CableContent(),
            ),
            Step(
              title: Text('Gabinete / Rack y Switches',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: _kText)),
              subtitle: Text('Equipamiento activo y pasivo del nodo',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12)),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: _step3GabineteContent(),
            ),
            Step(
              title: Text('Cuadrilla de Mano de Obra y GPS',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: _kText)),
              subtitle: Text('Jornales técnicos y coordenadas satelitales',
                  style: GoogleFonts.inter(color: _kSub, fontSize: 12)),
              isActive: _currentStep >= 4,
              state: _currentStep == 4 ? StepState.editing : StepState.indexed,
              content: _step4CuadrillaContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: Cliente ───────────────────────────
  Widget _step0ClienteContent() {
    return Form(
      key: _formStep0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppField(
                  label: 'RUC o DNI',
                  controller: _rucCtrl,
                  hint: '8 u 11 dígitos',
                  prefixIcon: Icons.badge_outlined,
                  inputFormatters: [Formatters.digitos(11)],
                  validator: Validators.rucODni,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _buscandoCliente ? null : _buscarCliente,
                  icon: _buscandoCliente
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text('Buscar',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            label: 'Razón Social / Cliente',
            controller: _razonCtrl,
            hint: 'Nombre comercial o razón social',
            prefixIcon: Icons.business_outlined,
            inputFormatters: [Formatters.texto],
            validator: (v) {
              final req = Validators.requerido(v);
              if (req != null) return req;
              return Validators.textoMin(3)(v);
            },
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppField(
                  label: 'Contacto',
                  controller: _contactoCtrl,
                  hint: 'Persona responsable',
                  prefixIcon: Icons.person_outline,
                  inputFormatters: [Formatters.letras],
                  validator: (v) {
                    final req = Validators.requerido(v);
                    if (req != null) return req;
                    return Validators.soloLetras(v);
                  },
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppField(
                  label: 'Teléfono / Celular',
                  controller: _telefonoCtrl,
                  hint: '9 dígitos (9xxxxxxx)',
                  prefixIcon: Icons.phone_outlined,
                  inputFormatters: [Formatters.digitos(9)],
                  validator: Validators.celular,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            label: 'Correo Electrónico',
            controller: _correoCtrl,
            hint: 'contacto@empresa.com',
            prefixIcon: Icons.email_outlined,
            inputFormatters: [Formatters.correo],
            validator: Validators.correo,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppField(
                  label: 'Provincia',
                  controller: _provinciaCtrl,
                  prefixIcon: Icons.location_city_outlined,
                  inputFormatters: [Formatters.letras],
                  validator: Validators.requerido,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppField(
                  label: 'Distrito',
                  controller: _distritoCtrl,
                  prefixIcon: Icons.map_outlined,
                  inputFormatters: [Formatters.letras],
                  validator: Validators.requerido,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            label: 'Dirección específica de obra',
            controller: _direccionCtrl,
            hint: 'Av. / Calle / N° / Zona industrial',
            prefixIcon: Icons.home_outlined,
            inputFormatters: [Formatters.texto],
            validator: (v) {
              final req = Validators.requerido(v);
              if (req != null) return req;
              return Validators.textoMin(5)(v);
            },
          ),
          const SizedBox(height: 10),
          AppField(
            label: 'Referencia de acceso (opcional)',
            controller: _referenciaCtrl,
            hint: 'Frente a parque, puerta negra...',
            prefixIcon: Icons.place_outlined,
            inputFormatters: [Formatters.texto],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Puntos y Distancia ────────────────
  Widget _step1PuntosContent() {
    final distancia = double.tryParse(_distanciaCtrl.text.trim()) ?? 0.0;
    final excedeNorma = TIA568Calculator.excedeLimite(distancia);

    return Form(
      key: _formStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: 'N° Total de Puntos de Red (Tomas RJ-45)',
            controller: _puntosCtrl,
            hint: 'Ej. 24, 48, 96',
            prefixIcon: Icons.hub_outlined,
            helper: 'Incluye puestos de trabajo, CCTV IP, APs WiFi y VoIP',
            inputFormatters: [Formatters.digitos(4)],
            validator: (v) {
              final req = Validators.requerido(v);
              if (req != null) return req;
              final ent = Validators.entero(v);
              if (ent != null) return ent;
              final val = int.tryParse(v!.trim()) ?? 0;
              if (val < 1 || val > 2000) return 'Ingrese entre 1 y 2000 puntos';
              return null;
            },
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppField(
            label: 'Distancia Promedio al Rack / Nodo (metros)',
            controller: _distanciaCtrl,
            hint: 'Límite ANSI/TIA-568: ≤ 90 metros',
            prefixIcon: Icons.straighten_outlined,
            helper: 'Ningún enlace individual puede superar 90 m: ingrese el del punto más lejano',
            inputFormatters: [Formatters.decimal],
            validator: (v) {
              final req = Validators.requerido(v);
              if (req != null) return req;
              final dec = Validators.decimal(v);
              if (dec != null) return dec;
              final val = double.tryParse(v!.trim()) ?? 0.0;
              if (val < 10 || val > 500) return 'Distancia debe estar entre 10 y 500 m';
              if (TIA568Calculator.excedeLimite(val) && !_incluirGabineteIntermedio) {
                return 'Supera 90 m: incluye un gabinete intermedio (IDF) o reduce la distancia';
              }
              return null;
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Advertencia Técnica Normativa si distancia > 90m
          if (excedeNorma) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAmber.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: _kAmber, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Advertencia Técnica ANSI/TIA-568',
                          style: GoogleFonts.inter(
                            color: _kAmber,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TIA568Calculator.mensajeExcesoDistancia,
                    style: GoogleFonts.inter(
                      color: _kText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: _kAmber,
                    inactiveThumbColor: _kSub,
                    inactiveTrackColor: _kDivider,
                    title: Text(
                      'Incluir Gabinete Intermedio (IDF) en el BOM',
                      style: GoogleFonts.inter(
                        color: _kText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'El enlace se divide: troncal rack → IDF y horizontal IDF → puntos (≤ 90 m)',
                      style: GoogleFonts.inter(color: _kSub, fontSize: 11),
                    ),
                    value: _incluirGabineteIntermedio,
                    onChanged: (val) =>
                        setState(() => _incluirGabineteIntermedio = val),
                  ),
                  if (_incluirGabineteIntermedio) ...[
                    const SizedBox(height: 8),
                    AppField(
                      label: 'Distancia troncal rack principal → IDF (m)',
                      controller: _troncalCtrl,
                      hint: 'Ej. ${(_distanciaTotal - 60).clamp(1, 500).toStringAsFixed(0)}',
                      prefixIcon: Icons.call_split,
                      inputFormatters: [Formatters.decimal],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final req = Validators.requerido(v);
                        if (req != null) return req;
                        final t = double.tryParse(v!.trim()) ?? 0.0;
                        if (TIA568Calculator.excedeTroncalCobre(t)) {
                          return 'El troncal en cobre no puede superar 90 m (se requeriría fibra óptica)';
                        }
                        if (t <= 0 || t >= _distanciaTotal) {
                          return 'Debe ser mayor a 0 y menor a ${_distanciaTotal.toStringAsFixed(0)} m';
                        }
                        final h = _distanciaTotal - t;
                        if (h < 10 || h > 90) {
                          return 'El tramo IDF → puntos quedaría en ${h.toStringAsFixed(1)} m; debe estar entre 10 y 90 m';
                        }
                        return null;
                      },
                    ),
                    if (_distanciaTroncal > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tramo horizontal IDF → puntos: ${_distanciaHorizontal.toStringAsFixed(1)} m',
                          style: GoogleFonts.inter(
                            color: _distanciaHorizontal >= 10 &&
                                    _distanciaHorizontal <= 90
                                ? _kCyan
                                : _kAmber,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kDivider),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: _kCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Se aplicará automáticamente un 10% de reserva técnica sobre el metrado total de cable según norma.',
                    style: GoogleFonts.inter(color: _kSub, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Cable ─────────────────────────────
  Widget _step2CableContent() {
    return Column(children: [
      _dropdown(
        label: 'Categoría de Cable de Red',
        value: _categoriaCable,
        items: const [
          'Cat 6 UTP Interior',
          'Cat 6A Exterior Blindado',
          'Cat 5e UTP',
        ],
        onChanged: (v) => setState(() => _categoriaCable = v!),
        icon: Icons.cable,
      ),
      const SizedBox(height: 12),
      _dropdown(
        label: 'Tipo de Canalización y Bandejas',
        value: _tipoCanalizacion,
        items: const [
          'Canaleta Perimetral',
          'Tubería Conduit PVC',
          'Bandeja Portacable',
          'Embutido en Pared',
        ],
        onChanged: (v) => setState(() => _tipoCanalizacion = v!),
        icon: Icons.view_week_outlined,
      ),
    ]);
  }

  // ── Step 3: Rack y Switch ─────────────────────
  Widget _step3GabineteContent() {
    return Column(children: [
      _dropdown(
        label: 'Gabinete / Rack Principal',
        value: _rackSeleccionado,
        items: const [
          'Mural 6U',
          'Mural 9U',
          'Mural 12U',
          'Gabinete Piso 22U',
          'Gabinete Piso 42U',
        ],
        onChanged: (v) => setState(() => _rackSeleccionado = v!),
        icon: Icons.dns_outlined,
      ),
      const SizedBox(height: 12),
      _dropdown(
        label: 'Switch Activo de Conectividad',
        value: _switchPuertos,
        items: const [
          '8 Puertos No-PoE',
          '16 Puertos PoE',
          '24 Puertos PoE',
          '48 Puertos PoE',
          'Core L3 24p',
        ],
        onChanged: (v) => setState(() => _switchPuertos = v!),
        icon: Icons.router_outlined,
      ),
    ]);
  }

  // ── Step 4: Cuadrilla + GPS ───────────────────
  Widget _step4CuadrillaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Cuadrilla Técnica de Instalación'),
        const SizedBox(height: 6),
        _counterRow(
          'Días proyectados de obra',
          _diasEjecucion,
          onDec: () => setState(() => _diasEjecucion = max(1, _diasEjecucion - 1)),
          onInc: () => setState(() => _diasEjecucion += 1),
        ),
        const SizedBox(height: 8),
        _counterRow(
          'Técnicos en cuadrilla',
          _tecnicosCuadrilla,
          onDec: () =>
              setState(() => _tecnicosCuadrilla = max(1, _tecnicosCuadrilla - 1)),
          onInc: () => setState(() => _tecnicosCuadrilla += 1),
        ),
        const SizedBox(height: 16),
        _sectionLabel('Nodo Central / Rack (Geolocalización GPS)'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _capturandoGPS ? null : _capturarGPS,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (_gps?.ok ?? false)
                  ? _kTeal.withValues(alpha: 0.12)
                  : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_gps?.ok ?? false)
                    ? _kTeal.withValues(alpha: 0.5)
                    : _kBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  (_gps?.ok ?? false) ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: (_gps?.ok ?? false) ? _kTeal : _kBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_gps?.ok ?? false)
                            ? 'Nodo GPS: ${_gps!.latitud!.toStringAsFixed(5)}, ${_gps!.longitud!.toStringAsFixed(5)}'
                            : 'Capturar Coordenadas del Nodo',
                        style: GoogleFonts.inter(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        (_gps?.ok ?? false)
                            ? 'Margen de precisión: ±${_gps!.precisionM!.toStringAsFixed(1)} m'
                            : 'Toca para registrar ubicación física del rack',
                        style: GoogleFonts.inter(color: _kSub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_capturandoGPS)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kCyan),
                  )
                else
                  const Icon(Icons.my_location, color: _kCyan, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDivider),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: _kSub, fontSize: 13),
          icon: Icon(icon, color: _kCyan, size: 20),
          border: InputBorder.none,
          isDense: true,
        ),
        dropdownColor: _kCard,
        style: GoogleFonts.inter(color: _kText, fontSize: 14),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: _kCyan,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _counterRow(String label, int val,
      {required VoidCallback onDec, required VoidCallback onInc}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDivider),
      ),
      child: Row(
        children: [
          // La etiqueta cede espacio a los botones en pantallas angostas.
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: _kText, fontSize: 13)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline, color: _kSub, size: 22),
                onPressed: onDec,
              ),
              Container(
                width: 32,
                alignment: Alignment.center,
                child: Text(
                  '$val',
                  style: GoogleFonts.inter(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, color: _kCyan, size: 22),
                onPressed: onInc,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
