# Google Play — Declaração de serviço em primeiro plano (Relaxa e Durma)

Conteúdo pronto para colar em **Play Console → Monitorar e melhorar →
Conteúdo do app → Permissões de serviço em primeiro plano**.

O app (targetSdk 36) declara **um único tipo**: `mediaPlayback`. No manifest
final do build `1.0.0+5` estão só `FOREGROUND_SERVICE` +
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` e o serviço do `flutter_foreground_task`,
que é iniciado apenas pelo Relaxa e Durma (`lib/core/audio.dart`, chamado por
`lib/telas/dormir.dart`).

---

## Situação em 29/10/2026: vídeo final no ar

**Feito**
- A página https://www.thekairo.app/suporte está no ar nos 4 idiomas, com o
  vídeo na âncora `#video` (repo `lp-kairo`).
- O **vídeo final** está publicado em `lp-kairo/public/videos/kairo-demo.mp4`
  (commit `12bec6d` da lp-kairo; 2:14, H.264 720×1536, 30 fps), com o poster
  `kairo-demo.jpg`. Ele junta duas gravações do mesmo aparelho, com o app em
  inglês, no tema escuro e com a conta "Alexandra":
  - o original até abrir o Relaxa e Durma: Início e Modo Silêncio;
  - o complemento gravado em 28/10, sem cortes: Chuva → 30 minutos, a
    notificação na barra, ~13 s de tela bloqueada com o som tocando,
    Encerrar e a barra já sem a notificação;
  - o resto do original: Mentor, Dôjo, Jardim e Biblioteca.

  As emendas caem na lista do Relaxa e Durma, que é igual nas duas
  gravações. Os trechos e o comando estão em "Montagem do vídeo final",
  no fim.
- Na montagem, a gaveta de apps do aparelho ficou desfocada, porque expunha
  os apps instalados. A chuva subiu 24 dB, com limitador: a captura saiu a
  −46 LUFS, inaudível, e no vídeo está a −22 LUFS.
- O texto e os 6 capítulos da seção do vídeo descrevem o vídeo final nos 4
  idiomas. Diferente do roteiro, a volta ao app foi pelo ícone, não pela
  notificação, e a tela de bloqueio não mostra a notificação do Kairo. Os
  capítulos não prometem nenhuma das duas coisas.
- Os textos da declaração estão prontos (abaixo), mas **não foram enviados**.

**Falta (no Play Console)**
1. **Enviar a declaração** com os textos e o link abaixo, depois de passar
   pelo checklist do fim.
2. Na mesma visita, em **Segurança dos dados**, trocar a URL de exclusão de
   conta para https://www.thekairo.app/suporte#excluir-conta.

> O nome "Alexandra" aparece no vídeo público. A titular da conta autorizou o
> uso do nome (29/10/2026).

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

> https://www.thekairo.app/en/suporte#video

Use a versão em inglês. O link sem `/en` também funciona, mas escolhe o
idioma pelo navegador: se o do revisor não pedir pt, en, es ou de, a página
abre em português.

Se o formulário recusar uma página e pedir o arquivo de vídeo:
`https://www.thekairo.app/videos/kairo-demo.mp4`.

---

## Gravação do complemento (Android, vertical, ~30–40 s)

Gravado em 28/10/2026 (`~/Downloads/segundo-video-kairo.mp4`). O roteiro
fica aqui para o caso de regravar.

O caso de uso Media playback exige que o vídeo mostre **o usuário iniciando a
reprodução** — som tocando sozinho ao abrir o app não conta — e o som
seguindo fora do app. O passeio pelo app está na gravação original; este
trecho completa o vídeo.

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

Salve o arquivo em `~/Downloads` e monte o vídeo como em "Montagem do vídeo
final", abaixo.

## Checklist antes de enviar

- [x] O vídeo abre em `https://www.thekairo.app/en/suporte#video` numa aba
      anônima (conferido em 29/10).
- [x] O vídeo mostra o toque que inicia o som e o áudio seguindo com a tela
      bloqueada.
- [x] Os capítulos da página descrevem o vídeo final, nos 4 idiomas.
- [ ] O AAB enviado continua só com `mediaPlayback`: conferir
      `build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml`
      depois de mexer em plugins.

## Montagem do vídeo final (29/10/2026)

O original é `~/Downloads/kairo-demo-original-hevc.mp4` e o complemento é
`~/Downloads/segundo-video-kairo.mp4`, ambos em HEVC 1080×2400.

| Trecho | Arquivo | De → até | Mostra |
|---|---|---|---|
| 1 | original | 0 → 11,40 s | Início, Modo Silêncio, abre o Relaxa e Durma |
| 2 | complemento | 2,40 → 55,20 s | Chuva → 30 minutos … barra sem a notificação |
| 3 | original | 22,20 s → fim | Início, Mentor, Dôjo, Jardim, Biblioteca |

- O áudio de cada trecho começa no 1º quadro dele (2,435 e 22,239 s). Se o
  corte do áudio ficasse em 2,40, ele sairia 35 ms à frente da imagem.
- A gaveta de apps aparece nítida em 14,20–15,70, 21,09–23,20 e
  52,46–53,45 s do complemento, e é ali que entra o `gblur`. Na barra de
  notificações, o próprio sistema já desfoca o fundo.
- O `fps=30` vai depois do concat: sem taxa fixa, o x264 calcula o nível
  H.264 errado.

```bash
OR=~/Downloads/kairo-demo-original-hevc.mp4; NV=~/Downloads/segundo-video-kairo.mp4
CORTE="crop=1080:2304:0:96,scale=720:-2"
BLUR="gblur=sigma=24:enable='between(t,14.20,15.70)+between(t,21.09,23.20)+between(t,52.46,53.45)'"
ffmpeg -i "$OR" -i "$NV" -i "$OR" -filter_complex "
[0:v]$CORTE,trim=end=11.40,setpts=PTS-STARTPTS[v0];
[0:a]atrim=end=11.40,asetpts=PTS-STARTPTS[a0];
[1:v]$CORTE,$BLUR,trim=start=2.40:end=55.20,setpts=PTS-STARTPTS[v1];
[1:a]atrim=start=2.435:end=55.20,asetpts=PTS-STARTPTS,volume=24dB,alimiter=limit=0.84:attack=5:release=50:level=disabled[a1];
[2:v]$CORTE,trim=start=22.20,setpts=PTS-STARTPTS[v2];
[2:a]atrim=start=22.239,asetpts=PTS-STARTPTS[a2];
[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[vc][a];[vc]fps=30[v]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 23 -pix_fmt yuv420p -c:a aac \
  -movflags +faststart kairo-demo.mp4
```

Os tempos valem só para essas duas gravações. Numa regravação, meça de novo
com a luminância média de cada quadro (`signalstats`: app ≈ 42, gaveta
≈ 204, tela inicial ≈ 110) e confira os quadros em volta de cada emenda.
