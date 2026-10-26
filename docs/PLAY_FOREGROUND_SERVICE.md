# Google Play — Declaração de serviço em primeiro plano (Relaxa e Durma)

Conteúdo pronto para colar em **Play Console → Monitorar e melhorar →
Conteúdo do app → Permissões de serviço em primeiro plano**.

O app (targetSdk 36) declara **um único tipo**: `mediaPlayback`. No manifest
final do build `1.0.0+5` estão só `FOREGROUND_SERVICE` +
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` e o serviço do `flutter_foreground_task`,
que é iniciado apenas pelo Relaxa e Durma (`lib/core/audio.dart`, chamado por
`lib/telas/dormir.dart`).

---

## Situação em 25/10/2026: vídeo provisório no ar

**Feito**
- A página https://www.thekairo.app/suporte está no ar nos 4 idiomas, com o
  vídeo na âncora `#video` (repo `lp-kairo`).
- Um vídeo **provisório** está publicado em
  `lp-kairo/public/videos/kairo-demo.mp4` (commits `62f5da9` e `955a183` da
  lp-kairo). É um passeio de 1:32 pelo app em inglês, no tema escuro e com
  a conta "Alexandra": Início, Modo Silêncio, Relaxa e Durma (som Jungle, só
  com o app aberto), Mentor, Dôjo, Jardim e Biblioteca.
- A gravação original (HEVC, 1080×2400) está em
  `~/Downloads/kairo-demo-original-hevc.mp4`. O site usa uma cópia em
  H.264, porque o Chrome não decodifica HEVC. A cópia tem 720×1536, sem a
  faixa preta do topo da gravação, e o player usa exatamente essa
  proporção. O comando de conversão está no README da lp-kairo.
- Os textos da declaração estão prontos (abaixo), mas **não foram enviados**.

**Falta, nesta ordem**
1. **Gravar o complemento** (~30–40 s; roteiro em "Gravação do complemento",
   abaixo). É o trecho que a declaração exige: o vídeo atual não mostra a
   notificação nem o som com a tela bloqueada.
2. **Montar o vídeo final.** O complemento entra no lugar do trecho do
   Jungle (≈0:11–0:23 do original, do toque em Relax & Sleep até a volta ao
   Início). As duas partes levam o mesmo corte e a mesma codificação, e o
   arquivo mantém o nome `kairo-demo.mp4`.
3. **Reescrever o texto da seção do vídeo** nos 4 idiomas
   (`suporte.video.body` e `suporte.video.capitulos` em
   `lp-kairo/src/messages/*.json`). Hoje ele descreve o roteiro final
   (Chuva, notificação, tela bloqueada), não o vídeo no ar. Os capítulos
   devem seguir a ordem real do vídeo final, com o mesmo número de itens nos
   4 idiomas.
4. **Poster** (opcional): `lp-kairo/public/videos/kairo-demo.jpg`, em
   720×1536. Sem ele, a página mostra o primeiro quadro do vídeo (o Início).
5. **Publicar:** `npm run build` na lp-kairo, conferir a página no
   navegador, commit e push na `main` (a Vercel publica em ~1 min).
6. **Enviar a declaração** no Play Console com os textos e o link abaixo,
   depois de passar pelo checklist do fim.
7. Na mesma visita ao Play Console, em **Segurança dos dados**, trocar a URL
   de exclusão de conta para https://www.thekairo.app/suporte#excluir-conta.

Os passos 2 a 5 são técnicos: com o arquivo em `~/Downloads`, peça ao Claude
Code para "montar o vídeo final do /suporte" seguindo este documento.

> O nome "Alexandra" aparece no vídeo público. Confirme que a pessoa titular
> da conta autoriza o uso do nome.

---

## Tipo e caso de uso

- **Tipo de serviço:** Reprodução de mídia (`mediaPlayback`)
- **Caso de uso (lista):** Media playback / Reprodução de mídia — áudio que
  continua tocando em segundo plano.

## Descrição da funcionalidade (456 caracteres)

> Relax & Sleep (“Relaxa e Durma” in Portuguese) plays a calming sound the user picks — rain, wind, jungle, bamboo or a tone frequency — for a duration they choose (30 min, 1 h, 2 h or all night) to help them fall asleep. Playback starts only when the user taps a sound and a duration. The mediaPlayback service keeps the audio playing with the screen off or the app in the background, with an ongoing notification, until the timer ends or the user taps End.

## Impacto se a tarefa for adiada pelo sistema (204 caracteres)

> The sound the user just picked would not start, or would start late, while they are lying down to sleep. They tap a sound expecting to hear it right away, so a delayed start makes the feature look broken.

## Impacto se a tarefa for interrompida pelo sistema (250 caracteres)

> The audio would stop as soon as the screen turns off or the app goes to the background — exactly when the user is falling asleep. That defeats the purpose of the feature: they would have to keep the screen on all night or get up to restart the sound.

## Link do vídeo

> https://www.thekairo.app/suporte#video

Se o formulário recusar uma página e pedir o arquivo de vídeo:
`https://www.thekairo.app/videos/kairo-demo.mp4`.

---

## Gravação do complemento (Android, vertical, ~30–40 s)

O caso de uso Media playback exige que o vídeo mostre **o usuário iniciando a
reprodução** — som tocando sozinho ao abrir o app não conta — e o som
seguindo fora do app. O passeio pelo app já está gravado; falta só este
trecho.

**Antes de gravar:**
- Use o mesmo aparelho e a mesma conta da gravação anterior, com o app em
  **inglês** e no tema escuro, para o corte ficar contínuo. O recorte da
  faixa preta foi medido para a tela de 1080×2400 desse aparelho.
- Conceda a permissão de notificação ao app. Sem ela, a notificação do
  serviço não aparece na barra.
- Limpe as notificações de outros apps.
- Gravador de tela do Android com **áudio do dispositivo** (não o
  microfone), volume de mídia alto e, se houver, "mostrar toques".

**Gravação:**
1. No **Home** do Kairo, toque em **Relax & Sleep** (se aparecer o tutorial,
   **Got it**) → **Rain** → **30 minutes**. O som começa: deixe ~5 s na tela
   do som.
2. Botão Home do Android → puxe a barra de notificações e mostre
   **"Relax & Sleep — Playing for your sleep."**
3. Bloqueie a tela pelo botão liga/desliga e espere ~10 s com o som audível.
   Se der, acenda a tela de bloqueio sem desbloquear, para a notificação
   aparecer ali também.
4. Desbloqueie, toque na notificação → o app volta à tela do som → **End**.
   O som para; puxe a barra para mostrar que a notificação sumiu.

Salve o arquivo em `~/Downloads` (por exemplo, `kairo-demo-fgs.mp4`) e siga
para o passo 2 de "Falta".

## Checklist antes de enviar

- [ ] O vídeo abre em `https://www.thekairo.app/suporte#video` numa aba anônima.
- [ ] O vídeo mostra o toque que inicia o som e o áudio seguindo com a tela
      bloqueada.
- [ ] Os capítulos da página descrevem o vídeo final, nos 4 idiomas.
- [ ] O AAB enviado continua só com `mediaPlayback`: conferir
      `build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml`
      depois de mexer em plugins.
