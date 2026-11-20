-- ═══════════════════════════════════════════════════════════════════
-- EJARAD TIC · Fase 5
-- Estados de proyecto que usa la aplicación.
--
-- La app cambia el estado de una obra a 'Pausado' (menú ⋮ → Pausar) y a
-- 'Completado' (al generar el acta de conformidad). El enum original
-- estado_proyecto solo incluía: Pendiente, En Proceso, Certificado,
-- Liquidado y Cancelado. Esta migración añade los dos que faltan.
--
-- Es idempotente (IF NOT EXISTS): si ya existen no hace nada.
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
--
-- Para comprobar el estado actual:
--   select e.enumlabel from pg_enum e
--   join pg_type t on t.oid = e.enumtypid
--   where t.typname = 'estado_proyecto' order by e.enumsortorder;
-- ═══════════════════════════════════════════════════════════════════

alter type public.estado_proyecto add value if not exists 'Pausado';
alter type public.estado_proyecto add value if not exists 'Completado';
