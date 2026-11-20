// lib/core/engine/tia568_calculator.dart
// Lógica determinística que traduce los requerimientos del cliente en
// cantidades de insumos (BOM) para cableado estructurado de cobre.
//
// Norma de referencia (ediciones "E", vigentes):
//   · ANSI/TIA-568.1-E  → diseño del cableado de edificios comerciales:
//                          enlace permanente horizontal ≤ 90 m y canal ≤ 100 m
//                          (90 m de cable + hasta 10 m entre cordones).
//   · ANSI/TIA-568.2-E  → componentes de par trenzado balanceado (Cat 5e, 6, 6A).
//                          La categoría del canal la fija el componente de
//                          menor categoría: cable, jacks, patch panels y
//                          patch cords deben ser de la misma categoría.
//
// Parámetros de estimación que NO son requisitos de la norma, sino criterios
// de la empresa: reserva técnica de 10 %, merma de 10 % en jacks, 2 patch
// cords por punto, organizador por panel y bobinas de 305 m (1 000 ft).

class ParametrosEntrada {
  final int puntosTotales;
  final double distanciaPromedio; // Enlace horizontal en metros
  final double costoJornalTecnico;
  final int diasEjecucion;
  final int tecnicosCuadrilla;
  final double margenComercial; // Ej. 0.30 para 30%

  /// Cable troncal (backbone) del rack principal al gabinete intermedio (IDF).
  /// 0 si no hay IDF. Con IDF, [distanciaPromedio] es el tramo horizontal
  /// desde el IDF hasta cada punto.
  final double distanciaTroncal;

  /// Puertos del switch elegido (0 = no especificado → 1 equipo).
  final int puertosPorSwitch;

  ParametrosEntrada({
    required this.puntosTotales,
    required this.distanciaPromedio,
    required this.costoJornalTecnico,
    required this.diasEjecucion,
    required this.tecnicosCuadrilla,
    this.margenComercial = 0.30,
    this.distanciaTroncal = 0,
    this.puertosPorSwitch = 0,
  });
}

class ResultadoCalculoTIA568 {
  final double metradoCableTotal;
  final int bobinasRequeridas;
  final int jacksRequeridos;
  final int patchCordsRequeridos;
  final int patchPanels24p;
  final int patchPanels48p;
  final int organizadoresRequeridos;
  final int switchesRequeridos;
  final double costoManoObraTotal;

  /// true si la distancia excede el límite normado de 90 m (enlace permanente).
  final bool excedeLimiteNormado;

  ResultadoCalculoTIA568({
    required this.metradoCableTotal,
    required this.bobinasRequeridas,
    required this.jacksRequeridos,
    required this.patchCordsRequeridos,
    required this.patchPanels24p,
    required this.patchPanels48p,
    required this.organizadoresRequeridos,
    required this.switchesRequeridos,
    required this.costoManoObraTotal,
    required this.excedeLimiteNormado,
  });
}

class TIA568Calculator {
  /// Edición de la norma tomada como referencia (se imprime en la cotización).
  static const String normaReferencia = 'ANSI/TIA-568.1-E y 568.2-E';

  /// Longitud máxima normada del enlace horizontal (permanent link).
  static const double distanciaMaximaNormada = 90.0;

  /// Longitud máxima del troncal en cobre entre rack e IDF. Por encima se
  /// requiere fibra óptica (ANSI/TIA-568.3), fuera del alcance del cotizador.
  static const double distanciaMaximaTroncalCobre = 90.0;

  /// Reserva técnica sobre el metrado total de cable (criterio de la empresa).
  static const double reservaTecnica = 0.10;

  /// Longitud de cada bobina/caja de cable (m).
  static const double metrosPorBobina = 305.0;

  static const String mensajeExcesoDistancia =
      'Exceso de distancia según norma ANSI/TIA-568 (máx. 90 m por enlace). '
      'Se recomienda instalar un gabinete intermedio (IDF) para segmentar el enlace.';

  static bool excedeLimite(double distancia) => distancia > distanciaMaximaNormada;

  static bool excedeTroncalCobre(double distancia) =>
      distancia > distanciaMaximaTroncalCobre;

  static ResultadoCalculoTIA568 calcular(ParametrosEntrada params) {
    if (params.puntosTotales <= 0) {
      throw ArgumentError('La cantidad de puntos debe ser mayor a 0');
    }
    if (params.distanciaPromedio <= 0) {
      throw ArgumentError('La distancia promedio debe ser mayor a 0');
    }
    if (params.distanciaTroncal < 0) {
      throw ArgumentError('La distancia troncal no puede ser negativa');
    }
    if (excedeTroncalCobre(params.distanciaTroncal)) {
      throw ArgumentError(
          'El troncal en cobre no puede superar 90 m; para distancias mayores '
          'se requiere fibra óptica');
    }

    // 1. Metrado lineal total (horizontal + troncal IDF) con 10% de reserva técnica
    final double metradoBase =
        params.puntosTotales * params.distanciaPromedio + params.distanciaTroncal;
    final double metradoCableTotal = metradoBase * (1 + reservaTecnica);

    // 2. Cajas/Bobinas de cable de 305m (Redondeo hacia arriba)
    // Se redondea a 2 decimales antes de dividir: con coma flotante, 3 355 m
    // salían como 3 355,0000000000005 y pedían una bobina de más.
    final double metradoRedondeado = double.parse(metradoCableTotal.toStringAsFixed(2));
    final int bobinasRequeridas = (metradoRedondeado / metrosPorBobina).ceil();

    // 3. Jacks RJ45 con 10% de margen por merma de crimpado
    // 10 % de merma con enteros: puntos × 1,10 en coma flotante daba 56 jacks
    // para 50 puntos (55 exactos).
    final int jacksRequeridos = (params.puntosTotales * 11 + 9) ~/ 10;

    // 4. Patch Cords (1 para puesto de trabajo + 1 para patch panel)
    final int patchCordsRequeridos = params.puntosTotales * 2;

    // 5. Dimensionamiento óptimo de Patch Panels
    int patchPanels24p = 0;
    int patchPanels48p = 0;

    if (params.puntosTotales <= 24) {
      patchPanels24p = 1;
    } else if (params.puntosTotales <= 48) {
      patchPanels48p = 1;
    } else {
      patchPanels48p = (params.puntosTotales / 48).floor();
      final int residuo = params.puntosTotales % 48;
      if (residuo > 0 && residuo <= 24) {
        patchPanels24p = 1;
      } else if (residuo > 24) {
        patchPanels48p += 1;
      }
    }

    // 6. Organizadores horizontales de cable: 1 por cada patch panel
    final int organizadoresRequeridos = patchPanels24p + patchPanels48p;

    // 7. Switches: un puerto por punto de red activo
    final int switchesRequeridos = params.puertosPorSwitch > 0
        ? (params.puntosTotales / params.puertosPorSwitch).ceil()
        : 1;

    // 8. Costo de Mano de Obra (días * técnicos * jornal)
    final double costoManoObraTotal =
        params.diasEjecucion * params.tecnicosCuadrilla * params.costoJornalTecnico;

    return ResultadoCalculoTIA568(
      metradoCableTotal: metradoRedondeado,
      bobinasRequeridas: bobinasRequeridas,
      jacksRequeridos: jacksRequeridos,
      patchCordsRequeridos: patchCordsRequeridos,
      patchPanels24p: patchPanels24p,
      patchPanels48p: patchPanels48p,
      organizadoresRequeridos: organizadoresRequeridos,
      switchesRequeridos: switchesRequeridos,
      costoManoObraTotal: costoManoObraTotal,
      excedeLimiteNormado: excedeLimite(params.distanciaPromedio),
    );
  }
}
