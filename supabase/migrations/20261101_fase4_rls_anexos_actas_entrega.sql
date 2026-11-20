-- ═══════════════════════════════════════════════════════════════════
-- EJARAD TIC · Fase 4
-- · Cierra las políticas abiertas "Permitir acceso total…" (rol public,
--   que incluye anon) en anexos_proyecto, anexo_detalles y actas_entrega.
-- · Aplica el mismo criterio de Privilegio Mínimo de la Fase 3.
--
-- Ejecutar UNA vez en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente. Requiere haber ejecutado antes la Fase 3
-- (funciones is_gestor, is_admin, puede_ver_proyecto).
-- ═══════════════════════════════════════════════════════════════════

-- 1. Eliminar TODAS las políticas previas de estas tablas
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('anexos_proyecto', 'anexo_detalles', 'actas_entrega')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.anexos_proyecto enable row level security;
alter table public.anexo_detalles  enable row level security;
alter table public.actas_entrega   enable row level security;

-- Sin acceso para usuarios no autenticados
revoke all on public.anexos_proyecto, public.anexo_detalles, public.actas_entrega from anon;

-- 2. anexos_proyecto: lectura del equipo del proyecto; escritura solo gestores
create policy anexos_select on public.anexos_proyecto
  for select to authenticated using (public.puede_ver_proyecto(proyecto_id));
create policy anexos_write on public.anexos_proyecto
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

-- 3. anexo_detalles: hereda el permiso del anexo
create policy anexo_detalles_select on public.anexo_detalles
  for select to authenticated using (
    exists (select 1 from public.anexos_proyecto a
            where a.id = anexo_detalles.anexo_id and public.puede_ver_proyecto(a.proyecto_id)));
create policy anexo_detalles_write on public.anexo_detalles
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

-- 4. actas_entrega: tabla heredada (la app usa actas_conformidad).
--    Contiene DNI y firma del cliente (Ley N° 29733): solo Admin.
create policy actas_entrega_admin on public.actas_entrega
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
