// Pruebas unitarias del motor de estimación paramétrica (HU-03).
// Verifican las reglas ANSI/TIA-568 implementadas en TIA568Calculator.
import 'package:flutter_test/flutter_test.dart';
import 'package:ejarad_app/core/engine/tia568_calculator.dart';

ParametrosEntrada _p(int puntos, double distancia,
        {double jornal = 120, int dias = 2, int tecnicos = 2}) =>
    ParametrosEntrada(
      puntosTotales: puntos,
      distanciaPromedio: distancia,
      costoJornalTecnico: jornal,
      diasEjecucion: dias,
      tecnicosCuadrilla: tecnicos,
    );

void main() {
  group('Metrado y bobinas', () {
    test('aplica 10 % de reserva técnica al metrado', () {
      final r = TIA568Calculator.calcular(_p(10, 50));
      expect(r.metradoCableTotal, 550.0); // 10 × 50 × 1.10
    });

    test('redondea bobinas de 305 m hacia arriba', () {
      expect(TIA568Calculator.calcular(_p(10, 50)).bobinasRequeridas, 2); // 550 m
      expect(TIA568Calculator.calcular(_p(5, 55)).bobinasRequeridas, 1); // 302.5 m
      expect(TIA568Calculator.calcular(_p(6, 50)).bobinasRequeridas, 2); // 330 m
    });
  });

  group('Gabinete intermedio (IDF)', () {
    test('suma el cable troncal al metrado con reserva', () {
      final r = TIA568Calculator.calcular(ParametrosEntrada(
        puntosTotales: 10,
        distanciaPromedio: 60, // tramo horizontal IDF → puntos
        distanciaTroncal: 50, // rack principal → IDF
        costoJornalTecnico: 120,
        diasEjecucion: 2,
        tecnicosCuadrilla: 2,
      ));
      expect(r.metradoCableTotal, 715.0); // (10 × 60 + 50) × 1.10
      expect(r.bobinasRequeridas, 3);
      expect(r.excedeLimiteNormado, isFalse);
    });

    test('el troncal en cobre no puede superar 90 m (se requeriría fibra)', () {
      expect(
          () => TIA568Calculator.calcular(ParametrosEntrada(
                puntosTotales: 10,
                distanciaPromedio: 60,
                distanciaTroncal: 91,
                costoJornalTecnico: 120,
                diasEjecucion: 2,
                tecnicosCuadrilla: 2,
              )),
          throwsArgumentError);
      expect(
          () => TIA568Calculator.calcular(ParametrosEntrada(
                puntosTotales: 10,
                distanciaPromedio: 60,
                distanciaTroncal: -5,
                costoJornalTecnico: 120,
                diasEjecucion: 2,
                tecnicosCuadrilla: 2,
              )),
          throwsArgumentError);
      expect(TIA568Calculator.excedeTroncalCobre(90), isFalse);
      expect(TIA568Calculator.excedeTroncalCobre(90.1), isTrue);
    });
  });

  group('Switches', () {
    ParametrosEntrada conPuertos(int puntos, int puertos) => ParametrosEntrada(
          puntosTotales: puntos,
          distanciaPromedio: 30,
          costoJornalTecnico: 120,
          diasEjecucion: 2,
          tecnicosCuadrilla: 2,
          puertosPorSwitch: puertos,
        );

    test('un switch por cada bloque de puertos, redondeado hacia arriba', () {
      expect(TIA568Calculator.calcular(conPuertos(24, 24)).switchesRequeridos, 1);
      expect(TIA568Calculator.calcular(conPuertos(25, 24)).switchesRequeridos, 2);
      expect(TIA568Calculator.calcular(conPuertos(96, 24)).switchesRequeridos, 4);
      expect(TIA568Calculator.calcular(conPuertos(10, 48)).switchesRequeridos, 1);
    });

    test('sin puertos especificados se estima un equipo', () {
      expect(TIA568Calculator.calcular(_p(96, 30)).switchesRequeridos, 1);
    });
  });

  group('Norma de referencia', () {
    test('indica las ediciones E de ANSI/TIA-568', () {
      expect(TIA568Calculator.normaReferencia, contains('568.1-E'));
      expect(TIA568Calculator.normaReferencia, contains('568.2-E'));
    });
  });

  group('Accesorios', () {
    test('jacks con 10 % de merma y 2 patch cords por punto', () {
      final r = TIA568Calculator.calcular(_p(24, 30));
      expect(r.jacksRequeridos, 27); // ceil(26.4)
      expect(r.patchCordsRequeridos, 48);
    });

    test('dimensiona patch panels y organizadores', () {
      final casos = {
        // puntos: (24p, 48p)
        12: (1, 0),
        24: (1, 0),
        25: (0, 1),
        48: (0, 1),
        60: (1, 1),
        96: (0, 2),
        100: (1, 2),
        130: (0, 3),
      };
      casos.forEach((puntos, esperado) {
        final r = TIA568Calculator.calcular(_p(puntos, 30));
        expect((r.patchPanels24p, r.patchPanels48p), esperado,
            reason: '$puntos puntos');
        expect(r.organizadoresRequeridos, esperado.$1 + esperado.$2);
      });
    });
  });

  group('Mano de obra', () {
    test('días × técnicos × jornal', () {
      final r = TIA568Calculator.calcular(_p(10, 30, jornal: 150, dias: 3, tecnicos: 4));
      expect(r.costoManoObraTotal, 1800.0);
    });
  });

  group('Límite normado de 90 m', () {
    test('90 m está dentro de la norma', () {
      expect(TIA568Calculator.calcular(_p(10, 90)).excedeLimiteNormado, isFalse);
    });

    test('más de 90 m activa la advertencia', () {
      expect(TIA568Calculator.calcular(_p(10, 90.5)).excedeLimiteNormado, isTrue);
      expect(TIA568Calculator.excedeLimite(120), isTrue);
    });
  });

  group('Validación de entradas', () {
    test('rechaza puntos o distancia no positivos', () {
      expect(() => TIA568Calculator.calcular(_p(0, 30)), throwsArgumentError);
      expect(() => TIA568Calculator.calcular(_p(10, 0)), throwsArgumentError);
    });
  });

  group('Rendimiento (RNF-01)', () {
    test('1 000 estimaciones en menos de 2 s', () {
      final sw = Stopwatch()..start();
      for (var i = 1; i <= 1000; i++) {
        TIA568Calculator.calcular(_p(i, 10 + (i % 80).toDouble()));
      }
      sw.stop();
      // ignore: avoid_print
      print('RNF-01: 1000 estimaciones en ${sw.elapsedMicroseconds} µs '
          '(${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2)} µs c/u)');
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
