-- ============================================================================
-- Kairo · 14_cortesias.sql
-- Acesso cortesia por E-MAIL (testadores do closed testing / TestFlight,
-- parceiros, suporte): concede o entitlement Premium SEM cobrança, pelo MESMO
-- caminho canônico das compras reais (aplicar_estado_assinatura).
--
-- Motivação (fase de teste, 08/2026): cadastrar o testador no Play Console
-- (lista do track fechado / License testing) ou no TestFlight NÃO cria
-- entitlement no Supabase — o hard paywall (TelaPortao) lê public.subscriptions,
-- que só os webhooks escrevem, e segue exigindo assinatura do testador. Com a
-- allowlist abaixo, quem está nela entra direto e NUNCA vê o paywall (nem o
-- fluxo de pagamento das lojas).
--
-- Desenho (mesmos princípios do 08/12/13):
--   • public.cortesias — allowlist por e-mail (lowercase), com validade e
--     motivo. Escrita só por service role / SQL Editor (RLS on, sem policy).
--   • adicionar_cortesia(email, dias, motivo) — upsert na lista + concessão
--     imediata se a conta já existe ('concedido'); senão 'aguardando_signup'
--     e o trigger cobre quando a conta for criada.
--   • Trigger on_auth_user_created_cortesia — concede no signup. Nunca
--     bloqueia a criação da conta (erro vira warning, como no 13).
--   • remover_cortesia(email) — tira da lista e expira o entitlement SE (e
--     somente se) ele foi concedido por cortesia; assinatura real fica intacta.
--   • provider 'cortesia' em subscriptions: a convergência do 12 já protege —
--     um webhook Apple/Google não rebaixa uma cortesia vigente (provider
--     diferente), e uma compra REAL (active) sempre sobrescreve a cortesia.
--
-- O CLIENT não muda: TelaPortao/perfil leem status+current_period_end, e uma
-- cortesia é status 'active' com fim = expira_em ("Premium ativo até …").
-- is_premium() também passa sem alteração — os gates server-side (mentor-chat,
-- transcrever-audio) liberam junto. Nada disso exige novo build/review.
--
-- ADITIVO e idempotente. Depende do 12_billing_multiplataforma.sql (RPC de 7
-- parâmetros + vocabulário de status). Verificação rápida no banco:
--   select proname, pronargs from pg_proc where proname='aplicar_estado_assinatura';
--   -- precisa existir a versão com pronargs = 7
--
-- USO (SQL Editor, como service role):
--   -- 1 testador, 90 dias (default):
--   select public.adicionar_cortesia('fulano@gmail.com');
--   -- vários de uma vez:
--   select t.email, public.adicionar_cortesia(t.email)
--     from unnest(array['a@x.com','b@y.com','c@z.com']) as t(email);
--   -- reprocessar a lista inteira sem mexer na validade (ex.: conta criada
--   -- antes deste script existir):
--   select c.email, public.conceder_cortesia(u.id, c.email)
--     from public.cortesias c
--     join auth.users u on lower(u.email) = c.email;
--   -- encerrar a fase de teste (revoga um a um):
--   select c.email, public.remover_cortesia(c.email) from public.cortesias c;
--
-- IMPORTANTE: o e-mail é o de LOGIN NO APP (Supabase Auth) — não a conta
-- Google/Apple do aparelho, nem o e-mail cadastrado nos consoles das lojas.
-- ============================================================================

-- ── 1. Vocabulário: provider 'cortesia' em subscriptions ─────────────────────
-- O 12 restringiu provider a none|stripe|apple|google; acrescentamos cortesia.
alter table public.subscriptions
  drop constraint if exists subscriptions_provider_check;
alter table public.subscriptions
  add constraint subscriptions_provider_check
  check (provider in ('none','stripe','apple','google','cortesia'));

-- ── 2. Tabela cortesias (allowlist por e-mail) ───────────────────────────────
create table if not exists public.cortesias (
  email      text        primary key,
  motivo     text        not null default 'testador',
  expira_em  timestamptz not null,
  criado_em  timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Toda escrita deve vir normalizada (adicionar_cortesia cuida disso); o
  -- CHECK barra um INSERT manual fora do padrão, que nunca casaria no lookup.
  constraint cortesias_email_minusculo check (email = lower(trim(email)))
);

alter table public.cortesias enable row level security;
-- Intencionalmente SEM policy: RLS on sem policy = invisível a anon/auth.
-- Só service role (bypassa RLS) e funções SECURITY DEFINER (owner) acessam.

-- ── 3. conceder_cortesia(): aplica o entitlement de um e-mail da lista ───────
-- Núcleo reusado pelo adicionar_cortesia e pelo trigger de signup. Devolve um
-- diagnóstico legível p/ rodar em lote no SQL Editor:
--   'concedido' | 'sem_cortesia' | 'cortesia_expirada' | 'ja_premium'
create or replace function public.conceder_cortesia(p_user_id uuid, p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_c     public.cortesias;
  v_s     public.subscriptions;
begin
  if p_user_id is null or v_email is null or v_email = '' then
    raise exception 'conceder_cortesia: user_id e e-mail obrigatórios';
  end if;

  select * into v_c from public.cortesias where email = v_email;
  if v_c.email is null then
    return 'sem_cortesia';
  end if;
  if v_c.expira_em <= now() then
    return 'cortesia_expirada';
  end if;

  -- Assinatura REAL vigente nunca é sobrescrita por cortesia: preservamos o
  -- provider_sub_id/ciclo de quem já paga (a cortesia só cobre quem não paga).
  select * into v_s from public.subscriptions where user_id = p_user_id;
  if v_s.user_id is not null
     and v_s.provider not in ('none','cortesia')
     and v_s.status in ('active','trialing','grace')
     and v_s.current_period_end > now()
  then
    return 'ja_premium';
  end if;

  perform public.aplicar_estado_assinatura(
    p_user_id, 'cortesia', 'active', 'cortesia:' || v_c.motivo,
    v_c.expira_em, false, null
  );
  return 'concedido';
end;
$$;

revoke all on function public.conceder_cortesia(uuid, text) from public;
grant execute on function public.conceder_cortesia(uuid, text) to service_role;

-- ── 4. adicionar_cortesia(): upsert na lista + concessão imediata ────────────
-- Re-adicionar um e-mail renova a validade (now() + p_dias) — é o jeito de
-- estender o acesso de um testador.
create or replace function public.adicionar_cortesia(
  p_email  text,
  p_dias   integer default 90,
  p_motivo text default 'testador'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email   text := lower(trim(p_email));
  v_user_id uuid;
begin
  if v_email is null or v_email = '' then
    raise exception 'adicionar_cortesia: e-mail obrigatório';
  end if;

  insert into public.cortesias as c (email, motivo, expira_em, updated_at)
  values (v_email, p_motivo, now() + make_interval(days => p_dias), now())
  on conflict (email) do update set
    motivo     = excluded.motivo,
    expira_em  = excluded.expira_em,
    updated_at = now();

  -- auth.users é a fonte de identidade; conta mais antiga vence — mesmo
  -- critério determinístico do aplicar_estado_por_email (13).
  select id into v_user_id
  from auth.users
  where lower(email) = v_email
  order by created_at asc
  limit 1;

  if v_user_id is null then
    return 'aguardando_signup';
  end if;
  return public.conceder_cortesia(v_user_id, v_email);
end;
$$;

revoke all on function public.adicionar_cortesia(text, integer, text) from public;
grant execute on function public.adicionar_cortesia(text, integer, text) to service_role;

-- ── 5. remover_cortesia(): revoga a cortesia sem tocar assinatura real ───────
-- Expira o entitlement apenas quando o provider vigente é 'cortesia' — mesmo
-- provider, então a convergência do 12 permite o rebaixamento. Uma assinatura
-- Stripe/Apple/Google (vigente ou não) nunca é alterada por aqui.
create or replace function public.remover_cortesia(p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email   text := lower(trim(p_email));
  v_user_id uuid;
begin
  if v_email is null or v_email = '' then
    raise exception 'remover_cortesia: e-mail obrigatório';
  end if;

  delete from public.cortesias where email = v_email;

  select id into v_user_id
  from auth.users
  where lower(email) = v_email
  order by created_at asc
  limit 1;

  if v_user_id is not null and exists (
    select 1 from public.subscriptions s
    where s.user_id = v_user_id and s.provider = 'cortesia'
  ) then
    perform public.aplicar_estado_assinatura(
      v_user_id, 'cortesia', 'expired', 'cortesia', now(), false, null
    );
  end if;
  return 'removido';
end;
$$;

revoke all on function public.remover_cortesia(text) from public;
grant execute on function public.remover_cortesia(text) to service_role;

-- ── 6. Trigger: concede no signup ────────────────────────────────────────────
-- Ordem de disparo em auth.users (alfabética, mesmo evento):
--   on_auth_user_created (perfil) → on_auth_user_created_cortesia (aqui) →
--   on_auth_user_created_reconcile (13). Se o e-mail tiver TAMBÉM um
--   pending_entitlement pago (web), o reconcile roda DEPOIS e o entitlement
--   real prevalece sobre a cortesia — exatamente o desejado.
create or replace function public.conceder_cortesia_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.email is null or NEW.email = '' then
    return NEW;
  end if;
  begin
    perform public.conceder_cortesia(NEW.id, NEW.email);
  exception when others then
    -- Nunca bloqueia o signup; remédio manual: re-rodar adicionar_cortesia.
    raise warning 'conceder_cortesia_signup falhou p/ %: %', NEW.email, sqlerrm;
  end;
  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created_cortesia on auth.users;
create trigger on_auth_user_created_cortesia
  after insert on auth.users
  for each row execute function public.conceder_cortesia_signup();
