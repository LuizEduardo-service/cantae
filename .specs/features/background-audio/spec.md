# Áudio em segundo plano no Modo solo (background-audio) Specification

## Problem Statement

O RF24 (Must) pede que a reprodução continue em segundo plano e com a tela bloqueada. Hoje o Modo solo só toca com o app aberto e a tela acesa.

A fase 4 deixou parte da base pronta, mas nada ligado:
- **Android:** o `AndroidManifest.xml` declara o serviço de primeiro plano do `audio_service` e a `MainActivity` estende `AudioServiceActivity`.
- **`BackgroundAudioHandler`:** foi feito para a sala (os comandos passam pelo broadcaster). Nunca foi registrado no app, porque `AudioService.init` não é chamado em `main.dart`.
- **iOS:** não declara `UIBackgroundModes: audio`.
- **Sessão de áudio:** nenhuma é configurada (`.playback` no iOS, foco de áudio no Android).
- **Interrupções:** a pausa por ligação ou por fone desconectado nunca foi exercitada (lacuna BG-04 da fase 4).

As correções de áudio da feature anterior (todas as faixas tocam juntas; o relógio avança) também nunca rodaram num aparelho.

## Goals

- [ ] Com o Modo solo tocando, a música continua quando a pessoa bloqueia a tela ou troca de app, com faixas, loop e metrônomo funcionando.
- [ ] Pela notificação e pela tela bloqueada, a pessoa vê o título da música, toca, pausa e muda a posição.
- [ ] Uma ligação, outro app tocando ou o fone desconectado pausam a música, e ela só volta quando a pessoa mandar.
- [ ] Existe um roteiro de teste em aparelho e um teste de integração pronto para rodar, que também confirma as correções de áudio da feature anterior.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Segundo plano nas telas de sala (Mestre, Cantor, Visitante) | As telas de sala ainda não existem. O handler é feito para receber outra tela depois. |
| Segundo plano em Alinhamento e Editor de letra | São telas de edição, não de ensaio. O comportamento delas não muda nesta feature. |
| Loop, metrônomo ou mix pela notificação | Decisão do usuário: a notificação tem só Tocar/Pausar e a barra de posição. |
| Capa (artwork) na notificação | Não existe imagem de música no app. |
| Mini player ao sair do Modo solo pelo app | O UI_SPEC §6.12 manda parar o áudio ao sair da tela; não há mini player no PRD. |
| Executar o teste em aparelho nesta feature | Decisão do usuário: nenhum aparelho disponível agora. O roteiro e o teste de integração ficam prontos; a execução fica registrada como pendência. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Controles da notificação | Título da música, Tocar/Pausar e a barra de posição arrastável | Decisão do usuário | y |
| Verificação em aparelho | Roteiro escrito + teste de integração pronto; execução adiada | Decisão do usuário: nenhum aparelho agora | y |
| Interrupção (ligação, outro app que toma o áudio) | Pausa e não retoma sozinha; a pessoa toca "Tocar" para voltar | `docs/tasks-cantae-mvp-consolidado.md` T4.11: "interrupções exigem retomada explícita" | y: segue o documento |
| Som curto de outro app (aviso, navegação) | O volume abaixa durante o aviso e volta sozinho; a música não pausa | Comportamento padrão de "duck" do sistema; pausar por um aviso de 1 s atrapalharia o ensaio | n: assumido |
| Fone desconectado | Pausa, para a música não sair no alto-falante | Padrão dos dois sistemas e o uso do app é com fone (AGENTS.md §1) | n: assumido |
| Aviso de pausa por interrupção | Toast ao voltar para a tela: "Música pausada: outro áudio começou" ou "Música pausada: fone desconectado" | AGENTS.md: mudança com efeito fora da tela mostra toast | n: assumido |
| Texto da notificação | Título = nome da música; subtítulo = "Modo solo" | Dado plausível; sem jargão | n: assumido |
| Sair do Modo solo pelo app | Para o áudio e tira a notificação | UI_SPEC §6.12 ("Sair da tela para o áudio") | y: segue o UI_SPEC |
| Fechar o app pela lista de recentes | Para o áudio e tira a notificação | Padrão do Android; sem tela, não há como controlar o loop e o metrônomo | n: assumido |
| Permissão de notificação (Android 13+) | Não pedir: notificação de sessão de mídia é isenta | Documentação do Android sobre `POST_NOTIFICATIONS`: notificações de sessão de mídia são isentas. Confirmar no roteiro de aparelho | n: a confirmar no aparelho |
| Handler da fase 4 (`BackgroundAudioHandler`, da sala) | Só pode existir um handler no app; ele passa a encaminhar os comandos para a tela ativa (hoje, só o Modo solo) | `audio_service` aceita um único `AudioService.init` por processo | n: decidido no design |

**Open questions:** none; all resolved or logged above.

---

## User Stories

### P1: Continuar tocando em segundo plano ⭐ MVP

**User Story**: Como cantor, quero bloquear a tela ou trocar de app sem a música parar, para ensaiar com o celular no bolso.

**Why P1**: É o RF24 (Must) e um critério de aceite do MVP ("Background audio works on both Android and iOS").

**Acceptance Criteria**:

1. The system SHALL iniciar o serviço de áudio em segundo plano (`AudioService.init`) uma vez, na abertura do app, antes de qualquer tela tocar.
2. The system SHALL configurar a sessão de áudio para reprodução de música (`.playback` no iOS; foco de áudio de mídia no Android) antes do primeiro "Tocar".
3. The system SHALL declarar no iOS o modo de segundo plano de áudio (`UIBackgroundModes: audio`) e manter no Android o serviço de primeiro plano do tipo `mediaPlayback` já declarado.
4. WHILE o Modo solo toca e o app está em segundo plano ou com a tela bloqueada, o sistema SHALL continuar tocando todas as faixas, com o mix, o loop e o metrônomo valendo como no app aberto.
5. WHEN a música chega ao fim em segundo plano THEN o sistema SHALL ficar pausado no fim, como no app aberto (o próximo "Tocar" recomeça do zero).

**Independent Test**: no computador, com um serviço de áudio falso: abrir o Modo solo, tocar, simular o app indo para segundo plano e conferir que o motor não recebeu pausa e que o loop continua voltando ao início do trecho. No aparelho: roteiro passo 1–3.

---

### P2: Controles na notificação e na tela bloqueada

**User Story**: Como cantor, quero tocar, pausar e mudar a posição pela tela bloqueada, sem desbloquear o celular.

**Why P2**: É parte do RF24 e do critério de aceite do MVP ("locked screen, tray controls"). Sem P1, não há o que controlar.

**Acceptance Criteria**:

1. WHILE o Modo solo está aberto com uma música carregada, o sistema SHALL publicar na notificação e na tela bloqueada o nome da música como título, "Modo solo" como subtítulo e a duração da música.
2. The system SHALL publicar o estado de reprodução (tocando ou pausado) e a posição da timeline sempre que tocar, pausar, mudar a posição ou o loop voltar ao início do trecho.
3. WHEN a pessoa toca "Tocar" ou "Pausar" na notificação ou na tela bloqueada THEN o sistema SHALL ter o mesmo efeito do botão Tocar/Pausar do Modo solo, e a tela SHALL mostrar o novo estado ao voltar.
4. WHEN a pessoa arrasta a barra de posição na notificação ou na tela bloqueada THEN o sistema SHALL ter o mesmo efeito de arrastar a barra do Modo solo.
5. The system SHALL oferecer na notificação só Tocar/Pausar e a barra de posição.
6. WHEN a pessoa sai do Modo solo pelo app THEN o sistema SHALL parar o áudio e tirar a notificação.
7. WHEN a pessoa fecha o app pela lista de recentes THEN o sistema SHALL parar o áudio e tirar a notificação.

**Independent Test**: com um serviço de áudio falso, abrir o Modo solo de "Ave Maria", conferir o título publicado; chamar o "Pausar" do handler e conferir que a tela mostra "Tocar"; chamar o "seek" do handler para 0:41 e conferir a posição na tela; sair da tela e conferir que a notificação foi retirada.

---

### P3: Interrupções e fone

**User Story**: Como cantor, quero que a música pause sozinha quando chega uma ligação ou o fone desconecta, e que só volte quando eu mandar.

**Why P3**: Proteção do uso real; depende de P1. O PRD pede retomada explícita (T4.11).

**Acceptance Criteria**:

1. WHEN o sistema operacional avisa uma interrupção que exige pausa (ligação, outro app tomando o áudio) THEN o sistema SHALL pausar todas as faixas e o metrônomo juntos e publicar o estado pausado.
2. WHEN a interrupção termina THEN o sistema SHALL continuar pausado até a pessoa tocar "Tocar".
3. WHEN o sistema operacional avisa um som curto de outro app (duck) THEN o sistema SHALL abaixar o volume durante o aviso e devolvê-lo ao fim, sem pausar.
4. WHEN o fone é desconectado com a música tocando THEN o sistema SHALL pausar todas as faixas e o metrônomo juntos.
5. WHEN a música foi pausada por interrupção ou por fone desconectado THEN o Modo solo SHALL mostrar o botão "Tocar" e o toast "Música pausada: outro áudio começou" ou "Música pausada: fone desconectado".
6. IF a pausa por interrupção falhar THEN o sistema SHALL manter o estado que de fato está tocando e não mostrar o toast de pausa.

**Independent Test**: com uma sessão de áudio falsa, tocar, emitir uma interrupção de pausa, conferir que o motor pausou e a tela mostra "Tocar" e o toast; emitir o fim da interrupção e conferir que nada voltou a tocar; emitir "fone desconectado" e conferir a pausa.

---

### P4: Roteiro e teste no aparelho

**User Story**: Como responsável pelo app, quero um roteiro e um teste prontos para confirmar no celular o que o computador não consegue provar.

**Why P4**: Os critérios de tela bloqueada só se provam num aparelho, e não há aparelho agora.

**Acceptance Criteria**:

1. The system SHALL ter um roteiro de teste em aparelho em `docs/`, com passos numerados e o resultado esperado de cada um, cobrindo: tela bloqueada, troca de app, controles da notificação, ligação, fone desconectado, fechar pelos recentes, todas as faixas tocando juntas e o relógio avançando.
2. The system SHALL ter um teste de integração (`integration_test/`) que, rodado num aparelho, abre o Modo solo com uma música de 2 faixas, toca, e grava num log que as duas faixas estão tocando e que a posição avançou.
3. The system SHALL registrar no `STATE.md` que o roteiro e o teste de integração ainda não rodaram num aparelho.

**Independent Test**: ler o roteiro e conferir os itens de P4-AC1; rodar `flutter analyze` com o teste de integração compilando.

---

## Edge Cases

- WHEN o app abre THEN o sistema SHALL NOT mostrar notificação nenhuma até o Modo solo carregar uma música.
- WHEN a pessoa toca "Tocar" na notificação depois do fim da música THEN o sistema SHALL recomeçar do zero, como no app.
- WHEN o loop está ligado e a pessoa arrasta a barra da notificação para fora do trecho THEN o sistema SHALL ter o mesmo efeito de arrastar a barra do app.
- IF `AudioService.init` falhar na abertura do app THEN o sistema SHALL abrir normalmente, e o Modo solo SHALL tocar com o app aberto, sem controles na notificação.
- WHILE o Modo solo está aberto, WHEN Alinhamento ou Editor de letra não estão abertos THEN só o Modo solo SHALL responder aos comandos da notificação (um dono por vez).

---

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | A posição vinda da notificação é limitada a 0–duração, como o arrastar do app (P2-AC4) |
| Failure / partial-failure | Falha no `AudioService.init` (Edge Cases); falha ao pausar na interrupção (P3-AC6) |
| Idempotency / retry / duplicates | "Pausar" com a música já pausada não muda nada; um só `AudioService.init` por processo (P1-AC1) |
| Auth boundaries & rate limits | N/A because o Modo solo não tem papéis; a sala (com papéis) está fora do escopo e o gate de papéis do BG-03 continua no handler da sala |
| Concurrency / ordering | Comandos da notificação e da tela passam pelo mesmo caminho (P2-AC3/AC4); um dono por vez (Edge Cases) |
| Data lifecycle / expiry | Nada é gravado; a notificação some ao sair do Modo solo ou fechar o app (P2-AC6/AC7) |
| Observability | N/A because o app não tem log/telemetria; o teste de integração grava seu próprio log (P4-AC2) |
| External-dependency failure | Interrupções e fone (P3); permissão de notificação no Android 13+ (Assumptions, a confirmar no aparelho) |
| State-transition integrity | tocando → pausado por interrupção → continua pausado → tocando só por comando (P3-AC1/AC2) |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| BGA-01 | P1-AC1: `AudioService.init` uma vez na abertura | Execute | Implementing |
| BGA-02 | P1-AC2: sessão de áudio `.playback` / foco de mídia | Execute | Implementing |
| BGA-03 | P1-AC3: `UIBackgroundModes: audio` + serviço `mediaPlayback` | Execute | Implementing |
| BGA-04 | P1-AC4/AC5: segue tocando com mix, loop e metrônomo; fim igual ao app | Execute | Implementing |
| BGA-05 | P2-AC1: título, subtítulo e duração publicados | Execute | Implementing |
| BGA-06 | P2-AC2: estado e posição publicados | Execute | Implementing |
| BGA-07 | P2-AC3: Tocar/Pausar pela notificação | Execute | Implementing |
| BGA-08 | P2-AC4: arrastar posição pela notificação | Execute | Implementing |
| BGA-09 | P2-AC5: só Tocar/Pausar e barra | Execute | Implementing |
| BGA-10 | P2-AC6/AC7: sair da tela ou fechar o app para e tira a notificação | Execute | Implementing |
| BGA-11 | P3-AC1/AC2: interrupção pausa e não retoma sozinha | Execute | Implementing |
| BGA-12 | P3-AC3: som curto abaixa o volume sem pausar | Execute | Implementing |
| BGA-13 | P3-AC4: fone desconectado pausa | Execute | Implementing |
| BGA-14 | P3-AC5/AC6: tela e toast após pausa externa | - | Pending |
| BGA-15 | P4-AC1: roteiro de teste em aparelho | - | Pending |
| BGA-16 | P4-AC2: teste de integração com log | - | Pending |
| BGA-17 | P4-AC3: pendência registrada no STATE.md | - | Pending |
| BGA-18 | Edge: falha no `AudioService.init` não impede o app | Execute | Implementing |
| BGA-19 | Edge: sem notificação antes de carregar; um dono por vez | Execute | Implementing |

**ID format:** `BGA-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 19 total, 0 mapped to tasks, 19 unmapped

---

## Success Criteria

- [ ] No computador, todos os critérios de P1–P3 que não dependem do sistema operacional passam com serviço e sessão de áudio falsos.
- [ ] O roteiro de aparelho cobre tela bloqueada, troca de app, notificação, ligação, fone e fechar pelos recentes.
- [ ] Quando rodado num aparelho, o roteiro confirma que a música toca 5 minutos com a tela bloqueada sem cortar.
