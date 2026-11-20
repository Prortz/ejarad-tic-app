-- ═══════════════════════════════════════════════════════════════════
-- EJARAD TIC · Fase 3
-- · RLS por ROL (Admin/Supervisor vs Técnico) — Privilegio Mínimo
-- · Protección de datos personales (DNI) y firmas — Ley N° 29733
-- · Trazabilidad: precisión GPS, serie/QR, sello de captura, columna PostGIS
-- · Correlativo de cotización COT-AAAA-NNN
-- · Imprevistos y coordenadas del nodo central
--
-- Ejecutar UNA vez en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente: se puede volver a correr sin romper nada.
-- Requiere haber ejecutado antes 20261004_fase2_auth_evidencias_actas.sql
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- 1. FUNCIONES AUXILIARES (SECURITY DEFINER → evitan recursión de RLS)
-- ───────────────────────────────────────────────────────────────────
create or replace function public.mi_perfil_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.perfiles where user_id = auth.uid() and activo limit 1;
$$;

create or replace function public.is_gestor()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where user_id = auth.uid() and rol in ('Admin', 'Supervisor') and activo
  );
$$;

create or replace function public.es_miembro_proyecto(p_proyecto uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
           select 1 from public.proyecto_equipo pe
           where pe.proyecto_id = p_proyecto and pe.perfil_id = public.mi_perfil_id())
      or exists (
           select 1 from public.proyectos pr
           where pr.id = p_proyecto and pr.lider_id = public.mi_perfil_id());
$$;

create or replace function public.puede_ver_proyecto(p_proyecto uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_gestor() or public.es_miembro_proyecto(p_proyecto);
$$;

create or replace function public.proyecto_de_hito(p_hito uuid)
returns uuid
language sql stable security definer set search_path = public
as $$
  select proyecto_id from public.hitos_proyecto where id = p_hito;
$$;

grant execute on function
  public.mi_perfil_id(), public.is_gestor(), public.es_miembro_proyecto(uuid),
  public.puede_ver_proyecto(uuid), public.proyecto_de_hito(uuid)
to authenticated;


-- ───────────────────────────────────────────────────────────────────
-- 2. COLUMNAS NUEVAS
-- ───────────────────────────────────────────────────────────────────
-- Trazabilidad en campo
alter table public.evidencias_proyecto add column if not exists precision_m   double precision;
alter table public.evidencias_proyecto add column if not exists numero_serie  text;
alter table public.evidencias_proyecto add column if not exists qr_payload    text;
alter table public.evidencias_proyecto add column if not exists capturado_en  timestamptz default now();

-- Coordenadas del nodo central y imprevistos
alter table public.proyectos     add column if not exists latitud_nodo  double precision;
alter table public.proyectos     add column if not exists longitud_nodo double precision;
alter table public.cotizaciones  add column if not exists latitud_nodo  double precision;
alter table public.cotizaciones  add column if not exists longitud_nodo double precision;
alter table public.cotizaciones  add column if not exists imprevistos_porcentaje numeric default 0;
alter table public.cotizaciones  add column if not exists imprevistos            numeric default 0;

-- Rangos válidos de coordenadas (solo filas nuevas / modificadas)
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'evidencias_coord_chk') then
    alter table public.evidencias_proyecto
      add constraint evidencias_coord_chk
      check ((latitud is null or latitud between -90 and 90)
         and (longitud is null or longitud between -180 and 180)) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'catalogo_precios_chk') then
    alter table public.catalogo_precios
      add constraint catalogo_precios_chk
      check (costo_base >= 0 and precio_venta_default >= 0) not valid;
  end if;
end $$;

-- Código de cotización único
do $$
begin
  create unique index if not exists cotizaciones_codigo_uidx
    on public.cotizaciones (codigo_cotizacion);
exception when others then
  raise notice 'No se pudo crear índice único de cotizaciones (¿códigos duplicados?): %', sqlerrm;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- 3. PostGIS: columna geográfica ligada al hito de obra
-- ───────────────────────────────────────────────────────────────────
do $$
declare v_schema text;
begin
  begin
    create extension if not exists postgis with schema extensions;
  exception when others then
    raise notice 'PostGIS no disponible: %', sqlerrm;
  end;

  select n.nspname into v_schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
  where e.extname = 'postgis';
  if v_schema is null then return; end if;

  execute format(
    'alter table public.evidencias_proyecto add column if not exists ubicacion %I.geography(Point,4326)',
    v_schema);

  execute format($f$
    create or replace function public.trg_evidencia_ubicacion()
    returns trigger language plpgsql as $b$
    begin
      if new.latitud is not null and new.longitud is not null then
        new.ubicacion := %1$I.st_setsrid(%1$I.st_makepoint(new.longitud, new.latitud), 4326)::%1$I.geography;
      else
        new.ubicacion := null;
      end if;
      return new;
    end $b$;
  $f$, v_schema);

  drop trigger if exists evidencia_set_ubicacion on public.evidencias_proyecto;
  create trigger evidencia_set_ubicacion
    before insert or update of latitud, longitud on public.evidencias_proyecto
    for each row execute function public.trg_evidencia_ubicacion();

  update public.evidencias_proyecto set latitud = latitud
  where latitud is not null and longitud is not null and ubicacion is null;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- 4. VISTA PÚBLICA DE PERSONAL (sin DNI)
-- ───────────────────────────────────────────────────────────────────
create or replace view public.perfiles_publico as
  select id, user_id, nombre, apellido, cargo, rol, codigo_usuario, activo
  from public.perfiles;

revoke all on public.perfiles_publico from anon;
grant select on public.perfiles_publico to authenticated;


-- ───────────────────────────────────────────────────────────────────
-- 5. CORRELATIVO DE COTIZACIÓN  COT-AAAA-NNN
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.correlativos (
  clave  text primary key,
  ultimo integer not null default 0
);
alter table public.correlativos enable row level security;   -- sin políticas: solo vía RPC

create or replace function public.siguiente_codigo_cotizacion()
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_anio  text := to_char(now() at time zone 'America/Lima', 'YYYY');
  v_clave text;
  v_max   integer;
  v_n     integer;
begin
  if not public.is_gestor() then
    raise exception 'Sin permiso para generar cotizaciones';
  end if;
  v_clave := 'COT-' || v_anio;

  select coalesce(max((regexp_match(codigo_cotizacion, '^COT-' || v_anio || '-(\d+)$'))[1]::int), 0)
    into v_max from public.cotizaciones;

  insert into public.correlativos (clave, ultimo) values (v_clave, v_max)
  on conflict (clave) do update set ultimo = greatest(public.correlativos.ultimo, excluded.ultimo);

  update public.correlativos set ultimo = ultimo + 1
  where clave = v_clave returning ultimo into v_n;

  return v_clave || '-' || lpad(v_n::text, 3, '0');
end $$;

grant execute on function public.siguiente_codigo_cotizacion() to authenticated;


-- ───────────────────────────────────────────────────────────────────
-- 6. RLS POR ROL
--    Se eliminan TODAS las políticas previas (incluidas las abiertas
--    "ejarad_auth_all" y cualquier política anon) y se recrean.
-- ───────────────────────────────────────────────────────────────────
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in (
        'perfiles', 'catalogo_precios', 'clientes', 'direcciones_clientes',
        'cotizaciones', 'cotizacion_detalles', 'proyectos', 'proyecto_materiales',
        'hitos_proyecto', 'evidencias_proyecto', 'proyecto_equipo', 'actas_conformidad')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.perfiles              enable row level security;
alter table public.catalogo_precios      enable row level security;
alter table public.clientes              enable row level security;
alter table public.direcciones_clientes  enable row level security;
alter table public.cotizaciones          enable row level security;
alter table public.cotizacion_detalles   enable row level security;
alter table public.proyectos             enable row level security;
alter table public.proyecto_materiales   enable row level security;
alter table public.hitos_proyecto        enable row level security;
alter table public.evidencias_proyecto   enable row level security;
alter table public.proyecto_equipo       enable row level security;
alter table public.actas_conformidad     enable row level security;

-- ── perfiles: cada quien ve el suyo (con DNI); Admin ve y escribe todo ──
create policy perfiles_select_propio_o_admin on public.perfiles
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy perfiles_admin_write on public.perfiles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ── catálogo: lectura para todos; escritura solo Admin/Supervisor ──
create policy catalogo_select on public.catalogo_precios
  for select to authenticated using (true);
create policy catalogo_insert on public.catalogo_precios
  for insert to authenticated with check (public.is_gestor());
create policy catalogo_update on public.catalogo_precios
  for update to authenticated using (public.is_gestor()) with check (public.is_gestor());
create policy catalogo_delete on public.catalogo_precios
  for delete to authenticated using (public.is_gestor());

-- ── clientes y direcciones: gestores todo; técnico solo los de sus obras ──
create policy clientes_select on public.clientes
  for select to authenticated using (
    public.is_gestor() or exists (
      select 1 from public.proyectos pr
      where pr.cliente_id = clientes.id and public.es_miembro_proyecto(pr.id)));
create policy clientes_write on public.clientes
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

create policy direcciones_select on public.direcciones_clientes
  for select to authenticated using (
    public.is_gestor() or exists (
      select 1 from public.proyectos pr
      where pr.cliente_id = direcciones_clientes.cliente_id and public.es_miembro_proyecto(pr.id)));
create policy direcciones_write on public.direcciones_clientes
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

-- ── cotizaciones (precios y márgenes): solo Admin/Supervisor ──
create policy cotizaciones_gestor on public.cotizaciones
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());
create policy cotizacion_detalles_gestor on public.cotizacion_detalles
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

-- ── proyectos ──
create policy proyectos_select on public.proyectos
  for select to authenticated using (public.puede_ver_proyecto(id));
create policy proyectos_insert on public.proyectos
  for insert to authenticated with check (public.is_gestor());
create policy proyectos_update on public.proyectos
  for update to authenticated using (public.puede_ver_proyecto(id)) with check (public.puede_ver_proyecto(id));
create policy proyectos_delete on public.proyectos
  for delete to authenticated using (public.is_gestor());

-- ── materiales / metrados del proyecto ──
create policy materiales_select on public.proyecto_materiales
  for select to authenticated using (public.puede_ver_proyecto(proyecto_id));
create policy materiales_insert on public.proyecto_materiales
  for insert to authenticated with check (public.is_gestor());
create policy materiales_update on public.proyecto_materiales
  for update to authenticated using (public.puede_ver_proyecto(proyecto_id))
  with check (public.puede_ver_proyecto(proyecto_id));
create policy materiales_delete on public.proyecto_materiales
  for delete to authenticated using (public.is_gestor());

-- ── hitos ──
create policy hitos_select on public.hitos_proyecto
  for select to authenticated using (public.puede_ver_proyecto(proyecto_id));
create policy hitos_insert on public.hitos_proyecto
  for insert to authenticated with check (public.is_gestor());
create policy hitos_update on public.hitos_proyecto
  for update to authenticated using (public.puede_ver_proyecto(proyecto_id))
  with check (public.puede_ver_proyecto(proyecto_id));
create policy hitos_delete on public.hitos_proyecto
  for delete to authenticated using (public.is_gestor());

-- ── evidencias: el técnico SOLO inserta/actualiza lo que él registró ──
create policy evidencias_select on public.evidencias_proyecto
  for select to authenticated using (public.puede_ver_proyecto(public.proyecto_de_hito(hito_id)));
create policy evidencias_insert on public.evidencias_proyecto
  for insert to authenticated with check (
    public.puede_ver_proyecto(public.proyecto_de_hito(hito_id))
    and registrado_por = public.mi_perfil_id());
create policy evidencias_update on public.evidencias_proyecto
  for update to authenticated
  using (public.is_gestor() or registrado_por = public.mi_perfil_id())
  with check (public.is_gestor() or registrado_por = public.mi_perfil_id());
create policy evidencias_delete on public.evidencias_proyecto
  for delete to authenticated
  using (public.is_gestor() or registrado_por = public.mi_perfil_id());

-- ── equipo de proyecto: lectura del equipo propio; escritura solo gestores ──
create policy equipo_select on public.proyecto_equipo
  for select to authenticated using (public.puede_ver_proyecto(proyecto_id));
create policy equipo_write on public.proyecto_equipo
  for all to authenticated using (public.is_gestor()) with check (public.is_gestor());

-- ── actas (firma + DNI del firmante) ──
create policy actas_select on public.actas_conformidad
  for select to authenticated using (public.puede_ver_proyecto(proyecto_id));
create policy actas_insert on public.actas_conformidad
  for insert to authenticated with check (
    public.puede_ver_proyecto(proyecto_id) and generado_por = public.mi_perfil_id());
create policy actas_update on public.actas_conformidad
  for update to authenticated using (public.puede_ver_proyecto(proyecto_id))
  with check (public.puede_ver_proyecto(proyecto_id));
create policy actas_delete on public.actas_conformidad
  for delete to authenticated using (public.is_admin());


-- ───────────────────────────────────────────────────────────────────
-- 7. STORAGE
--    · evidencias-hitos: público de lectura (fotos de obra), escritura solo
--      miembros del proyecto (ruta proyectos/<proyecto_id>/...).
--    · actas: PRIVADO (contiene DNI y firmas): acceso solo por miembros del
--      proyecto (ruta <codigo_proyecto>/...). La app descarga con sesión.
-- ───────────────────────────────────────────────────────────────────
update storage.buckets set public = false where id = 'actas';

drop policy if exists "ejarad_storage_select" on storage.objects;
drop policy if exists "ejarad_storage_insert" on storage.objects;
drop policy if exists "ejarad_storage_update" on storage.objects;
drop policy if exists "ejarad_storage_delete" on storage.objects;
drop policy if exists "ejarad_evid_select"    on storage.objects;
drop policy if exists "ejarad_evid_insert"    on storage.objects;
drop policy if exists "ejarad_evid_update"    on storage.objects;
drop policy if exists "ejarad_evid_delete"    on storage.objects;
drop policy if exists "ejarad_actas_select"   on storage.objects;
drop policy if exists "ejarad_actas_insert"   on storage.objects;
drop policy if exists "ejarad_actas_update"   on storage.objects;
drop policy if exists "ejarad_actas_delete"   on storage.objects;

create policy "ejarad_evid_select" on storage.objects
  for select to authenticated using (bucket_id = 'evidencias-hitos');
create policy "ejarad_evid_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'evidencias-hitos' and exists (
      select 1 from public.proyectos pr
      where pr.id::text = (storage.foldername(name))[2] and public.puede_ver_proyecto(pr.id)));
create policy "ejarad_evid_update" on storage.objects
  for update to authenticated using (
    bucket_id = 'evidencias-hitos' and exists (
      select 1 from public.proyectos pr
      where pr.id::text = (storage.foldername(name))[2] and public.puede_ver_proyecto(pr.id)));
create policy "ejarad_evid_delete" on storage.objects
  for delete to authenticated using (bucket_id = 'evidencias-hitos' and public.is_gestor());

create policy "ejarad_actas_select" on storage.objects
  for select to authenticated using (
    bucket_id = 'actas' and exists (
      select 1 from public.proyectos pr
      where pr.codigo_proyecto = (storage.foldername(name))[1] and public.puede_ver_proyecto(pr.id)));
create policy "ejarad_actas_insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'actas' and exists (
      select 1 from public.proyectos pr
      where pr.codigo_proyecto = (storage.foldername(name))[1] and public.puede_ver_proyecto(pr.id)));
create policy "ejarad_actas_update" on storage.objects
  for update to authenticated using (
    bucket_id = 'actas' and exists (
      select 1 from public.proyectos pr
      where pr.codigo_proyecto = (storage.foldername(name))[1] and public.puede_ver_proyecto(pr.id)));
create policy "ejarad_actas_delete" on storage.objects
  for delete to authenticated using (bucket_id = 'actas' and public.is_admin());

-- Refrescar caché de esquema de la API
notify pgrst, 'reload schema';
