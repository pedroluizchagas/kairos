# Prompt — alinhamento legal do site thekairo.app (pós-rejeição Apple)

> Copiar tudo abaixo da linha e colar no agente do projeto do site (lp-kairo).

---

Você vai atualizar as páginas legais do site do Kairo (thekairo.app). O app iOS foi rejeitado pela Apple em 09/07/2026 e as correções de código já foram feitas no app; agora o site — que hospeda a Política de Privacidade (`/privacidade`) e os Termos de Uso (`/termos`) linkados de dentro do app — precisa refletir exatamente a mesma realidade. O reviewer da Apple abre esses links durante o review, então o conteúdo precisa estar publicado antes do reenvio.

## O que é o Kairo (referência rápida)

App Flutter de evolução pessoal (iOS/Android), bundle `com.thekairo.app`. Funcionalidades: chat "Mentor" com IA, práticas diárias (Dôjo), reflexões guiadas (Jardim), carta semanal gerada por IA aos domingos, modo silêncio e sons para dormir. Assinatura auto-renovável (mensal/anual, 7 dias de teste grátis) via In-App Purchase (Apple/Google) e via Stripe no checkout da própria landing. Backend: Supabase (auth por e-mail/senha — sem login social —, Postgres, Storage e Edge Functions).

## Por que a Apple rejeitou (o que afeta o site)

1. **Guideline 5.1.1(i) + 5.1.2(i) — Privacidade / IA de terceiros.** O app envia dados pessoais a serviços de IA. A Apple exige que (a) o app explique o que envia, para quem, e peça permissão ANTES do envio — **já implementado no app**; e (b) que **a Política de Privacidade identifique quais dados o app coleta, como coleta, todos os usos de cada dado, e confirme que os terceiros que recebem dados oferecem proteção igual ou equivalente**. A Apple diz explicitamente que colocar isso só nos Termos de Uso NÃO é suficiente — precisa estar na Política de Privacidade.
2. **Guideline 5.1.1(v) — Exclusão de conta.** O app agora tem exclusão de conta completa dentro do app (Perfil → Excluir conta). A política precisa refletir isso.
3. Contexto: houve também rejeição por 2.3.7 (referência a preço nos metadados da loja) e 3.1.1 (IAP) — resolvidas no app/App Store Connect. Do lado do site só importa a nota sobre métricas fictícias, abaixo.

## O que o app faz hoje — fatos que a política DEVE refletir com exatidão

**Envio a provedores de IA (somente após consentimento explícito no app, registrado com timestamp no perfil do usuário):**
- **Anthropic (Claude)** — gera as respostas do chat Mentor e a carta semanal. Recebe: o texto das mensagens do chat (histórico recente), os dados de perfil do onboarding (nome, identidade que a pessoa quer construir, o que a tira do eixo, área de foco, ritmo) e — para a carta semanal — o texto integral das reflexões do Jardim da semana e estatísticas de práticas.
- **Groq (Whisper)** — transcreve as mensagens de voz do Mentor. Recebe: o arquivo de áudio da mensagem de voz.
- Ambos processam os dados nos Estados Unidos. O conteúdo não é usado para treinar os modelos (APIs comerciais com DPA). Todas as chamadas passam pelo backend (Supabase Edge Functions) — nenhuma chave de API vive no aparelho.
- O app mostra uma folha de consentimento antes do PRIMEIRO uso de qualquer recurso de IA; sem o aceite, nenhum dado sai do aparelho. Recusar não bloqueia o resto do app.

**Exclusão de conta (dentro do app):**
- Caminho: Perfil → Excluir conta → confirmação. A exclusão é imediata e permanente no servidor: perfil, mensagens do Mentor (texto e áudio), reflexões do Jardim, práticas e progresso, cartas semanais, registro de assinatura e arquivos de Storage (avatar e áudios de voz).
- A assinatura na loja (Apple/Google) NÃO é cancelada automaticamente pela exclusão — o usuário cancela nos ajustes da loja (o app avisa isso na confirmação). Assinatura feita na web (Stripe): cancelamento via contato/portal.
- Alternativa por e-mail para quem não consegue usar o app: contact@thekairo.app.

**Demais dados:**
- Conta: e-mail e senha (Supabase Auth). Foto de avatar opcional.
- Pagamentos: Apple, Google (IAP) e Stripe (web). Nunca vemos dados de cartão — só o status da assinatura.
- Gerados pelo uso: contadores de interação com IA (para limites de uso), preferências de notificação (processadas no aparelho), logs de erro/diagnóstico.

## Tarefas no site

1. **Atualizar `/privacidade`** com o texto-base completo abaixo, preenchendo:
   - Controlador: razão social da entidade + CNPJ **24.811.306/0001-96**
   - Contato/encarregado (DPO): **contact@thekairo.app**
   - Idade mínima: **18 anos** (sugerido — confirmar com o Pedro)
   - Data de última atualização: a data da publicação
2. **Revisar `/termos`** para consistência com a política: assinatura auto-renovável (mensal/anual, 7 dias de teste), cancelamento via loja (Apple/Google) ou Stripe (web), isenção sobre conteúdo gerado por IA (o Mentor é reflexivo, não é aconselhamento médico/psicológico/profissional), mesma idade mínima.
3. **Rodapé:** trocar o e-mail antigo `ola@kairoapp.com` por `contact@thekairo.app`.
4. **Métricas fictícias:** remover (ou marcar claramente como ilustrativas) as métricas placeholder da landing — "95%", "1.2M+ práticas", "48k+ cartas" — e o rating "4.9" no JSON-LD. O site é a URL de marketing/suporte cadastrada na App Store; o reviewer visita, e dados fabricados podem virar nova rejeição por metadata enganosa.
5. **Conferir** que `https://thekairo.app/#faq` funciona (é a URL de suporte cadastrada) e que `/privacidade` e `/termos` abrem bem no navegador do celular — o app abre esses links direto do paywall e da folha de consentimento.

## Checklist do conteúdo obrigatório da Política (Apple 5.1.1(i))

- [ ] Quais dados são coletados e COMO (fornecidos pelo usuário × gerados pelo uso)
- [ ] TODOS os usos de cada dado
- [ ] Tabela de terceiros/subprocessadores — Supabase, Anthropic, Groq, Apple, Google, Stripe — com finalidade e dados compartilhados de cada um
- [ ] Afirmação de que os terceiros oferecem proteção igual/equivalente (contratos de processamento de dados)
- [ ] Seção específica de IA: o que vai para Anthropic/Groq, consentimento prévio no app, não-uso para treinamento
- [ ] Transferência internacional (EUA) com salvaguardas
- [ ] Exclusão de conta pelo próprio app + alternativa por e-mail
- [ ] Direitos LGPD/GDPR e canal de contato

## Texto-base da Política de Privacidade (adaptar só a formatação ao site)

**Última atualização:** [data da publicação]

Esta Política descreve como o **Kairo** ("app", "nós") trata seus dados pessoais. Ao usar o Kairo, você concorda com as práticas aqui descritas.

**Controlador dos dados:** [razão social], CNPJ 24.811.306/0001-96, [cidade, país].
**Contato (encarregado/DPO):** contact@thekairo.app.

### 1. Dados que coletamos

Coletamos apenas o necessário para o app funcionar:

**Você fornece:**
- **Conta:** e-mail e senha (autenticação), nome e idioma de preferência.
- **Perfil:** foto de perfil (avatar), se você enviar, e as respostas do onboarding (identidade que quer construir, o que te tira do eixo, área de foco, ritmo).
- **Conteúdo que você cria:** reflexões do Jardim, registros de práticas, mensagens de texto e de voz trocadas com o Mentor e as cartas semanais geradas a partir delas.

**Gerados pelo uso:**
- **Dados de uso da IA:** registros de quantas interações com a IA você fez (para aplicar limites de uso).
- **Notificações:** preferências de lembrete (processadas no seu dispositivo).
- **Dados técnicos:** logs de erro e diagnóstico, identificadores de dispositivo necessários para entrega de notificações.

**Não coletamos** dados de cartão de crédito: pagamentos são processados pela **Apple**, **Google** ou **Stripe** (na web) — nós recebemos apenas o **status da sua assinatura**, nunca os dados do cartão.

### 2. Como usamos seus dados

- Fornecer e personalizar o app (Mentor, Dôjo, Jardim, cartas semanais);
- Processar suas mensagens com a IA para gerar respostas e reflexões;
- Gerenciar sua conta e sua assinatura (incluindo o período de teste);
- Enviar lembretes e notificações que você configurar;
- Garantir segurança, prevenir abuso e aplicar limites de uso;
- Cumprir obrigações legais.

### 3. Base legal (LGPD / GDPR)

Tratamos seus dados com base em: **execução do contrato** (prestar o serviço que você assina), **consentimento** (ex.: recursos de IA, notificações, envio de foto), **legítimo interesse** (segurança, prevenção de fraude) e **cumprimento de obrigação legal**.

### 4. Compartilhamento com terceiros (subprocessadores)

Não vendemos seus dados. Compartilhamos com prestadores estritamente necessários:

| Prestador | Finalidade | Dados |
|---|---|---|
| **Supabase** | Hospedagem, banco de dados, autenticação e armazenamento | Conta, perfil, conteúdo |
| **Anthropic (Claude)** | Processar as mensagens do Mentor e gerar as cartas | Texto das suas mensagens/reflexões e dados do seu perfil (nome, identidade, foco, ritmo) |
| **Groq (Whisper)** | Transcrever as mensagens de voz do Mentor | Áudio das mensagens de voz |
| **Apple / Google** | Distribuição do app e processamento de pagamentos | Status de compra/assinatura |
| **Stripe** | Pagamento de assinatura **na web** | Status de pagamento (cartão fica na Stripe) |

Cada prestador trata os dados sob contratos de processamento de dados (DPA) e oferece proteção equivalente à desta Política.

### 5. Inteligência Artificial

O Mentor e as cartas semanais usam modelos da **Anthropic (Claude)**: o texto das suas mensagens, as reflexões do Jardim (usadas na carta semanal) e os dados do seu perfil (nome, identidade, foco e ritmo) são processados para gerar as respostas. As mensagens de voz são transcritas por modelos da **Groq (Whisper)**: o áudio é enviado apenas para transcrição. **Não** usamos seu conteúdo pessoal para treinar modelos de terceiros.

O app **pede o seu consentimento antes do primeiro uso** desses recursos; sem o aceite, nenhum dado seu é enviado aos provedores de IA. As respostas da IA são geradas automaticamente e têm caráter reflexivo — veja a isenção nos Termos de Uso.

### 6. Transferência internacional

Alguns prestadores (Supabase, Anthropic, Groq, Apple, Google, Stripe) processam dados **fora do Brasil**, inclusive nos Estados Unidos. Ao usar o Kairo, você concorda com essa transferência, realizada com salvaguardas contratuais adequadas.

### 7. Retenção e exclusão

Mantemos seus dados enquanto sua conta existir. Você pode **excluir sua conta a qualquer momento dentro do app** (Perfil → Excluir conta) — a exclusão é imediata e permanente e remove perfil, conversas, reflexões, práticas, cartas e arquivos enviados. Também aceitamos solicitações por contact@thekairo.app. Retemos apenas o que a lei exigir. A exclusão da conta **não cancela** uma assinatura ativa na App Store/Google Play — cancele nos ajustes da loja.

### 8. Seus direitos

Conforme a LGPD (e o GDPR, se aplicável), você pode: confirmar o tratamento, acessar, corrigir, anonimizar, portar ou **excluir** seus dados, revogar consentimento e se opor a tratamentos. Para exercer, escreva para contact@thekairo.app.

### 9. Segurança

Adotamos medidas técnicas e organizacionais: criptografia em trânsito, controle de acesso por linha (RLS) no banco e segregação de credenciais. Nenhum sistema é 100% seguro, mas trabalhamos para proteger seus dados.

### 10. Crianças

O Kairo **não se destina a menores de 18 anos**. Não coletamos intencionalmente dados de menores; se identificarmos, removemos.

### 11. Alterações

Podemos atualizar esta Política. Mudanças relevantes serão comunicadas no app ou por e-mail. A data no topo indica a última revisão.

### 12. Contato

Dúvidas ou solicitações sobre privacidade: **contact@thekairo.app**.
