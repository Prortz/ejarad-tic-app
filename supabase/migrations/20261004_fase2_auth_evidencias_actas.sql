-- ═══════════════════════════════════════════════════════════════════
-- EJARAD TIC · Fase 2
-- Auth real (perfiles), evidencias (Storage), equipo de proyecto,
-- actas de conformidad y catálogo editable.
--
-- Ejecutar UNA vez en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente: se puede volver a correr sin romper nada.
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- 1. PERFILES (vinculados a auth.users)
-- ───────────────────────────────────────────────────────────────────
alter table public.perfiles add column if not exists apellido       text;
alter table public.perfiles add column if not exists dni            text;
alter table public.perfiles add column if not exists cargo          text default 'Técnico de Campo';
alter table public.perfiles add column if not exists codigo_usuario text;
alter table public.perfiles add column if not exists activo         boolean not null default true;
alter table public.perfiles add column if not exists updated_at     timestamptz default now();

-- rol → texto con valores controlados (la tabla estaba vacía)
do $$
declare r record;
begin
  for r in
    select conname from pg_constraint
    where conrelid = 'public.perfiles'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%rol%'
  loop
    execute format('alter table public.perfiles drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.perfiles alter column rol drop default;
alter table public.perfiles alter column rol type text using rol::text;
alter table public.perfiles alter column rol set default 'Técnico';
alter table public.perfiles
  add constraint perfiles_rol_check check (rol in ('Admin', 'Supervisor', 'Técnico'));

create unique index if not exists perfiles_user_id_uidx on public.perfiles (user_id);

-- ¿Es admin el usuario autenticado?
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where user_id = auth.uid() and rol = 'Admin' and activo
  );
$$;

-- Crea automáticamente el perfil cuando se crea un usuario en Auth.
-- El PRIMER usuario que se registre será Admin (bootstrap).
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  meta  jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_rol text;
begin
  if not exists (select 1 from public.perfiles where rol = 'Admin') then
    v_rol := 'Admin';
  else
    v_rol := coalesce(nullif(meta->>'rol', ''), 'Técnico');
  end if;

  insert into public.perfiles
    (id, user_id, nombre, apellido, dni, telefono, correo, cargo, rol, codigo_usuario, activo)
  values (
    new.id, new.id,
    coalesce(nullif(meta->>'nombre', ''), split_part(new.email, '@', 1)),
    meta->>'apellido', meta->>'dni', meta->>'telefono', new.email,
    coalesce(nullif(meta->>'cargo', ''),
             case when v_rol = 'Admin' then 'Jefe de Proyectos' else 'Técnico de Campo' end),
    v_rol, meta->>'codigo_usuario', true
  )
  on conflict (id) do nothing;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: usuarios de Auth que ya existan y no tengan perfil
insert into public.perfiles (id, user_id, nombre, correo, cargo, rol, activo)
select u.id, u.id, split_part(u.email, '@', 1), u.email,
       'Jefe de Proyectos',
       case when not exists (select 1 from public.perfiles where rol = 'Admin')
            then 'Admin' else 'Técnico' end,
       true
from auth.users u
where not exists (select 1 from public.perfiles p where p.user_id = u.id)
on conflict (id) do nothing;

-- RLS de perfiles: todos los autenticados leen, solo Admin escribe
alter table public.perfiles enable row level security;
drop policy if exists "perfiles_select_auth" on public.perfiles;
drop policy if exists "perfiles_admin_write" on public.perfiles;
create policy "perfiles_select_auth" on public.perfiles
  for select to authenticated using (true);
create policy "perfiles_admin_write" on public.perfiles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());


-- ───────────────────────────────────────────────────────────────────
-- 2. Referencias a usuarios → perfiles(id)
--    (registrado_por, completado_por, lider_id, creado_por)
-- ───────────────────────────────────────────────────────────────────
do $$
declare r record;
begin
  for r in
    select tc.table_name, tc.constraint_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name
     and tc.table_schema   = kcu.table_schema
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema = 'public'
      and (   (tc.table_name = 'evidencias_proyecto' and kcu.column_name = 'registrado_por')
           or (tc.table_name = 'hitos_proyecto'      and kcu.column_name = 'completado_por')
           or (tc.table_name = 'proyectos'           and kcu.column_name = 'lider_id')
           or (tc.table_name = 'cotizaciones'        and kcu.column_name = 'creado_por'))
  loop
    execute format('alter table public.%I drop constraint %I', r.table_name, r.constraint_name);
  end loop;
end $$;

alter table public.evidencias_proyecto alter column registrado_por type uuid using nullif(registrado_por::text, '')::uuid;
alter table public.hitos_proyecto      alter column completado_por type uuid using nullif(completado_por::text, '')::uuid;
alter table public.proyectos           alter column lider_id       type uuid using nullif(lider_id::text, '')::uuid;
alter table public.cotizaciones        alter column creado_por     type uuid using nullif(creado_por::text, '')::uuid;

alter table public.evidencias_proyecto
  add constraint evidencias_registrado_por_fkey foreign key (registrado_por) references public.perfiles(id) on delete set null;
alter table public.hitos_proyecto
  add constraint hitos_completado_por_fkey foreign key (completado_por) references public.perfiles(id) on delete set null;
alter table public.proyectos
  add constraint proyectos_lider_id_fkey foreign key (lider_id) references public.perfiles(id) on delete set null;
alter table public.cotizaciones
  add constraint cotizaciones_creado_por_fkey foreign key (creado_por) references public.perfiles(id) on delete set null;


-- ───────────────────────────────────────────────────────────────────
-- 3. HITOS: completar sin evidencia + observaciones
-- ───────────────────────────────────────────────────────────────────
alter table public.hitos_proyecto add column if not exists observaciones            text;
alter table public.hitos_proyecto add column if not exists completado_sin_evidencia boolean not null default false;
alter table public.hitos_proyecto add column if not exists motivo_sin_evidencia     text;


-- ───────────────────────────────────────────────────────────────────
-- 4. EQUIPO DEL PROYECTO
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.proyecto_equipo (
  id              uuid primary key default gen_random_uuid(),
  proyecto_id     uuid not null references public.proyectos(id) on delete cascade,
  perfil_id       uuid not null references public.perfiles(id)  on delete cascade,
  rol_en_proyecto text not null default 'Técnico'
                  check (rol_en_proyecto in ('Líder', 'Técnico', 'Supervisor')),
  created_at      timestamptz not null default now(),
  unique (proyecto_id, perfil_id)
);
alter table public.proyecto_equipo enable row level security;


-- ───────────────────────────────────────────────────────────────────
-- 5. ACTAS DE CONFORMIDAD (registro de proyectos culminados)
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.actas_conformidad (
  id                   uuid primary key default gen_random_uuid(),
  codigo_acta          text not null unique,
  proyecto_id          uuid not null unique references public.proyectos(id) on delete cascade,
  codigo_proyecto      text,
  nombre_obra          text,
  cliente_id           uuid references public.clientes(id) on delete set null,
  cliente_razon_social text,
  cliente_ruc          text,
  firmante_nombre      text not null,
  firmante_documento   text,
  firmante_cargo       text,
  observaciones        text,
  equipo               jsonb not null default '[]'::jsonb,  -- snapshot [{nombre, rol, cargo}]
  firma_path           text,
  pdf_path             text,
  pdf_url              text,
  fecha_cierre         timestamptz not null default now(),
  generado_por         uuid references public.perfiles(id) on delete set null,
  created_at           timestamptz not null default now()
);
alter table public.actas_conformidad enable row level security;


-- ───────────────────────────────────────────────────────────────────
-- 6. CATÁLOGO: categoría / unidad como texto (si eran ENUM)
-- ───────────────────────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'catalogo_precios'
               and column_name = 'categoria' and data_type = 'USER-DEFINED') then
    alter table public.catalogo_precios alter column categoria type text using categoria::text;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'catalogo_precios'
               and column_name = 'unidad_medida' and data_type = 'USER-DEFINED') then
    alter table public.catalogo_precios alter column unidad_medida type text using unidad_medida::text;
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- 7. Acceso para usuarios autenticados en tablas operativas
--    (ahora la app trabaja con sesión, no con anon)
-- ───────────────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'clientes', 'direcciones_clientes', 'cotizaciones', 'cotizacion_detalles',
    'proyectos', 'proyecto_materiales', 'hitos_proyecto', 'evidencias_proyecto',
    'catalogo_precios', 'proyecto_equipo', 'actas_conformidad'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop policy if exists "ejarad_auth_all" on public.%I', t);
      execute format(
        'create policy "ejarad_auth_all" on public.%I for all to authenticated using (true) with check (true)', t);
    end if;
  end loop;
end $$;


-- ───────────────────────────────────────────────────────────────────
-- 8. STORAGE: buckets de evidencias y actas
-- ───────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit)
values ('evidencias-hitos', 'evidencias-hitos', true, 10485760)
on conflict (id) do update set public = true, file_size_limit = 10485760;

insert into storage.buckets (id, name, public, file_size_limit)
values ('actas', 'actas', true, 20971520)
on conflict (id) do update set public = true, file_size_limit = 20971520;

drop policy if exists "ejarad_storage_select" on storage.objects;
drop policy if exists "ejarad_storage_insert" on storage.objects;
drop policy if exists "ejarad_storage_update" on storage.objects;
drop policy if exists "ejarad_storage_delete" on storage.objects;

create policy "ejarad_storage_select" on storage.objects
  for select to authenticated using (bucket_id in ('evidencias-hitos', 'actas'));
create policy "ejarad_storage_insert" on storage.objects
  for insert to authenticated with check (bucket_id in ('evidencias-hitos', 'actas'));
create policy "ejarad_storage_update" on storage.objects
  for update to authenticated using (bucket_id in ('evidencias-hitos', 'actas'));
create policy "ejarad_storage_delete" on storage.objects
  for delete to authenticated using (bucket_id in ('evidencias-hitos', 'actas'));

-- Refrescar caché de esquema de la API
notify pgrst, 'reload schema';
