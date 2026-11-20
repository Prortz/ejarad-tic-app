// Pruebas de la elección de insumos por categoría (ANSI/TIA-568.2-E: el canal
// se certifica por el componente de menor categoría, por eso cable, jacks,
// patch panels y patch cords deben ser de la misma categoría).
import 'package:ejarad_app/services/catalogo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _it(String sku, String desc, String cat) =>
    {'sku': sku, 'descripcion': desc, 'categoria': cat, 'activo': true};

final _cable6 = _it('CAB-CAT6-INT', 'Cable UTP Cat 6 Interior 24 AWG caja 305 m', 'cableado');
final _cable6a = _it('CAB-CAT6A-OUT', 'Cable UTP Cat 6A Exterior blindado caja 305 m', 'cableado');
final _cable5e = _it('CAB-CAT5E-INT', 'Cable UTP Cat 5e Interior 24 AWG caja 305 m', 'cableado');
final _jack6 = _it('JCK-CAT6-RJ45', 'Jack Keystone RJ45 Cat 6 Hembra', 'conectividad');
final _jack6a = _it('JCK-CAT6A-RJ45', 'Jack Keystone RJ45 Cat 6A blindado', 'conectividad');
final _pc6 = _it('PAT-CAT6-1M', 'Patch Cord Cat 6 1m Azul', 'conectividad');

const _otras = {'6a', 'cat6a', '5e', 'cat5e'};

void main() {
  group('Cable por categoría', () {
    final cat = [_cable6, _cable6a];

    test('Cat 6 elige el cable Cat 6 y nunca el 6A', () {
      final r = CatalogoRepository.buscarMejor(cat, 'Cat 6 UTP Interior',
          categoria: 'cableado', excluidos: _otras);
      expect(r?['sku'], 'CAB-CAT6-INT');
    });

    test('Cat 6A elige el cable 6A', () {
      final r = CatalogoRepository.buscarMejor(cat, 'Cat 6A Exterior Blindado',
          categoria: 'cableado', algunoDe: {'6a', 'cat6a'});
      expect(r?['sku'], 'CAB-CAT6A-OUT');
    });

    test('Cat 5e sin cable 5e en el catálogo no cae en un cable Cat 6', () {
      final r = CatalogoRepository.buscarMejor(cat, 'Cat 5e UTP',
          categoria: 'cableado', algunoDe: {'5e', 'cat5e'});
      expect(r, isNull);
    });

    test('Cat 5e con cable 5e en el catálogo lo elige', () {
      final r = CatalogoRepository.buscarMejor([...cat, _cable5e], 'Cat 5e UTP',
          categoria: 'cableado', algunoDe: {'5e', 'cat5e'});
      expect(r?['sku'], 'CAB-CAT5E-INT');
    });
  });

  group('Conectividad por categoría', () {
    test('Cat 6A no usa jacks Cat 6', () {
      final r = CatalogoRepository.buscarMejor([_jack6, _pc6], 'Jack RJ45 Keystone',
          categoria: 'conectividad', algunoDe: {'6a', 'cat6a'});
      expect(r, isNull);
    });

    test('Cat 6A usa el jack 6A cuando existe', () {
      final r = CatalogoRepository.buscarMejor([_jack6, _jack6a], 'Jack RJ45 Keystone',
          categoria: 'conectividad', algunoDe: {'6a', 'cat6a'});
      expect(r?['sku'], 'JCK-CAT6A-RJ45');
    });

    test('Cat 6 no usa jacks 6A aunque sean más completos', () {
      final r = CatalogoRepository.buscarMejor([_jack6a, _jack6], 'Jack RJ45 Keystone',
          categoria: 'conectividad', excluidos: _otras);
      expect(r?['sku'], 'JCK-CAT6-RJ45');
    });
  });

  group('Búsqueda por SKU leído desde un QR', () {
    final cat = [_cable6, _jack6];

    test('coincidencia exacta y contenida', () {
      expect(CatalogoRepository.buscarPorSku(cat, 'JCK-CAT6-RJ45')?['sku'], 'JCK-CAT6-RJ45');
      expect(CatalogoRepository.buscarPorSku(cat, 'lote-2026/jck-cat6-rj45/0042')?['sku'],
          'JCK-CAT6-RJ45');
    });

    test('código desconocido o vacío no devuelve nada', () {
      expect(CatalogoRepository.buscarPorSku(cat, 'XYZ-999'), isNull);
      expect(CatalogoRepository.buscarPorSku(cat, '  '), isNull);
    });
  });
}
