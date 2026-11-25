# Metrônomo solo (solo-metronome) Specification

## Problem Statement

O Modo solo ainda não tem metrônomo. O RF54 (Should) pede um metrônomo independente no solo, o RF50 pede BPM, compasso e acento por música, e o RF53 pede volume local do clique. Hoje nenhuma tela define o andamento de uma música, então quase todas estão com `metronomeConfig` nulo. Existe só o cálculo dos pulsos no domínio (`MetronomePulseGenerator`), e nada toca o clique.

Ao investigar como fazer o clique cair no tempo da música, apareceram três bugs no áudio já entregue. Os dois primeiros quebram a reprodução num celular de verdade:
1. O motor só inicia a primeira faixa. `just_audio`'s `play()` só completa quando a reprodução pausa, e `MultiTrackAudioEngine.playAt` faz `await` de cada faixa em sequência.
2. O relógio da música não anda durante a reprodução. O motor lê a posição do `playbackEventStream`, que só emite em eventos, em vez do `positionStream`, que é contínuo.
3. O gerador de pulsos acumula atraso: usa intervalo inteiro (`60000 ~/ bpm`), cerca de 70 ms de atraso após 3 minutos a 72 BPM.

## Goals

- [ ] Num aparelho real, todas as faixas tocam juntas e o relógio avança durante a reprodução.
- [ ] No Modo solo, a pessoa liga um metrônomo que bate no tempo da música, inclusive depois de pausar, arrastar a barra e repetir um trecho em loop.
- [ ] A pessoa define e ajusta o andamento (BPM, tempos por compasso, acento) de uma música criada por ela, e o valor fica salvo na música.
- [ ] A pessoa ajusta o volume do clique sem mudar o das faixas.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Metrônomo coletivo na sala (RF51/RF52) | Pertence às telas de sala. A faixa de clique desta feature foi pensada para ser reaproveitada lá. |
| Subdivisões, "tap tempo", mudança de andamento no meio da música | Fora do RF50 (BPM, compasso, acento). |
| Deslocamento do primeiro tempo (anacruse) | Não existe campo no `MetronomeConfig`. O primeiro tempo cai em `0 ms` da timeline (ver Assumptions). |
| Editar "ligar ao abrir" (`enabledByDefault`) | Não pedido. O valor existente é respeitado e preservado ao salvar. |
| Reprodução em segundo plano / tela bloqueada | Feature própria (RF24), já registrada. |
| Testar o áudio num aparelho físico | O ambiente de teste é `flutter test`. As correções 1 e 2 seguem o contrato documentado do `just_audio` e são provadas por testes que imitam esse contrato. A confirmação em aparelho fica para a feature de segundo plano. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Música sem andamento definido | O Modo solo abre a folha "Andamento" para definir BPM e compasso, e grava na música (RF50) | Decisão do usuário | y |
| Volume do metrônomo | Uma linha "Metrônomo" em "Mix por naipe", com volume e M; o botão do rodapé liga e desliga | Decisão do usuário | y |
| Os 3 bugs de áudio | Primeiras tarefas desta feature, cada uma com teste de regressão que falha primeiro | Decisão do usuário | y |
| Música recebida de uma sala | É só leitura (precedente: `song_detail_screen.dart:218`). Com andamento salvo, o metrônomo liga e desliga, mas não se ajusta. Sem andamento, o botão fica desabilitado com uma frase explicando o motivo | AGENTS.md: nenhum controle inutilizável sem uma frase explicando por quê | n: segue o precedente de só-leitura |
| Som do clique | Um bipe curto sintetizado: tom mais agudo no primeiro tempo do compasso quando o acento está ligado; o mesmo tom em todos os tempos quando desligado | RF50 "acento do primeiro tempo"; nenhum asset de áudio existe no projeto | n: assumido |
| Primeiro tempo | O tempo 1 cai em `0 ms` da timeline compartilhada; não há deslocamento | O `MetronomeConfig` não tem campo de deslocamento; acrescentá-lo é mudança de domínio sem pedido | n: assumido; anacruse registrada como Out of Scope |
| Limites | BPM inteiro de 30 a 300; tempos por compasso de 2 a 16 | Os mesmos limites que o `MetronomeConfig` já impõe em asserts | n: segue o domínio |
| Ligar ao abrir | Se `enabledByDefault` for verdadeiro, o metrônomo já começa ligado ao abrir o Modo solo | Campo já existente no domínio (RF50) | n: assumido |
| Isolar (S) uma faixa com o metrônomo ligado | O clique continua soando: isolar silencia as outras vozes, não o metrônomo | Ensaiar uma voz isolada com o clique é o uso típico do metrônomo; no motor, isolar silenciava todas as outras faixas | n: decidido no T4 (lacuna do design) |
| Ajustes de volume e M do metrônomo | Valem só enquanto a tela está aberta, como o mix das faixas | Mesma regra do Modo solo (SOLO-13) | n: segue o precedente |

**Open questions:** none; all resolved or logged above.

---

## User Stories

### P1: Reprodução confiável no aparelho ⭐ MVP

**User Story**: Como cantor, quero que todas as faixas toquem juntas e que o tempo da música avance enquanto toca, para que o ensaio funcione num celular de verdade.

**Why P1**: Sem isso, nenhum recurso que depende do tempo (letra, loop, fim da música, metrônomo) funciona fora dos testes.

**Acceptance Criteria**:

1. WHEN o motor de áudio recebe o comando de tocar THEN o sistema SHALL enviar o comando de tocar a todas as faixas carregadas, sem esperar que a reprodução de uma faixa termine ou pause para iniciar a próxima.
2. WHEN o comando de tocar é enviado THEN o sistema SHALL concluir o comando sem esperar a reprodução pausar ou terminar.
3. WHILE a música toca, o sistema SHALL emitir a posição da timeline continuamente, a cada no máximo 200 ms, mesmo sem nenhum evento novo do player.
4. The system SHALL gerar o pulso de índice `n` do metrônomo em `round(n × 60000 / bpm)` ms, sem acumular erro entre pulsos.

**Independent Test**: com um player falso que só responde ao "tocar" quando pausa (como o Android), tocar uma música de 2 faixas e conferir que as duas receberam o comando; tocar e esperar 300 ms sem eventos e conferir que a posição avançou; gerar pulsos a 72 BPM e conferir o pulso 216 em `180000 ms`.

---

### P2: Ligar o metrônomo no Modo solo

**User Story**: Como cantor, quero ligar um metrônomo que bate junto com a música, para ensaiar no andamento certo.

**Why P2**: É o RF54 (Should).

**Acceptance Criteria**:

1. WHERE a música tem andamento definido, o sistema SHALL mostrar no rodapé o botão "Metrônomo ♩ `BPM`".
2. WHEN a pessoa toca o botão com o metrônomo desligado THEN o sistema SHALL ligar o metrônomo e mostrar o botão no estado ligado (positivo).
3. WHEN a pessoa toca o botão com o metrônomo ligado THEN o sistema SHALL desligar o metrônomo e as faixas da música SHALL continuar tocando sem interrupção.
4. WHILE o metrônomo está ligado, o sistema SHALL tocar um clique em cada tempo `round(n × 60000 / bpm)` da timeline, com o clique de acento no primeiro tempo de cada compasso quando o acento estiver ligado.
5. WHILE o metrônomo está ligado, WHEN a pessoa pausa, arrasta a barra ou o loop volta ao início do trecho THEN o sistema SHALL manter o clique alinhado à timeline (o clique se move junto com as faixas).
6. WHERE o andamento salvo tem "ligar ao abrir" (`enabledByDefault`), o sistema SHALL abrir o Modo solo com o metrônomo já ligado.
7. IF preparar o clique falhar THEN o sistema SHALL manter o metrônomo desligado, mostrar "Não foi possível preparar o metrônomo." e não interromper a música.

**Independent Test**: abrir uma música com 72 BPM / 4 tempos, ligar o metrônomo, tocar e conferir que o motor tem uma faixa de clique cujos cliques caem em 0, 833, 1667… ms, com acento em 0 e em 3333 ms; desligar e conferir que a faixa de clique saiu e as outras seguem tocando.

---

### P3: Definir e ajustar o andamento

**User Story**: Como autor da música, quero definir o BPM, os tempos por compasso e o acento, para que o metrônomo bata no andamento certo, agora e nas próximas vezes.

**Why P3**: Sem andamento definido o metrônomo não funciona, mas é um passo de preparo, feito uma vez por música.

**Acceptance Criteria**:

1. WHERE a música foi criada por quem usa e não tem andamento definido, WHEN a pessoa toca "Metrônomo" THEN o sistema SHALL abrir a folha "Andamento" com BPM 72, 4 tempos por compasso e acento ligado.
2. WHERE a música foi criada por quem usa e tem andamento definido, the system SHALL oferecer "Ajustar andamento", que abre a folha "Andamento" com os valores salvos.
3. IF o BPM estiver fora de 30–300 ou os tempos por compasso fora de 2–16 THEN o sistema SHALL mostrar o limite junto ao campo e manter "Salvar andamento" desabilitado.
4. WHEN a pessoa toca "Salvar andamento" com valores válidos THEN o sistema SHALL gravar o andamento na música via `SongRepository.save`, preservando `enabledByDefault`, fechar a folha, ligar o metrônomo com o novo andamento e mostrar o toast "Andamento salvo".
5. IF gravar falhar THEN o sistema SHALL manter a folha aberta com os valores digitados, mostrar "Não foi possível salvar o andamento." e não mudar o metrônomo.
6. WHERE a música foi recebida de uma sala e não tem andamento definido, the system SHALL manter o botão "Metrônomo" desabilitado e mostrar "Música recebida: só quem criou pode definir o andamento.".
7. WHERE a música foi recebida de uma sala, the system SHALL NOT oferecer "Ajustar andamento".

**Independent Test**: abrir uma música criada sem andamento, tocar "Metrônomo", digitar 96 e 3 tempos, salvar, ver "Metrônomo ♩ 96" ligado e conferir no repositório `MetronomeConfig(bpm: 96, beatsPerMeasure: 3)`.

---

### P4: Volume do metrônomo

**User Story**: Como cantor, quero deixar o clique mais baixo ou mais alto que as vozes.

**Why P4**: É o RF53 (Should). O metrônomo já é útil no volume padrão.

**Acceptance Criteria**:

1. WHILE o metrônomo está ligado, o sistema SHALL mostrar em "Mix por naipe" a linha "Metrônomo" com controle de volume e M, sem S.
2. WHEN a pessoa muda o volume do metrônomo THEN o sistema SHALL aplicar o volume só ao clique.
3. WHEN a pessoa toca M na linha do metrônomo THEN o sistema SHALL silenciar só o clique; WHEN toca de novo THEN o sistema SHALL devolver o volume escolhido.
4. The system SHALL valer o volume e o M do metrônomo só enquanto o Modo solo está aberto.

**Independent Test**: com o metrônomo ligado, baixar o volume da linha "Metrônomo" para 40 % e conferir que só a faixa de clique recebeu 0,4.

---

## Edge Cases

- WHEN a pessoa liga o metrônomo com a música tocando THEN o sistema SHALL alinhar o clique à posição atual antes de ele soar.
- WHEN o andamento é salvo com o metrônomo ligado THEN o sistema SHALL trocar o clique pelo do novo andamento, alinhado à posição atual.
- IF a música for longa THEN o sistema SHALL preparar o clique fora da thread de interface (CLAUDE.md: operações pesadas fora da UI thread).
- WHEN a pessoa sai do Modo solo THEN o sistema SHALL parar também o clique (já coberto por SOLO-07, agora incluindo a faixa de clique).

---

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | BPM 30–300, tempos 2–16 (P3-AC3); volume 0–100 % (P4) |
| Failure / partial-failure | Falha ao preparar o clique (P2-AC7); falha ao salvar o andamento (P3-AC5) |
| Idempotency / retry / duplicates | Salvar de novo regrava o mesmo andamento; ligar e desligar repetidamente sempre termina no último estado |
| Auth boundaries & rate limits | Música recebida é só leitura para o andamento (P3-AC6/AC7) |
| Concurrency / ordering | Ligar com a música tocando alinha antes de soar (Edge Cases); tocar inicia todas as faixas juntas (P1-AC1) |
| Data lifecycle / expiry | O andamento persiste na música; volume e M do clique só na sessão (P4-AC4); o arquivo de clique é temporário, na pasta de cache do app |
| Observability | N/A because o app não tem infraestrutura de log/telemetria e o PRD proíbe envio para servidor |
| External-dependency failure | Contrato do `just_audio` (play só completa ao pausar; posição contínua) coberto em P1 |
| State-transition integrity | metrônomo: sem andamento → definido → ligado ↔ desligado; ajuste com ele ligado troca o clique (Edge Cases) |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| MET-01 | P1-AC1/AC2: tocar inicia todas as faixas sem esperar | Specify | Pending |
| MET-02 | P1-AC3: posição contínua | Specify | Pending |
| MET-03 | P1-AC4: pulsos sem atraso acumulado | Specify | Pending |
| MET-04 | P2-AC1: botão "Metrônomo ♩ BPM" | Specify | Pending |
| MET-05 | P2-AC2/AC3: ligar e desligar | Specify | Pending |
| MET-06 | P2-AC4: cliques nos tempos, com acento | Specify | Pending |
| MET-07 | P2-AC5: clique alinhado ao pausar/arrastar/loop | Specify | Pending |
| MET-08 | P2-AC6: ligar ao abrir | Specify | Pending |
| MET-09 | P2-AC7: falha ao preparar o clique | Specify | Pending |
| MET-10 | P3-AC1/AC2: folha "Andamento" | Specify | Pending |
| MET-11 | P3-AC3: limites | Specify | Pending |
| MET-12 | P3-AC4: salvar andamento | Specify | Pending |
| MET-13 | P3-AC5: falha ao salvar | Specify | Pending |
| MET-14 | P3-AC6/AC7: música recebida | Specify | Pending |
| MET-15 | P4-AC1/AC2: linha e volume do metrônomo | Specify | Pending |
| MET-16 | P4-AC3: M do metrônomo | Specify | Pending |
| MET-17 | P4-AC4: volume e M só na sessão | Specify | Pending |
| MET-18 | Edge: ligar tocando / trocar andamento ligado alinha à posição | Specify | Pending |
| MET-19 | Edge: preparar o clique fora da UI thread | Specify | Pending |

**ID format:** `MET-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 19 total, 0 mapped to tasks (Tasks phase pending)

---

## Success Criteria

- [ ] Num celular, a música inteira toca com todas as faixas e o relógio avança.
- [ ] Depois de 3 minutos a 72 BPM, o clique está a no máximo 1 ms do tempo calculado (sem atraso acumulado).
- [ ] Uma música sem andamento ganha um andamento salvo pelo Modo solo, em menos de 30 segundos.
