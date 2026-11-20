-- ═══════════════════════════════════════════════════════════════════
-- EJARAD TIC · Catálogo de precios: componentes Cat 6A y cable Cat 5e
--
-- Por qué: el cotizador elige jacks, patch panels y patch cords de la MISMA
-- categoría que el cable (ANSI/TIA-568.2-E: el canal se certifica por el
-- componente de menor categoría). El catálogo solo tenía el cable Cat 6A, así
-- que con ese cable el BOM salía con ítems referenciales sin precio de catálogo.
--
-- PRECIOS: son de tiendas peruanas consultadas el 19/11/2026 (soles, IGV
-- incluido en la tienda). Aquí se guardan SIN IGV (precio ÷ 1,18) porque el
-- cotizador suma imprevistos, margen comercial e IGV al final.
-- costo_base y precio_venta_default llevan el mismo valor (precio de tienda):
-- el cotizador usa precio_venta_default como precio unitario de material y
-- aplica el margen después, así que un recargo aquí se cobraría dos veces.
-- Las tiendas actualizan sus precios a diario: confirma con tu proveedor.
--
-- Fuentes (página del producto):
--   JCK-CAT6A-RJ45  Nexxt NXM-STS00 (Cat 6A, blindado)        S/ 36,17  panacompu.com/peru
--   PAT-CAT6A-1M    Nexxt NAB-PCS6A3FBL (Cat 6A S/FTP, 90 cm)  S/ 29,39  panacompu.com/peru
--   PAT-CAT6A-2M    Nexxt NAB-PCS6A7FBL (Cat 6A S/FTP, 2,1 m)  S/ 34,56  panacompu.com/peru
--   CAB-CAT5E-INT   Xtech XTC-220 (Cat 5e UTP, 305 m)          S/ 212,54 panacompu.com/peru
--   PNL-CAT6A-24    Nexxt AW191NXT06 (24 p, 1U, Cat 6)         S/ 209,18 panacompu.com/peru
--   PNL-CAT6A-48    Nexxt AW192NXT40 (48 p, 2U, Cat 6)         S/ 441,01 panacompu.com/peru
--
-- LIMITES:
--  · No se encontró ningún patch panel Cat 6A con precio en soles. Los dos
--    paneles usan el precio del modelo Cat 6 equivalente, que es una COTA
--    INFERIOR (el Cat 6A suele costar más). Por eso se insertan INACTIVOS:
--    pide cotización de un panel Cat 6A a tu distribuidor, corrige el precio
--    en la app (Operaciones → Catálogo → lápiz) y actívalos con el interruptor.
--  · Los patch cords de 1 m y 2 m usan los modelos de 90 cm y 2,1 m, que son
--    los más cercanos que la tienda publica.
--  · Los demás ítems (jack, patch cords y cable Cat 5e) quedan ACTIVOS.
--
-- Cómo usarlo: Supabase → SQL Editor → pegar y ejecutar. Es idempotente: si
-- el SKU ya existe no hace nada.
-- Con cable Cat 5e los jacks, patch panels y patch cords se toman de Cat 6
-- (un componente de categoría superior es válido en un enlace Cat 5e).
-- ═══════════════════════════════════════════════════════════════════

insert into public.catalogo_precios
  (sku, descripcion, categoria, unidad_medida, costo_base, precio_venta_default, activo)
values
  -- Cat 6A (blindado, para el cable "Cat 6A Exterior Blindado")
  ('JCK-CAT6A-RJ45', 'Jack Keystone RJ45 Cat 6A blindado',          'conectividad', 'und',        30.65,  30.65, true),
  ('PAT-CAT6A-1M',   'Patch Cord Cat 6A S/FTP 1m',                  'conectividad', 'und',        24.91,  24.91, true),
  ('PAT-CAT6A-2M',   'Patch Cord Cat 6A S/FTP 2m',                  'conectividad', 'und',        29.29,  29.29, true),
  ('PNL-CAT6A-24',   'Patch Panel 24 Puertos Cat 6A blindado 1U',   'conectividad', 'und',       177.27, 177.27, false),
  ('PNL-CAT6A-48',   'Patch Panel 48 Puertos Cat 6A blindado 2U',   'conectividad', 'und',       373.74, 373.74, false),
  -- Cat 5e
  ('CAB-CAT5E-INT',  'Cable UTP Cat 5e Interior 24 AWG caja 305 m', 'cableado',     'caja_305m', 180.12, 180.12, true)
on conflict (sku) do nothing;

-- Comprobación:
--   select sku, descripcion, costo_base, precio_venta_default, activo
--   from public.catalogo_precios
--   where sku in ('JCK-CAT6A-RJ45','PAT-CAT6A-1M','PAT-CAT6A-2M','PNL-CAT6A-24','PNL-CAT6A-48','CAB-CAT5E-INT');
