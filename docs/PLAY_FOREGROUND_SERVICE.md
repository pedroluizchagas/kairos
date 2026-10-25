# Google Play — Declaração de serviço em primeiro plano (Relaxa e Durma)

Conteúdo pronto para colar em **Play Console → Monitorar e melhorar →
Conteúdo do app → Permissões de serviço em primeiro plano**.

O app (targetSdk 36) declara **um único tipo**: `mediaPlayback`. No manifest
final do build `1.0.0+5` estão só `FOREGROUND_SERVICE` +
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` e o serviço do `flutter_foreground_task`,
que é iniciado apenas pelo Relaxa e Durma (`lib/core/audio.dart`, chamado por
`lib/telas/dormir.dart`).

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

> https://thekairo.app/suporte#video

Se o formulário recusar uma página e pedir o arquivo de vídeo:
`https://thekairo.app/videos/kairo-demo.mp4`.

---

## Roteiro do vídeo (60–90 s, Android, vertical)

O caso de uso Media playback exige que o vídeo mostre **o usuário iniciando a
reprodução** — som tocando sozinho ao abrir o app não conta. A lista de
capítulos da página `/suporte` descreve exatamente este roteiro.

**Antes de gravar:**
- Use uma conta que passe do paywall, como `revisao.play@thekairo.app`
  (cortesia até 04/10/2027).
- Conceda a permissão de notificação ao entrar no app. Sem ela, a notificação
  do serviço não aparece na barra.
- Limpe as notificações de outros apps.
- Gravador de tela do Android com **áudio do dispositivo** e, se houver,
  "mostrar toques".

**Gravação:**
1. **Início** → passeio rápido por Mentor, Dôjo, Jardim e Biblioteca → volta ao
   Início (até ~15 s).
2. Toque em **Relaxa e Durma** (na 1ª vez, **Entendi** no tutorial) → **Chuva**
   → **30 minutos**. O som começa: deixe ~5 s na tela "Chuva / Bom sono."
3. Botão Home do Android → puxe a barra de notificações e mostre
   **"Relaxa e Durma — Tocando para o seu sono."**
4. Bloqueie a tela pelo botão liga/desliga e espere ~10 s com o som audível.
5. Desbloqueie, toque na notificação → o app volta à tela do som → **Encerrar**.
   O som para; puxe a barra para mostrar que a notificação sumiu.

**Publicação:** salvar como `lp-kairo/public/videos/kairo-demo.mp4` (poster
opcional `kairo-demo.jpg`) e fazer o deploy da landing. A página detecta o
arquivo no build.

## Checklist antes de enviar

- [ ] O vídeo abre em `https://thekairo.app/suporte#video` numa aba anônima.
- [ ] O vídeo mostra o toque que inicia o som e o áudio seguindo com a tela
      bloqueada.
- [ ] O AAB enviado continua só com `mediaPlayback`: conferir
      `build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml`
      depois de mexer em plugins.
