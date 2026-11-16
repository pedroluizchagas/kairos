# App Store — informações para a App Review

Textos prontos para colar no App Store Connect. Atualizado em 2026-11-16, em
resposta à rejeição de 15/07/2026 (submission `6db4c889`, build 29734408):
2.1(a) idioma, 2.1 conta demo com assinatura expirada, 2.1(b) IAPs não
submetidos.

---

## Conta demo (App Review Information → Sign-In Information)

- **E-mail:** `revisao.apple@thekairo.app`
- **Senha:** fica fora do repo, em `~/kairo-revisao-apple.txt` (máquina do
  Pedro, permissão 600). Guarde também no gerenciador de senhas.
- Criada em 2026-11-16 pela Admin API, com e-mail já confirmado. User id
  `974d35b7-05f4-41fd-96e7-be7142d427f5`.
- Assinatura **expirada de propósito** (`apple` / `expired` /
  `app.kairo.premium.monthly`), sem cortesia. A Apple pediu "a demo account
  with an expired subscription to review the entire purchase flow".

> ⚠️ Não use esta conta para testar compras. Uma compra sandbox deixa a conta
> ativa, e aí o revisor não vê mais o paywall. Teste compras com outra conta.

### Voltar a conta para "expirada" antes de cada nova submissão

Se um revisor comprou na revisão anterior, a conta fica ativa. No SQL Editor
do Supabase:

```sql
select public.aplicar_estado_assinatura(
  (select id from auth.users where email = 'revisao.apple@thekairo.app'),
  'apple', 'expired', 'app.kairo.premium.monthly',
  now() - interval '1 day', false, 'demo-expired-review');
```

Se a assinatura sandbox ainda estiver renovando, o `apple-webhook` pode
reativar a conta na renovação seguinte. Rode o SQL perto do envio e confira:

```sql
select s.status, s.current_period_end
from public.subscriptions s
join auth.users u on u.id = s.user_id
where u.email = 'revisao.apple@thekairo.app';
```

---

## Notes (App Review Information → Notes)

Só faz sentido depois que o build novo estiver na versão e as duas
assinaturas estiverem marcadas para envio (o texto afirma as duas coisas).

```text
Kairo is a personal-development app built around an AI Mentor (powered by Anthropic's Claude). It is a subscription app with no permanent free tier: after sign-in, an account without an active subscription sees the subscription screen (paywall) before entering the app.

DEMO ACCOUNT - EXPIRED SUBSCRIPTION
The account in Sign-In Information has an expired subscription, as requested in the previous review. To review the full purchase flow:
1. On first launch, select English on the language screen and tap the arrow button. After the short intro, swipe to continue.
2. Tap "I already have an account" and sign in with the demo account.
3. The paywall appears right after sign-in, with the Monthly and Annual auto-renewable subscriptions and their App Store prices. "Restore purchases" and "Sign out" are always available on this screen.
4. Choose a plan and complete the purchase with your Sandbox Apple ID while signed in to the demo account. The app unlocks as soon as the purchase is confirmed.

LANGUAGE - GUIDELINE 2.1(a)
The app is localized in English, Portuguese, Spanish and German. On first launch, the language screen comes pre-selected with the device language. After you select English, the app stays in English, including after sign-in and on the paywall. This build fixes the issue from the previous review, where the app switched back to Portuguese after sign-in. To change the language later, tap the avatar at the top of the Home screen to open Profile, then use Language.

IN-APP PURCHASES - GUIDELINE 2.1(b)
Both auto-renewable subscriptions (monthly and annual) are submitted for review together with this build.

OTHER INFORMATION
- Before any data is sent to an AI provider, the app asks for consent and names the providers: Anthropic (Claude) for the Mentor and Groq for voice transcription.
- Account deletion: Profile > Delete account.
- The app requires an internet connection.
```

---

## Resposta à Apple (App Review → mensagem da rejeição)

```text
Hello,

Thank you for your review. We have addressed the three issues:

1. Guideline 2.1(a) - Localization: after sign-in, the app was switching back to Portuguese even when English had been selected on launch. The new build fixes this: the language selected on launch is kept after sign-in and throughout the app.

2. Guideline 2.1 - Demo account: the App Review Information now has a demo account with an expired subscription. The paywall appears after sign-in, so the full purchase flow can be completed with a Sandbox Apple ID.

3. Guideline 2.1(b) - In-App Purchases: both auto-renewable subscriptions (monthly and annual) are now submitted for review together with the new build.

Step-by-step instructions are in the App Review notes.

Best regards,
The Kairo team
```

---

## Review Notes de cada assinatura (Subscriptions → assinatura → Review Information)

O mesmo texto serve para a mensal e a anual.

```text
This subscription is offered on the paywall that appears right after sign-in; Kairo has no free tier, so the subscription unlocks the whole app. To reach it, use the demo account in the app's App Review Information: its subscription is expired, so the paywall appears and the purchase can be completed with a Sandbox Apple ID. The monthly and annual plans are shown on the same screen, with "Restore purchases" and "Sign out" always available.
```

---

## Screenshot de revisão de cada assinatura (campo "Screenshot")

A Apple exige um print mostrando **onde a assinatura aparece dentro do app**,
ou seja, a tela do paywall. A Apple não deixa enviar a assinatura sem ele.

**Como capturar:**
1. O workflow `ios-screenshots` do Codemagic gera esse print no Simulador
   (`build/screenshots/*-paywall-premium.png`).
2. Ou rode o app com o ambiente **StoreKit / Sandbox** configurado, para os
   produtos carregarem com preço, e entre com uma conta **sem assinatura
   ativa**: o paywall aparece logo após o login.
3. O print deve mostrar os planos mensal/anual e o botão "Restaurar compras".

> Dica: se os produtos ainda não aparecem (status "Prepare for Submission"),
> use um **StoreKit Configuration File** no Xcode para renderizar o paywall
> com preços de teste só para o screenshot. O mesmo print serve para as duas
> assinaturas.

---

## Checklist antes de reenviar

- [x] Conta demo criada, confirmada e com assinatura expirada (16/11).
- [ ] Build novo gerado no Codemagic (`ios-testflight`) e selecionado na
      versão 1.0. A Apple ainda está com o build 29734408, de julho, que não
      tem a correção de idioma.
- [ ] Teste no TestFlight, do zero: escolher English, entrar com a conta demo,
      ver o paywall em inglês. Testar a compra sandbox com **outra** conta.
- [ ] Cada assinatura com preço, localização (nome e descrição) e screenshot
      de revisão. O grupo de assinaturas também precisa de localização.
- [ ] Oferta introdutória de 7 dias grátis nas duas assinaturas. O app promete
      o teste a contas que nunca assinaram; sem a oferta, o StoreKit cobra na
      hora (risco de rejeição 3.1.2).
- [ ] Product ID do anual conferido no ASC. O código consulta
      `app.kairo.premium.anual` e `app.kairo.premium.yearly`; só o que existir
      na loja aparece no paywall.
- [ ] Paid Apps Agreement ativo (Business). Sem ele, os produtos nem carregam.
- [ ] As duas assinaturas marcadas na seção "In-App Purchases and
      Subscriptions" da página da versão 1.0.
- [ ] Sign-In Information com a conta demo e Notes colados (textos acima).
- [ ] Resposta enviada na mensagem da rejeição e versão reenviada.
