# Roteiro de teste no aparelho — áudio em segundo plano

Confirma no celular o que o computador não consegue provar: tela bloqueada, notificação, ligação e fone (RF24; spec `.specs/features/background-audio/spec.md`).

**Situação:** ainda não executado. Ao executar, anote para cada passo "ok" ou o que aconteceu, o modelo do aparelho e a versão do sistema, e registre o resultado em `.specs/STATE.md`.

## Preparação

- Um celular Android 8 ou mais novo e, se houver, um iPhone com iOS 14 ou mais novo (o iPhone precisa de um Mac com Xcode).
- Fone com fio ou Bluetooth.
- Uma música com pelo menos duas faixas de naipe, de 3 minutos ou mais, com andamento definido (por exemplo, "Ave Verum Corpus", Mozart, 72 BPM).
- Outro celular para fazer uma ligação.
- Instalar a versão de teste: `flutter run --release -d <aparelho>`.

## Passo 0 — Teste automático no aparelho

1. Rodar `flutter test -d <aparelho> integration_test/background_audio_test.dart`.
   - **Esperado:** o teste passa. A saída tem as linhas `BACKGROUND_AUDIO_LOG`: `players=2`, os dois players com `playing=true` e `timeline_advanced` de 1500 ms ou mais. Isso confirma que as duas faixas tocam juntas e que o relógio avança (correções do Metrônomo solo).

## Passos

1. Abrir a música no Modo solo, colocar o fone e tocar "Tocar".
   - **Esperado:** todas as faixas soam juntas e o tempo na barra avança.
2. Aparelho Android 13 ou mais novo: conferir se o app pediu permissão de notificação.
   - **Esperado:** não pede; a notificação de mídia aparece mesmo assim. Se não aparecer, anotar: a premissa do spec precisa mudar.
3. Puxar a área de notificações.
   - **Esperado:** o nome da música, "Modo solo", o botão Pausar e a barra de posição.
4. Bloquear a tela e esperar 5 minutos, ouvindo.
   - **Esperado:** a música não corta nem para; ao fim dela, para sozinha.
5. Com a tela bloqueada, tocar Pausar e depois Tocar nos controles da tela bloqueada.
   - **Esperado:** pausa e volta do mesmo ponto. Ao desbloquear, o Modo solo mostra o mesmo estado.
6. Com a tela bloqueada, arrastar a barra de posição para o meio da música.
   - **Esperado:** a música continua do ponto escolhido; no app, a barra mostra a mesma posição.
7. No app, marcar um loop (início e fim) e ligar o metrônomo. Ir para a tela inicial do celular e abrir outro app que não toque som.
   - **Esperado:** o trecho continua repetindo e o clique continua no tempo.
8. Com a música tocando em segundo plano, receber uma ligação do outro celular; atender, conversar um pouco e desligar.
   - **Esperado:** a música pausa quando a ligação começa e **não volta** quando ela termina. Ao abrir o app: botão "Tocar" e o aviso "Música pausada: outro áudio começou".
9. Com a música tocando, abrir um vídeo em outro app.
   - **Esperado:** a música do Cantaê pausa e não volta sozinha. Ao voltar: o mesmo aviso do passo 8.
10. Com a música tocando, receber uma notificação com som (mensagem) ou usar uma instrução de navegação por voz.
    - **Esperado:** a música abaixa durante o som e volta ao volume normal, sem pausar.
11. Com a música tocando no fone, desconectar o fone.
    - **Esperado:** a música pausa e não sai pelo alto-falante. Ao abrir o app: "Tocar" e o aviso "Música pausada: fone desconectado".
12. Com a música tocando, voltar para a ficha da música pelo app ("Voltar").
    - **Esperado:** a música para e a notificação some.
13. Abrir o Modo solo de novo, tocar e fechar o app pela lista de apps recentes.
    - **Esperado:** a música para e a notificação some.
14. Abrir o Modo solo, tocar, pausar e deixar o app em segundo plano, pausado, por 15 minutos. Voltar ao app.
    - **Esperado (Android):** o app pode ter sido fechado pelo sistema e reabrir do início; isso é aceito. Anotar o que aconteceu.

## Cobertura

| Critério do spec | Passos |
| ---------------- | ------ |
| BGA-01, BGA-02, BGA-03 (serviço, sessão, modo de segundo plano) | 1, 4 |
| BGA-04 (segue tocando com mix, loop e metrônomo; fim) | 4, 7 |
| BGA-05, BGA-06, BGA-09 (notificação: título, estado, posição, só Tocar/Pausar e barra) | 3, 5, 6 |
| BGA-07, BGA-08 (Tocar/Pausar e barra pela tela bloqueada) | 5, 6 |
| BGA-10 (sair da tela ou fechar o app) | 12, 13 |
| BGA-11 (interrupção pausa e não volta) | 8, 9 |
| BGA-12 (som curto abaixa o volume) | 10 |
| BGA-13 (fone desconectado pausa) | 11 |
| BGA-14 (aviso ao voltar) | 8, 9, 11 |
| BGA-16 (teste automático) e correções do Metrônomo solo | 0 |
| Premissa: permissão de notificação no Android 13+ | 2 |
| Risco: app pausado em segundo plano pode ser fechado | 14 |
