# App Store Review Information — Kairo Pro Monthly

Conteúdo pronto para colar nos campos **Review Information** da assinatura
(`app.kairo.premium.monthly`) no App Store Connect.

---

## Review Notes (campo "Review Notes")

> **How to reach the subscription paywall**
>
> 1. On first launch, choose your language and sign in with the demo
>    account below (or tap "Create account" to register a new one).
> 2. The paywall appears **immediately after sign-in** (the app uses a
>    subscription gate: content is unlocked only with an active
>    subscription). It lists the auto-renewable subscriptions
>    (**Kairo Pro Monthly** and **Kairo Pro Yearly**), with prices coming
>    from the App Store. **"Restore Purchases"** and **"Sign out"** are
>    always visible on this screen.
> 3. The demo account below has an **expired subscription**, so you can
>    review the full purchase flow: the paywall shows up on sign-in and a
>    new purchase can be completed with a Sandbox Apple ID. Please make
>    the purchase while signed in to the demo account.
>
> **Demo account**
> Email: review@kairo.app
> Password: Review1234
>
> **Subscription details**
> - Product: Kairo Pro Monthly (auto-renewable, 1 month).
> - Unlocks: Mentor with the advanced model (Claude Sonnet), the weekly
>   Mentor letter, and higher daily usage limits.
> - Purchase is made exclusively through Apple In-App Purchase (StoreKit).
>   There are no external payment links or steering inside the app.
> - The app requires an internet connection (backend on Supabase).
>
> Thank you for reviewing Kairo.

---

## Screenshot (campo "Screenshot")

A Apple exige um print mostrando **onde a assinatura aparece dentro do app** —
ou seja, a tela da paywall (`TelaPremium`).

**Como capturar:**
1. Rode o app no simulador/dispositivo com o ambiente **StoreKit / Sandbox**
   configurado, para os produtos carregarem com preço.
2. Faça login com uma conta **sem assinatura ativa** — o portão (paywall)
   aparece imediatamente após o login.
3. Tire o screenshot da paywall mostrando os planos **Monthly/Yearly** e o
   botão **Restore Purchases**.

> Dica: se os produtos ainda não aparecem (status "Prepare for Submission"),
> use um **StoreKit Configuration File** no Xcode para renderizar a paywall
> com preços de teste só para o screenshot.

---

## Conta demo com assinatura EXPIRADA (exigência da Apple — rejeição 2.1)

A Apple pediu explicitamente ("we need access to a demo account with an
expired subscription to review the entire purchase flow"). Passos:

1. Crie a conta no próprio app (signup + confirmar e-mail).
2. Pegue o UUID do usuário: **Dashboard → Authentication → Users**.
3. No **SQL Editor** do dashboard (role postgres, bypassa RLS), rode:

```sql
insert into public.subscriptions
  (user_id, provider, status, product_id, current_period_end,
   cancel_at_period_end, provider_sub_id)
values
  ('<UUID-DA-CONTA-DEMO>', 'apple', 'expired', 'app.kairo.premium.monthly',
   now() - interval '1 day', false, 'demo-expired-tx')
on conflict (user_id) do update set
  provider = 'apple',
  status = 'expired',
  product_id = 'app.kairo.premium.monthly',
  current_period_end = now() - interval '1 day',
  updated_at = now();
```

4. Confira no app: logar com essa conta deve cair direto no portão
   (paywall), com o Perfil mostrando "Gratuito", e a compra sandbox deve
   completar e liberar a Home.
5. Coloque e-mail + senha dessa conta no campo **App Review Information →
   Sign-In Information** do App Store Connect e mencione nas Review Notes
   que a conta está com assinatura expirada.

---

## Checklist antes de submeter

- [ ] Conta de teste **criada, com e-mail confirmado** e com a linha
      `subscriptions` em estado `expired` (SQL acima).
- [ ] Screenshot da paywall anexado **em cada um dos dois IAPs** (a Apple
      não deixa submeter IAP sem o screenshot de review).
- [ ] As duas assinaturas **anexadas à versão** do app em review e em
      estado "Ready to Submit" (rejeição 2.1b: IAP não submetido).
- [ ] Product ID do anual conferido no ASC — o código consulta
      `app.kairo.premium.anual` E `app.kairo.premium.yearly`; só o que
      existir na loja aparece no paywall.
- [ ] Review Notes colado (com credenciais reais da conta de teste).
- [ ] Preço e disponibilidade da assinatura configurados.
- [ ] (Opcional) Imagem 1024×1024 da assinatura.

> ⚠️ Os valores `review@kairo.app` / `Review1234` são placeholders. Substitua
> pelas credenciais de uma conta de teste **real e já confirmada**. A senha
> precisa ter mín. 8 caracteres com letra e número (regra do app).

---

# Kairo Pro Yearly

Conteúdo para a assinatura **anual** (`app.kairo.premium.yearly`). O fluxo de
acesso é o mesmo do mensal — ambos os produtos aparecem na mesma paywall.

## Review Notes (campo "Review Notes")

> **How to reach the subscription paywall**
>
> 1. On first launch, choose your language and sign in with the demo
>    account below (or tap "Create account" to register a new one).
> 2. The paywall appears **immediately after sign-in** (the app uses a
>    subscription gate: content is unlocked only with an active
>    subscription). It lists the auto-renewable subscriptions
>    (**Kairo Pro Monthly** and **Kairo Pro Yearly**), with prices coming
>    from the App Store. **"Restore Purchases"** and **"Sign out"** are
>    always visible on this screen.
> 3. The demo account below has an **expired subscription**, so you can
>    review the full purchase flow: the paywall shows up on sign-in and a
>    new purchase can be completed with a Sandbox Apple ID. Please make
>    the purchase while signed in to the demo account.
>
> **Demo account**
> Email: review@kairo.app
> Password: Review1234
>
> **Subscription details**
> - Product: Kairo Pro Yearly (auto-renewable, 1 year).
> - Unlocks: Mentor with the advanced model (Claude Sonnet), the weekly
>   Mentor letter, and higher daily usage limits.
> - Purchase is made exclusively through Apple In-App Purchase (StoreKit).
>   There are no external payment links or steering inside the app.
> - The app requires an internet connection (backend on Supabase).
>
> Thank you for reviewing Kairo.

## Screenshot (campo "Screenshot")

Use a **mesma tela da paywall** (`TelaPremium`) que mostra os planos
Monthly/Yearly e o botão Restore Purchases. O mesmo screenshot do plano mensal
serve para o anual — ambos os produtos estão visíveis na imagem.
