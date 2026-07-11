-- Consentimento de compartilhamento de dados com provedores de IA
-- (Apple App Review 5.1.1(i)/5.1.2(i): o app precisa divulgar o que envia,
-- para quem, e obter permissão ANTES do envio).
--
-- O app grava o timestamp do aceite (folha de disclosure em
-- lib/core/consentimento_ia.dart). A Edge Function relatorio-semanal recusa
-- gerar a carta sem esse aceite — importante para o caminho do cron de
-- domingo, que não passa pela UI.
--
-- Nenhuma mudança de RLS: as policies de `profiles` por dono já cobrem a
-- coluna nova (o app já faz upsert do próprio perfil).
--
-- Idempotente (add column if not exists) para reaplicação segura.

alter table public.profiles
  add column if not exists consentimento_ia_em timestamptz;

comment on column public.profiles.consentimento_ia_em is
  'Quando o usuário consentiu no envio de dados aos provedores de IA (Anthropic/Groq). Nulo = ainda não consentiu; recursos de IA não enviam nada.';
