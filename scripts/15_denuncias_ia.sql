-- ============================================================================
-- Kairo · 15_denuncias_ia.sql
-- Denúncia de conteúdo gerado por IA (resposta do Mentor / carta semanal).
--
-- Motivação (go-live Android, 10/2026): a política de Conteúdo Gerado por IA
-- do Google Play exige que apps cujo recurso central é um chatbot de IA
-- permitam ao usuário denunciar conteúdo ofensivo SEM sair do app. No app:
-- segurar uma resposta do Mentor, ou "Denunciar esta carta" no fim da carta,
-- abre o sheet de motivos; a escolha grava uma linha aqui.
--
-- Desenho:
--   • Guarda uma CÓPIA do texto denunciado — as mensagens não têm id no
--     client e o usuário pode limpar o histórico depois.
--   • RLS: só INSERT da própria linha. Sem SELECT/UPDATE/DELETE — a
--     moderação lê pelo SQL Editor / service role.
--   • on delete cascade: excluir a conta apaga as denúncias junto (o texto
--     pode ecoar dados pessoais da conversa).
--
-- ADITIVO e idempotente. Revisar as denúncias (SQL Editor):
--   select created_at, origem, motivo, left(conteudo, 200) as trecho
--     from public.denuncias_ia
--    order by created_at desc;
-- ============================================================================

create table if not exists public.denuncias_ia (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  origem      text        not null check (origem in ('mentor', 'carta')),
  motivo      text        not null check (motivo in ('ofensivo', 'perigoso', 'outro')),
  conteudo    text        not null check (length(conteudo) between 1 and 20000),
  created_at  timestamptz not null default now()
);

create index if not exists denuncias_ia_created_idx
  on public.denuncias_ia (created_at desc);

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.denuncias_ia enable row level security;

drop policy if exists "denuncias_ia_insert_own" on public.denuncias_ia;
create policy "denuncias_ia_insert_own"
  on public.denuncias_ia for insert
  with check (auth.uid() = user_id);

-- Explícito: o client só precisa inserir (o insert não pede a linha de volta).
grant insert on table public.denuncias_ia to authenticated;
