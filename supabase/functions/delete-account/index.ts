// Supabase Edge Function — delete-account
// Exclusão de conta iniciada pelo próprio usuário (exigência Apple 5.1.1(v) e
// Google Play "Data deletion"). Auth pelo JWT do usuário; a exclusão em si
// roda com service role:
//   1. apaga os arquivos de Storage do usuário — avatar em `profire` e áudios
//      em `audios-mentor` — porque o ON DELETE CASCADE não alcança o Storage;
//   2. remove pendências por e-mail (`pending_entitlements`, sem FK);
//   3. auth.admin.deleteUser(uid) — todas as tabelas com FK para auth.users
//      (profiles, mensagens, reflexoes, praticas, pratica_completadas,
//      relatorios_semanais, subscriptions, uso_ia, cron_relatorios_fila)
//      caem pelo cascade.
//
// A assinatura na loja NÃO é cancelada aqui — Apple/Google não expõem isso ao
// servidor; a UI instrui o usuário a cancelar nos ajustes da loja.
//
// Contrato:
//   POST {}   (sem corpo; a identidade vem do JWT)
//   200 { ok: true } · 401 sem/!JWT · 500 interno
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.47.0';
import { corsHeaders, json } from '../_shared/cors.ts';

// Buckets com pasta por usuário ({uid}/...). O list é paginado — remove em
// lotes até a pasta esvaziar.
const BUCKETS = ['profire', 'audios-mentor'];
const LOTE = 100;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  try {
    const supabaseUrl     = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceRoleKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
      console.error('Config ausente: SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY');
      return json({ error: 'erro_interno' }, 500);
    }

    // ── Auth do usuário (JWT encaminhado pelo functions.invoke) ────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'nao_autorizado' }, 401);

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) return json({ error: 'sessao_invalida' }, 401);

    const supabaseService = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // ── 1. Storage primeiro ────────────────────────────────────────────────
    // Se falhasse DEPOIS do deleteUser, os arquivos ficariam órfãos para
    // sempre (sem dono para listar). Falha aqui aborta com 500 e o usuário
    // tenta de novo — nada foi perdido.
    for (const bucket of BUCKETS) {
      while (true) {
        const { data: arquivos, error } = await supabaseService.storage
          .from(bucket)
          .list(user.id, { limit: LOTE });
        if (error) {
          console.error(`delete-account: list ${bucket}/${user.id} falhou:`, error.message);
          return json({ error: 'erro_interno' }, 500);
        }
        if (!arquivos || arquivos.length === 0) break;
        const caminhos = arquivos.map((a) => `${user.id}/${a.name}`);
        const { error: erroRemove } = await supabaseService.storage
          .from(bucket)
          .remove(caminhos);
        if (erroRemove) {
          console.error(`delete-account: remove em ${bucket} falhou:`, erroRemove.message);
          return json({ error: 'erro_interno' }, 500);
        }
        if (arquivos.length < LOTE) break;
      }
    }

    // ── 2. Pendências por e-mail (sem FK — o cascade não alcança) ──────────
    const email = (user.email ?? '').trim().toLowerCase();
    if (email) {
      await supabaseService.from('pending_entitlements').delete().eq('email', email);
    }

    // ── 3. auth.users → cascade nas tabelas ────────────────────────────────
    const { error: erroDelete } = await supabaseService.auth.admin.deleteUser(user.id);
    if (erroDelete) {
      console.error('delete-account: deleteUser falhou:', erroDelete.message);
      return json({ error: 'erro_interno' }, 500);
    }

    return json({ ok: true }, 200);
  } catch (e) {
    console.error('delete-account erro interno:', (e as Error).message);
    return json({ error: 'erro_interno' }, 500);
  }
});
