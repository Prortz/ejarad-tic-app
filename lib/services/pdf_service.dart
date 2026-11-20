// lib/services/pdf_service.dart
import '../core/engine/tia568_calculator.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static final _navy    = PdfColor.fromHex('#1A3A6B');
  static final _cyan    = PdfColor.fromHex('#00B4D8');
  static final _grey    = PdfColor.fromHex('#64748B');
  static final _light   = PdfColor.fromHex('#F1F5F9');
  static final _green   = PdfColor.fromHex('#065F46');
  static const _white   = PdfColors.white;

  static Future<void> generarCotizacion({
    required String codigoCotizacion,
    required String razonSocial,
    required String ruc,
    required String direccion,
    required List<Map<String, dynamic>> items,
    required double margen,
    required double subtotal,
    required double igv,
    required double total,
    required int puntosTotales,
    required String categoriaCable,
    double imprevistos = 0.0,
    double imprevistosPorcentaje = 0.0,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00', 'es_PE');
    final hoy = DateFormat('dd/MM/yyyy', 'es_PE').format(DateTime.now());

    pw.MemoryImage? logo;
    try {
      final d = await rootBundle.load('assets/images/logo_ejarad.png');
      logo = pw.MemoryImage(d.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      header: (ctx) => _header(logo, codigoCotizacion, hoy),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _clienteBox(razonSocial, ruc, direccion),
        pw.SizedBox(height: 14),
        _specs(puntosTotales, categoriaCable),
        pw.SizedBox(height: 14),
        _bom(items, fmt),
        pw.SizedBox(height: 18),
        _totalesBox(subtotal, margen, igv, total, fmt,
            imprevistos: imprevistos,
            imprevistosPorcentaje: imprevistosPorcentaje),
        pw.SizedBox(height: 20),
        _terms(),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Cotizacion_$codigoCotizacion.pdf',
    );
  }

  static pw.Widget _header(pw.MemoryImage? logo, String cod, String fecha,
          {String titulo = 'COTIZACIÓN'}) =>
      pw.Column(children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_navy, _cyan],
                begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logo != null)
                pw.Image(logo, width: 100, height: 36, fit: pw.BoxFit.contain)
              else
                pw.Text('EJARAD TIC', style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold, color: _white)),
              pw.SizedBox(height: 3),
              pw.Text('SOLUCIONES INFORMÁTICAS E.I.R.L.',
                  style: pw.TextStyle(fontSize: 8, color: _white.shade(.85))),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(titulo, style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: _white)),
              pw.SizedBox(height: 3),
              pw.Text(cod, style: pw.TextStyle(fontSize: 10, color: _white)),
              pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 9, color: _white.shade(.85))),
            ]),
          ]),
        ),
        pw.SizedBox(height: 12),
      ]);

  static pw.Widget _footer(pw.Context ctx) =>
      pw.Column(children: [
        pw.Divider(color: _grey.shade(.3)),
        pw.SizedBox(height: 4),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('EJARAD TIC SOLUCIONES INFORMÁTICAS E.I.R.L. | Piura, Perú',
              style: pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _grey)),
        ]),
      ]);

  static pw.Widget _clienteBox(String razon, String ruc, String dir) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _light,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: _cyan.shade(.3))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 7.5, color: _grey, letterSpacing: 0.8)),
            pw.SizedBox(height: 3),
            pw.Text(razon.isEmpty ? 'Sin especificar' : razon,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (ruc.isNotEmpty) pw.Text('RUC/DNI: $ruc', style: pw.TextStyle(fontSize: 9, color: _grey)),
            if (dir.isNotEmpty) pw.Text('Dir: $dir', style: pw.TextStyle(fontSize: 9, color: _grey)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('VALIDEZ', style: pw.TextStyle(fontSize: 7.5, color: _grey, letterSpacing: 0.8)),
            pw.SizedBox(height: 3),
            pw.Text('30 días', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
      );

  static pw.Widget _specs(int puntos, String cable) =>
      pw.Row(children: [
        _chip('Puntos de Red', '$puntos pts'),
        pw.SizedBox(width: 10),
        _chip('Categoría Cable', cable),
        pw.SizedBox(width: 10),
        _chip('Norma', TIA568Calculator.normaReferencia),
      ]);

  static pw.Widget _chip(String label, String val) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: _navy.shade(.08),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: _navy.shade(.22))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _grey, letterSpacing: 0.5)),
          pw.SizedBox(height: 2),
          pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
        ]),
      ));

  static pw.Widget _bom(List<Map<String, dynamic>> items, NumberFormat fmt) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _title('DETALLE DE MATERIALES Y SERVICIOS'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _light, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FixedColumnWidth(35),
            2: pw.FixedColumnWidth(35),
            3: pw.FixedColumnWidth(62),
            4: pw.FixedColumnWidth(62),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _navy),
              children: ['Descripción', 'Unid.', 'Cant.', 'P. Unit.', 'Subtotal']
                  .map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Text(h, style: pw.TextStyle(
                          color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...items.asMap().entries.map((e) {
              final item = e.value;
              final bg = e.key.isOdd ? _light : _white;
              final sub  = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
              final pu   = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
              final cant = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _cell(item['descripcion']?.toString() ?? '—', align: pw.TextAlign.left),
                  _cell(item['unidad']?.toString() ?? 'und'),
                  _cell(cant % 1 == 0 ? cant.toInt().toString() : cant.toStringAsFixed(1)),
                  _cell('S/. ${fmt.format(pu)}'),
                  _cell('S/. ${fmt.format(sub)}', bold: true),
                ],
              );
            }),
          ],
        ),
      ]);

  static pw.Widget _totalesBox(
      double sub, double margen, double igv, double total, NumberFormat fmt,
      {double imprevistos = 0.0, double imprevistosPorcentaje = 0.0}) {
    final costoNeto = sub / (1 + margen / 100);
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Container(
          width: 250,
          decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _navy.shade(.3))),
          child: pw.Column(children: [
            _trow('Costo base materiales y labor', fmt.format(costoNeto - imprevistos), _white),
            if (imprevistos > 0)
              _trow('Imprevistos (${imprevistosPorcentaje.toStringAsFixed(1)}%)',
                  fmt.format(imprevistos), _light),
            _trow('Margen utilidad (${margen.toInt()}%)',
                fmt.format(costoNeto * margen / 100), _white),
            _trow('Subtotal con margen', fmt.format(sub), _light, bold: true),
            _trow('IGV (18%)', fmt.format(igv), _white),
            pw.Container(
              decoration: pw.BoxDecoration(color: _green,
                  borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(8), bottomRight: pw.Radius.circular(8))),
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('PRECIO TOTAL', style: pw.TextStyle(
                    color: _white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('S/. ${fmt.format(total)}', style: pw.TextStyle(
                    color: _white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
          ]),
        ),
      ]);
  }

  static pw.Widget _terms() {
    const list = [
      '• Precios en Soles (PEN) con IGV (18%) incluido.',
      '• Materiales sujetos a disponibilidad de stock al momento de la aprobación.',
      '• Plazo de ejecución inicia desde la aprobación formal de la cotización.',
      '• No incluye obra civil, demolición de losa ni permisos municipales.',
      '• Garantía de instalación: 12 meses por defectos de mano de obra.',
      '• Forma de pago: 50% adelanto al inicio, 50% contra entrega del dossier As-Built.',
    ];
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _title('CONDICIONES COMERCIALES'),
      pw.SizedBox(height: 6),
      ...list.map((c) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(c, style: pw.TextStyle(fontSize: 8, color: _grey)))),
    ]);
  }

  static pw.Widget _title(String t) => pw.Row(children: [
    pw.Container(width: 4, height: 13, decoration: pw.BoxDecoration(color: _cyan,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
    pw.SizedBox(width: 6),
    pw.Text(t, style: pw.TextStyle(
        fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.5)),
  ]);

  static pw.Widget _cell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _trow(String label, String val, PdfColor bg, {bool bold = false}) =>
      pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _grey,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('S/. $val', style: pw.TextStyle(fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );

  // ═══════════════════════════════════════════════════════════════
  // ACTA DE CONFORMIDAD (cierre de proyecto)
  // ═══════════════════════════════════════════════════════════════

  /// Genera el PDF del acta y devuelve sus bytes (no lo muestra).
  static Future<Uint8List> generarActaConformidad({
    required String codigoActa,
    required Map<String, dynamic> proyecto,
    required List<Map<String, dynamic>> hitos,
    required List<Map<String, dynamic>> equipo, // [{nombre, rol, cargo}]
    required String firmanteNombre,
    String? firmanteDocumento,
    String? firmanteCargo,
    String? observaciones,
    required Uint8List firmaPng,
    required DateTime fechaCierre,
    String? responsableEmpresa,
    List<Map<String, dynamic>>? materiales,
    double? latitudNodo,
    double? longitudNodo,
    Map<String, dynamic>? coordenadasGps,
  }) async {
    final pdf = pw.Document(
        title: 'Acta de Conformidad $codigoActa', author: 'EJARAD TIC');
    final fLarga = DateFormat("dd 'de' MMMM 'de' yyyy", 'es');
    final fCorta = DateFormat('dd/MM/yyyy', 'es');

    pw.MemoryImage? logo;
    try {
      final d = await rootBundle.load('assets/images/logo_ejarad.png');
      logo = pw.MemoryImage(d.buffer.asUint8List());
    } catch (_) {}

    final cliente = Map<String, dynamic>.from(proyecto['clientes'] ?? {});
    final dir = Map<String, dynamic>.from(proyecto['direcciones_clientes'] ?? {});
    final razon = (cliente['razon_social'] ?? '—').toString();
    final ruc = (cliente['ruc_cliente'] ?? '').toString();
    final direccion = [
      dir['direccion_especifica'], dir['distrito'], dir['provincia'], dir['departamento']
    ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');
    final inicio = DateTime.tryParse(
        (proyecto['fecha_inicio'] ?? proyecto['created_at'] ?? '').toString());
    final firma = pw.MemoryImage(firmaPng);

    // Registro fotográfico: hasta 2 fotos por hito (máx. 8)
    final pendientes = <Future<_FotoActa?>>[];
    for (final h in hitos) {
      final ev = List<Map<String, dynamic>>.from(h['evidencias_proyecto'] ?? []);
      for (final e in ev.take(2)) {
        if (pendientes.length >= 8) break;
        pendientes.add(() async {
          try {
            final img = await networkImage(e['foto_url'].toString())
                .timeout(const Duration(seconds: 20));
            return _FotoActa(h['nombre_fase']?.toString() ?? 'Hito',
                e['comentario']?.toString(), img);
          } catch (_) {
            return null;
          }
        }());
      }
    }
    final fotos = (await Future.wait(pendientes)).whereType<_FotoActa>().toList();

    final docTxt = (firmanteDocumento ?? '').trim().isEmpty
        ? ''
        : ', identificado(a) con documento N° ${firmanteDocumento!.trim()}';
    final cargoTxt = (firmanteCargo ?? '').trim().isEmpty
        ? ''
        : ', en calidad de ${firmanteCargo!.trim()}';

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      header: (ctx) => _header(logo, codigoActa, fCorta.format(fechaCierre),
          titulo: 'ACTA DE CONFORMIDAD'),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        // ── Datos del proyecto ──
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: _light,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _cyan.shade(.3))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _kv('PROYECTO', '${proyecto['codigo_proyecto'] ?? '—'}  ·  ${proyecto['nombre_obra'] ?? ''}'),
            _kv('CLIENTE', ruc.isEmpty ? razon : '$razon  ·  RUC/DNI $ruc'),
            if (direccion.isNotEmpty) _kv('DIRECCIÓN', direccion),
            _kv('INICIO', inicio != null ? fCorta.format(inicio) : '—'),
            _kv('CULMINACIÓN', fLarga.format(fechaCierre)),
          ]),
        ),
        pw.SizedBox(height: 14),

        // ── Declaración ──
        _title('DECLARACIÓN DE CONFORMIDAD'),
        pw.SizedBox(height: 6),
        pw.Text(
          'Por medio de la presente, $firmanteNombre$docTxt$cargoTxt de $razon, '
          'declara haber recibido a entera satisfacción los trabajos correspondientes a '
          '"${proyecto['nombre_obra'] ?? 'la obra'}", ejecutados por EJARAD TIC SOLUCIONES '
          'INFORMÁTICAS E.I.R.L. y culminados el día ${fLarga.format(fechaCierre)}, '
          'conforme al detalle de hitos técnicos y registro fotográfico que se adjunta.',
          style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 14),

        // ── Hitos ──
        _title('HITOS TÉCNICOS EJECUTADOS'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _light, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FixedColumnWidth(62),
            2: pw.FixedColumnWidth(52),
            3: pw.FlexColumnWidth(2.4),
          },
          children: [
            _headRow(['Hito', 'Fecha', 'Fotos', 'Estado']),
            ...hitos.asMap().entries.map((e) {
              final h = e.value;
              final nFotos = (h['evidencias_proyecto'] as List?)?.length ?? 0;
              final sinEv = h['completado_sin_evidencia'] == true;
              final f = DateTime.tryParse((h['fecha_completado'] ?? '').toString());
              final motivo = (h['motivo_sin_evidencia'] ?? '').toString();
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key.isOdd ? _light : _white),
                children: [
                  _cell(h['nombre_fase']?.toString() ?? '—', align: pw.TextAlign.left),
                  _cell(f != null ? fCorta.format(f.toLocal()) : '—'),
                  _cell('$nFotos'),
                  _cell(
                    sinEv
                        ? 'Sin evidencia${motivo.isNotEmpty ? ': $motivo' : ''}'
                        : 'Conforme',
                    align: pw.TextAlign.left,
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── Metrados y Materiales As-Built ──
        if (materiales != null && materiales.isNotEmpty) ...[
          _title('METRADOS Y MATERIALES INSTALADOS (AS-BUILT)'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _light, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FixedColumnWidth(45),
              2: pw.FixedColumnWidth(60),
              3: pw.FixedColumnWidth(60),
              4: pw.FixedColumnWidth(55),
            },
            children: [
              _headRow(['Insumo / Material', 'Unid.', 'Presup.', 'Instalado', 'Estado']),
              ...materiales.asMap().entries.map((e) {
                final m = e.value;
                final p = (m['cantidad_presupuestada'] as num?)?.toDouble() ?? 0.0;
                final i = (m['cantidad_instalada'] as num?)?.toDouble() ?? p;
                final u = (m['unidad_medida'] ?? 'und').toString();
                final desc = (m['descripcion'] ?? 'Material').toString();
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: e.key.isOdd ? _light : _white),
                  children: [
                    _cell(desc, align: pw.TextAlign.left),
                    _cell(u),
                    _cell(p % 1 == 0 ? p.toInt().toString() : p.toStringAsFixed(1)),
                    _cell(i % 1 == 0 ? i.toInt().toString() : i.toStringAsFixed(1), bold: true),
                    _cell(i >= p ? '100% Ok' : 'Parcial'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 14),
        ],

        // ── Trazabilidad GPS / Coordenadas ──
        if (latitudNodo != null || coordenadasGps != null) ...[
          _title('TRAZABILIDAD Y COORDENADAS GPS'),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _light,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _cyan.shade(.3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (latitudNodo != null && longitudNodo != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('COORDENADAS NODO PRINCIPAL / RACK',
                          style: pw.TextStyle(fontSize: 7.5, color: _grey, letterSpacing: 0.8)),
                      pw.Text(
                          'Lat: ${latitudNodo.toStringAsFixed(6)} | Lng: ${longitudNodo.toStringAsFixed(6)}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
                    ],
                  ),
                if (coordenadasGps != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('CIERRE IN SITU (GPS / POSTGIS)',
                          style: pw.TextStyle(fontSize: 7.5, color: _grey, letterSpacing: 0.8)),
                      pw.Text(
                          'Lat: ${(coordenadasGps['latitud'] as num?)?.toStringAsFixed(6) ?? '—'} | Lng: ${(coordenadasGps['longitud'] as num?)?.toStringAsFixed(6) ?? '—'}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
                    ],
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
        ],

        // ── Equipo ──
        _title('EQUIPO EJECUTOR'),
        pw.SizedBox(height: 8),
        if (equipo.isEmpty)
          pw.Text('No se registró equipo asignado.',
              style: pw.TextStyle(fontSize: 9, color: _grey))
        else
          pw.Table(
            border: pw.TableBorder.all(color: _light, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _headRow(['Nombre', 'Rol en obra', 'Cargo']),
              ...equipo.asMap().entries.map((e) => pw.TableRow(
                    decoration: pw.BoxDecoration(color: e.key.isOdd ? _light : _white),
                    children: [
                      _cell(e.value['nombre']?.toString() ?? '—', align: pw.TextAlign.left),
                      _cell(e.value['rol']?.toString() ?? '—'),
                      _cell(e.value['cargo']?.toString() ?? '—'),
                    ],
                  )),
            ],
          ),

        // ── Observaciones ──
        if ((observaciones ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _title('OBSERVACIONES'),
          pw.SizedBox(height: 6),
          pw.Text(observaciones!.trim(), style: const pw.TextStyle(fontSize: 9.5)),
        ],

        // ── Registro fotográfico (filas de 2) ──
        if (fotos.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _title('REGISTRO FOTOGRÁFICO'),
          pw.SizedBox(height: 8),
          for (var i = 0; i < fotos.length; i += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(child: _fotoBox(fotos[i])),
                pw.SizedBox(width: 10),
                pw.Expanded(
                    child: i + 1 < fotos.length ? _fotoBox(fotos[i + 1]) : pw.SizedBox()),
              ]),
            ),
        ],

        // ── Firmas ──
        pw.SizedBox(height: 24),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
            child: pw.Column(children: [
              pw.Container(height: 70, child: pw.Image(firma, fit: pw.BoxFit.contain)),
              pw.Container(height: 0.8, color: _navy),
              pw.SizedBox(height: 4),
              pw.Text(firmanteNombre,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              if ((firmanteDocumento ?? '').isNotEmpty)
                pw.Text('Doc.: $firmanteDocumento',
                    style: pw.TextStyle(fontSize: 8.5, color: _grey)),
              pw.Text(
                  (firmanteCargo ?? '').isNotEmpty ? '$firmanteCargo · $razon' : razon,
                  style: pw.TextStyle(fontSize: 8.5, color: _grey),
                  textAlign: pw.TextAlign.center),
              pw.Text('CONFORMIDAD DEL CLIENTE',
                  style: pw.TextStyle(fontSize: 7.5, color: _cyan, letterSpacing: 0.8)),
            ]),
          ),
          pw.SizedBox(width: 40),
          pw.Expanded(
            child: pw.Column(children: [
              pw.SizedBox(height: 70),
              pw.Container(height: 0.8, color: _navy),
              pw.SizedBox(height: 4),
              pw.Text(responsableEmpresa ?? 'EJARAD TIC',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('EJARAD TIC SOLUCIONES INFORMÁTICAS E.I.R.L.',
                  style: pw.TextStyle(fontSize: 8.5, color: _grey),
                  textAlign: pw.TextAlign.center),
              pw.Text('RESPONSABLE DE OBRA',
                  style: pw.TextStyle(fontSize: 7.5, color: _cyan, letterSpacing: 0.8)),
            ]),
          ),
        ]),
      ],
    ));

    return pdf.save();
  }

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 78,
              child: pw.Text(k,
                  style: pw.TextStyle(fontSize: 7.5, color: _grey, letterSpacing: 0.8))),
          pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static pw.TableRow _headRow(List<String> cols) => pw.TableRow(
        decoration: pw.BoxDecoration(color: _navy),
        children: cols
            .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(h,
                    style: pw.TextStyle(
                        color: _white, fontSize: 9, fontWeight: pw.FontWeight.bold))))
            .toList(),
      );

  static pw.Widget _fotoBox(_FotoActa f) => pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _light),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        padding: const pw.EdgeInsets.all(5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            height: 150,
            alignment: pw.Alignment.center,
            child: pw.Image(f.img, fit: pw.BoxFit.cover),
          ),
          pw.SizedBox(height: 4),
          pw.Text(f.hito,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy)),
          if ((f.comentario ?? '').isNotEmpty)
            pw.Text(f.comentario!, style: pw.TextStyle(fontSize: 7.5, color: _grey), maxLines: 2),
        ]),
      );
}

class _FotoActa {
  final String hito;
  final String? comentario;
  final pw.ImageProvider img;
  _FotoActa(this.hito, this.comentario, this.img);
}

