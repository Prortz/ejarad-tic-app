// supabase/functions/admin-users/index.ts
// ═══════════════════════════════════════════════════════════════════
// Gestión de usuarios para EJARAD TIC (solo rol Admin).
//
//   POST { action: 'create', email, password, nombre, apellido, dni,
//          telefono, cargo, rol, codigo_usuario }
//   POST { action: 'update', user_id, email?, password?, activo?,
//          nombre?, apellido?, dni?, telefono?, cargo?, rol?, codigo_usuario? }
//
// Usa la SERVICE ROLE KEY (disponible automáticamente en Edge Functions),
// por eso esta lógica no puede vivir en la app Flutter.
// ═══════════════════════════════════════════════════════════════════
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PERFIL_FIELDS = [
  'nombre', 'apellido', 'dni', 'telefono', 'cargo', 'rol', 'codigo_usuario', 'activo',
];
const ROLES = ['Admin', 'Supervisor', 'Técnico'];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    // 1. ¿Quién llama?
    const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
    const { data: { user }, error: authErr } = await admin.auth.getUser(token);
    if (authErr || !user) return json({ error: 'Sesión no válida. Vuelve a iniciar sesión.' }, 401);

    const { data: me } = await admin
      .from('perfiles').select('rol, activo').eq('user_id', user.id).maybeSingle();
    if (!me || me.rol !== 'Admin' || me.activo === false) {
      return json({ error: 'Solo un Admin puede gestionar usuarios.' }, 403);
    }

    // 2. Datos
    const body = await req.json();
    const perfil: Record<string, unknown> = {};
    for (const f of PERFIL_FIELDS) if (body[f] !== undefined) perfil[f] = body[f];
    if (perfil.rol !== undefined && !ROLES.includes(String(perfil.rol))) {
      return json({ error: `Rol inválido: ${perfil.rol}` }, 400);
    }
    if (body.password !== undefined && body.password !== null && body.password !== '' &&
        String(body.password).length < 6) {
      return json({ error: 'La contraseña debe tener al menos 6 caracteres.' }, 400);
    }

    // Duplicados de DNI / código antes de tocar Auth (el trigger de perfiles
    // fallaría con un genérico "Database error creating new user").
    const excluir = body.action === 'update' ? (body.user_id as string | undefined) : undefined;
    const duplicado = async (filtro: string) => {
      let q = admin.from('perfiles').select('user_id').or(filtro).limit(1);
      if (excluir) q = q.neq('user_id', excluir);
      const { data } = await q;
      return (data ?? []).length > 0;
    };
    const dni = String(perfil.dni ?? '').trim();
    if (dni && await duplicado(`dni.eq.${dni},numero_documento.eq.${dni}`)) {
      return json({ error: `Ya existe un usuario registrado con el DNI ${dni}.` }, 409);
    }
    const codigo = String(perfil.codigo_usuario ?? '').trim();
    if (codigo && await duplicado(`codigo_usuario.eq.${codigo}`)) {
      return json({ error: `El código de usuario ${codigo} ya está asignado a otra persona.` }, 409);
    }

    // 3. Crear
    if (body.action === 'create') {
      const email = String(body.email ?? '').trim().toLowerCase();
      if (!email || !body.password) {
        return json({ error: 'Correo y contraseña son obligatorios.' }, 400);
      }
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: String(body.password),
        email_confirm: true,
        user_metadata: perfil,
      });
      if (error) {
        const msg = /already|registered|exists/i.test(error.message)
          ? 'Ya existe un usuario con ese correo.'
          : error.message;
        return json({ error: msg }, 400);
      }
      const uid = data.user!.id;
      // El trigger crea el perfil; aquí garantizamos todos los campos.
      const { error: upErr } = await admin.from('perfiles').upsert(
        { id: uid, user_id: uid, correo: email, ...perfil, updated_at: new Date().toISOString() },
        { onConflict: 'id' },
      );
      if (upErr) return json({ error: upErr.message }, 400);
      return json({ ok: true, user_id: uid });
    }

    // 4. Actualizar
    if (body.action === 'update') {
      const uid = body.user_id as string | undefined;
      if (!uid) return json({ error: 'user_id requerido.' }, 400);

      if (uid === user.id && (body.activo === false || (body.rol && body.rol !== 'Admin'))) {
        return json({ error: 'No puedes desactivarte ni quitarte el rol Admin a ti mismo.' }, 400);
      }

      const authUpdate: Record<string, unknown> = {};
      const email = body.email ? String(body.email).trim().toLowerCase() : undefined;
      if (email) { authUpdate.email = email; authUpdate.email_confirm = true; }
      if (body.password) authUpdate.password = String(body.password);
      if (body.activo !== undefined) authUpdate.ban_duration = body.activo ? 'none' : '876000h';

      if (Object.keys(authUpdate).length > 0) {
        const { error } = await admin.auth.admin.updateUserById(uid, authUpdate);
        if (error) return json({ error: error.message }, 400);
      }

      const upd: Record<string, unknown> = { ...perfil, updated_at: new Date().toISOString() };
      if (email) upd.correo = email;
      const { error } = await admin.from('perfiles').update(upd).eq('user_id', uid);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: 'Acción no válida.' }, 400);
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
