// Pruebas unitarias de los validadores de entrada (RUC, DNI, celular, serie…).
import 'package:flutter_test/flutter_test.dart';
import 'package:ejarad_app/core/validators.dart';

void main() {
  group('RUC', () {
    test('acepta RUC válido de empresa', () {
      expect(Validators.ruc('20614671522'), isNull);
    });
    test('rechaza longitud o prefijo inválido', () {
      expect(Validators.ruc('2061467152'), isNotNull);
      expect(Validators.ruc('30614671522'), isNotNull);
      expect(Validators.ruc(''), isNotNull);
      expect(Validators.ruc('', obligatorio: false), isNull);
    });
  });

  group('DNI y RUC/DNI', () {
    test('DNI de 8 dígitos', () {
      expect(Validators.dni('12345678'), isNull);
      expect(Validators.dni('1234567'), isNotNull);
      expect(Validators.dni('1234567a'), isNotNull);
    });
    test('rucODni decide por longitud', () {
      expect(Validators.rucODni('12345678'), isNull);
      expect(Validators.rucODni('20614671522'), isNull);
      expect(Validators.rucODni('123'), isNotNull);
    });
  });

  group('Contacto', () {
    test('celular peruano', () {
      expect(Validators.celular('951581310'), isNull);
      expect(Validators.celular('851581310'), isNotNull);
      expect(Validators.celular('95158131'), isNotNull);
    });
    test('correo', () {
      expect(Validators.correo('tecnico@ejarad.pe'), isNull);
      expect(Validators.correo('tecnico@ejarad'), isNotNull);
      expect(Validators.correo('sin arroba.pe'), isNotNull);
    });
  });

  group('Números', () {
    test('entero con rango', () {
      expect(Validators.entero('24', 'Puntos', 1, 500), isNull);
      expect(Validators.entero('0', 'Puntos', 1, 500), isNotNull);
      expect(Validators.entero('2.5', 'Puntos', 1, 500), isNotNull);
    });
    test('decimal con rango (distancia 10–90 m)', () {
      expect(Validators.decimal('45.5', 'Distancia', 10, 90), isNull);
      expect(Validators.decimal('95', 'Distancia', 10, 90), isNotNull);
      expect(Validators.decimal('abc', 'Distancia', 10, 90), isNotNull);
    });
  });

  group('Serie / QR', () {
    test('formato de número de serie', () {
      expect(Validators.serie('SW-CISCO-2960/01'), isNull);
      expect(Validators.serie('AB'), isNotNull);
      expect(Validators.serie('serie con espacios'), isNotNull);
      expect(Validators.serie(''), isNull); // opcional por defecto
    });
  });

  group('Contraseña', () {
    test('longitud mínima y máxima', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('123'), isNotNull);
      expect(Validators.password('x' * 73), isNotNull);
    });

    test('confirmación debe coincidir con la contraseña escrita', () {
      final valida = Validators.confirmacion(() => 'Clave2026');
      expect(valida('Clave2026'), isNull);
      expect(valida('clave2026'), isNotNull);
      expect(valida(''), isNotNull);
    });
  });

  group('Código de recuperación', () {
    test('solo dígitos, de 6 a 10', () {
      expect(Validators.codigoOtp('123456'), isNull);
      expect(Validators.codigoOtp(' 12345678 '), isNull);
      expect(Validators.codigoOtp('12345'), isNotNull);
      expect(Validators.codigoOtp('12345678901'), isNotNull);
      expect(Validators.codigoOtp('12a456'), isNotNull);
      expect(Validators.codigoOtp(''), isNotNull);
    });
  });
}
