# Modo solo (solo-player) Specification

## Problem Statement

A pessoa que quer ensaiar sozinha não tem como tocar uma música da biblioteca fora de uma sala. O Detalhe da música já tem o botão "Ensaiar só" (`song_detail_screen.dart:301-302`), mas ele leva a um placeholder `ComingSoonScreen`. O RF11 (Must) pede reprodução local em modo solo, e o RNF-CONF-01 pede que ela funcione sem rede. As peças de áudio já existem:
- `AudioPlaybackEngine` com mudo e isolar;
- `LoopController` no domínio;
- letra sincronizada salva pelo Editor de letra.

## Goals

- [ ] A pessoa abre "Ensaiar só" e toca a música inteira, com todas as faixas sincronizadas, sem rede e sem sala.
- [ ] Durante a reprodução, a pessoa ajusta o mix de cada faixa (volume, mudo, isolar) e ouve o efeito na hora.
- [ ] A pessoa repete um trecho marcando início e fim do loop, e sai do loop seguindo da posição atual (RF10).
- [ ] A letra sincronizada acompanha a reprodução, mostrando a linha atual e a próxima.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Metrônomo no Modo solo (RF54) | Decisão do usuário: feature própria. Hoje não existe tocador de clique, só `MetronomePulseGenerator`. O clique sincronizado será reaproveitado também na sala (RF51/RF52). O botão "Metrônomo ♩ 72" do UI_SPEC §6.12 não aparece nesta feature. |
| Reprodução em segundo plano e com tela bloqueada (RF24) | Decisão do usuário: feature própria, que precisa de teste em aparelho Android/iOS real. Nesta feature, o áudio para quando a pessoa sai da tela. |
| Guardar o mix entre sessões | O PRD não pede. Os ajustes de volume, mudo e isolar valem enquanto a tela está aberta. |
| Registrar o ensaio no Histórico ou em `lastRehearsedAt` | Pertence à feature Histórico de ensaios (`mode: solo`, PRD consolidado §registro de ensaio). |
| Destaque "Próxima é sua" no `LyricView` | Depende do naipe padrão do Perfil, que ainda é placeholder. `LyricView` nasce com `userVoicePart` opcional, e o Modo solo passa nulo. |
| Escolher o trecho do loop pelas linhas da letra | Decisão do usuário: o loop é marcado com início e fim durante a reprodução. |
| Velocidade de reprodução e transposição | Fora do MVP (CLAUDE.md, Out of Scope). |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Metrônomo | Fica fora; vira feature própria | Decisão do usuário | y |
| Segundo plano / tela bloqueada | Fica fora; o áudio para ao sair da tela | Decisão do usuário | y |
| Como marcar o loop | Durante a reprodução: "Marcar início do loop", depois "Marcar fim do loop"; o trecho repete até desligar | Decisão do usuário | y |
| Mix por faixa | Volume (0–100 %) + M (mudo) + S (isolar) por faixa; o motor de áudio ganha volume por faixa | Decisão do usuário | y |
| Uma linha de mix por quê | Uma por faixa carregada: cada faixa de naipe e, se existir, o Playback. A linha mostra o selo e o nome do naipe ("Playback" para o Playback) | O motor carrega `song.tracks` e `song.playbackTrack`, e o mix age por `trackId`. Uma música pode ter mais de uma faixa do mesmo naipe | n: fato do domínio |
| Combinação de mudo, isolar e volume | Isolar é exclusivo: isolar uma faixa desfaz o isolar de outra. Enquanto há uma faixa isolada, só ela toca, com o volume dela. Sem isolar, a faixa muda fica em silêncio e as outras tocam com o próprio volume | Mesma regra que `MultiTrackAudioEngine` já aplica a mudo/isolar no Alinhamento; o volume entra como multiplicador | n: segue o precedente do código |
| O que fazer no fim da música | Ao chegar ao fim, a reprodução para, o botão volta a "Tocar" e o próximo "Tocar" recomeça de `0 ms` | Comportamento padrão de player. O PRD não especifica | n: assumido |
| Arrastar a barra de progresso | A pessoa pode tocar ou arrastar a barra para ir a outro instante, tocando ou em pausa | Controle básico de player; o UI_SPEC prevê `PlaybackProgress` no rodapé | n: assumido |
| "Marcar início/fim do loop" pausado | Só durante a reprodução: os botões ficam desabilitados em pausa | A decisão do usuário diz "durante a reprodução" | n: lido da decisão do usuário |
| Desligar o loop | Desliga e descarta o trecho; a reprodução segue da posição atual. Para repetir de novo, marca-se outro trecho | RF10: "Encerrar loop e seguir reprodução normal da posição atual". Guardar o trecho para religar seria um estado a mais, sem pedido | n: assumido |
| Fim do loop inválido | IF o instante marcado como fim for menor ou igual ao início THEN a marcação é recusada com erro inline e o início continua marcado | Mesmas regras de `LoopController.isValid` (`fimMs > inicioMs`) e do PRD consolidado §Alinhamento e loop | n: segue o PRD |
| Linhas sem tempo na letra | Linhas com `onsetMs` nulo não aparecem no `LyricView`; se nenhuma linha tiver tempo, aparece "Esta música ainda não tem letra sincronizada" | O `LyricView` acompanha o tempo; uma linha sem tempo não tem lugar na timeline | n: assumido |
| "Letra compacta" | O `LyricView` mostra a linha anterior (passada), a atual (card) e a próxima | `COMPONENTS.md` define `LyricLine.past/active/next`; "compacta" no UI_SPEC §6.12 = só essas três | n: lido dos docs |
| Texto do topo | `StatusPill` neutro "Funciona offline", sem "Sozinha" | "Sozinha" (UI_SPEC §6.12) supõe o gênero de quem usa. AGENTS.md pede "você" e o projeto evita supor pronomes | n: correção de texto; registrar no UI_SPEC |
| Música sem nenhuma faixa | Estado vazio "Esta música ainda não tem faixas" com ação "Enviar faixa" (rota `track-upload`) | Sem faixa não há o que tocar. "Enviar faixa" é a ação já existente no Detalhe para isso | n: assumido |

**Open questions:** none; all resolved or logged above.

---

## User Stories

### P1: Tocar a música sozinho ⭐ MVP

**User Story**: Como cantor ou autor, quero tocar uma música da minha biblioteca sem sala nem rede, com todas as faixas juntas, para ensaiar sozinho.

**Why P1**: É o RF11 (Must). Sem isso, "Ensaiar só" continua um placeholder.

**Acceptance Criteria**:

1. WHEN a pessoa toca "Ensaiar só" no Detalhe da música THEN o sistema SHALL abrir o Modo solo dessa música (rota com o id da música).
2. WHEN o Modo solo abre uma música com ao menos uma faixa THEN o sistema SHALL carregar todas as faixas (naipes e Playback, se houver) e mostrar o estado pausado em `0:00.0`, com a duração total em `m:ss.s`.
3. WHEN a pessoa toca "Tocar" THEN o sistema SHALL iniciar todas as faixas a partir da posição atual e o botão SHALL passar a "Pausar".
4. WHEN a pessoa toca "Pausar" THEN o sistema SHALL pausar todas as faixas na posição atual e o botão SHALL voltar a "Tocar".
5. WHILE toca, o sistema SHALL atualizar o tempo atual da `PlaybackProgress` com a posição da reprodução, no formato `m:ss.s`.
6. WHEN a pessoa toca ou arrasta a barra de progresso até um instante THEN o sistema SHALL levar todas as faixas a esse instante, mantendo o estado tocando ou pausado.
7. WHEN a reprodução chega ao fim da música (posição ≥ duração) THEN o sistema SHALL parar, mostrar "Tocar" e o próximo "Tocar" SHALL recomeçar de `0 ms`.
8. WHEN a pessoa sai do Modo solo THEN o sistema SHALL parar o áudio, sem deixá-lo tocando em segundo plano.
9. The system SHALL funcionar sem nenhuma conexão de rede: nenhum estado da tela depende de rede (RNF-CONF-01).

**Independent Test**: Abrir "Ensaiar só" numa música com 4 faixas, tocar, ver o tempo andar, pausar, arrastar a barra para 1:00.0, tocar de novo e conferir que todas as faixas foram levadas a 1:00.0.

---

### P2: Ajustar o mix por faixa

**User Story**: Como cantor, quero mudar o volume de cada naipe, mutá-lo ou isolá-lo, para ouvir melhor a minha voz ou o que preciso estudar.

**Why P2**: É a ação principal do UI_SPEC §6.12 ("Mix por naipe"), mas tocar a música (P1) já tem valor sozinho.

**Acceptance Criteria**:

1. The system SHALL mostrar, sob "Mix por naipe", uma linha por faixa carregada, com o selo e o nome do naipe ("Playback" para a faixa de Playback), um controle de volume e os botões M (mudo) e S (isolar).
2. WHEN a pessoa muda o volume de uma faixa para um valor entre 0 % e 100 % THEN o sistema SHALL aplicar esse volume só a essa faixa, sem mudar as outras.
3. WHEN a pessoa toca M numa faixa THEN o sistema SHALL silenciar essa faixa; WHEN toca M de novo THEN o sistema SHALL devolver o volume escolhido para ela.
4. WHEN a pessoa toca S numa faixa THEN o sistema SHALL tocar só essa faixa (com o volume dela) e silenciar todas as outras; WHEN toca S de novo na mesma faixa THEN o sistema SHALL voltar a tocar todas as faixas não mudas.
5. WHEN a pessoa toca S numa faixa enquanto outra faixa está isolada THEN o sistema SHALL isolar a nova e desfazer o isolar da anterior.
6. The system SHALL mostrar mudo e isolar com texto ou ícone além da cor (estado "ligado" do botão + rótulo semântico "Mudo"/"Solo", igual ao Alinhamento de faixas), conforme RNF-UX-05.
7. The system SHALL valer os ajustes de mix só enquanto o Modo solo está aberto: ao abrir de novo, toda faixa começa em 100 %, sem mudo e sem isolar.

**Independent Test**: Tocar uma música com 4 faixas, baixar o Tenor para 30 %, mutar o Baixo, isolar o Soprano e conferir no motor de áudio o volume efetivo de cada faixa; desfazer o isolar e conferir que Tenor volta a 30 % e Baixo continua mudo.

---

### P3: Repetir um trecho em loop

**User Story**: Como cantor, quero marcar o início e o fim de um trecho difícil e ouvi-lo em repetição, para estudar só aquela parte.

**Why P3**: É o loop do RF09/RF10 aplicado ao solo. Tocar e mixar já cobrem o uso básico.

**Acceptance Criteria**:

1. WHILE toca sem loop, o sistema SHALL oferecer "Marcar início do loop".
2. WHEN a pessoa toca "Marcar início do loop" THEN o sistema SHALL guardar o instante atual como início e passar a oferecer "Marcar fim do loop".
3. WHEN a pessoa toca "Marcar fim do loop" com o instante atual maior que o início THEN o sistema SHALL ligar o loop com esse trecho e mostrar "Repetindo trecho `m:ss`–`m:ss`".
4. IF a pessoa toca "Marcar fim do loop" com o instante atual menor ou igual ao início THEN o sistema SHALL recusar a marcação, mostrar um erro inline e manter o início marcado.
5. WHILE o loop está ligado, WHEN a posição de reprodução chega ao fim do trecho THEN o sistema SHALL levar todas as faixas ao início do trecho e seguir tocando.
6. WHEN a pessoa toca "Desligar loop" THEN o sistema SHALL descartar o trecho e seguir tocando da posição atual, sem pular (RF10).
7. WHILE a reprodução está pausada, o sistema SHALL manter "Marcar início do loop" e "Marcar fim do loop" desabilitados.
8. The system SHALL mostrar o trecho do loop na `PlaybackProgress` (região `accentTrack`) enquanto o loop está ligado.

**Independent Test**: Tocar, marcar início em 0:41, marcar fim em 1:12, ver "Repetindo trecho 0:41–1:12", deixar a posição chegar a 1:12 e conferir o salto para 0:41; desligar o loop em 0:50 e conferir que segue de 0:50.

---

### P4: Acompanhar a letra sincronizada

**User Story**: Como cantor, quero ver a linha que está sendo cantada e a próxima enquanto ensaio sozinho.

**Why P4**: A letra ajuda, mas o ensaio solo funciona sem ela, e nem toda música tem letra sincronizada.

**Acceptance Criteria**:

1. WHERE a música tem ao menos uma linha de letra com tempo marcado, o sistema SHALL mostrar o `LyricView` com a linha anterior (passada), a linha atual e a próxima.
2. The system SHALL considerar como linha atual a linha marcada de maior `onsetMs` menor ou igual à posição de reprodução; antes da primeira linha, não há linha atual e a primeira linha aparece como "Próxima".
3. The system SHALL mostrar na linha atual o selo do naipe e "`Naipe` · `dinâmica`" quando a linha tiver naipe, e apenas a dinâmica quando não tiver naipe.
4. IF nenhuma linha da letra tiver tempo marcado THEN o sistema SHALL mostrar "Esta música ainda não tem letra sincronizada" no lugar do `LyricView`.
5. The system SHALL anunciar a linha atual a leitores de tela como região viva.

**Independent Test**: Abrir uma música com 3 linhas marcadas (0:02, 0:05, 0:09), levar a posição a 0:06 e ver a linha de 0:02 como passada, a de 0:05 como atual e a de 0:09 como "Próxima".

---

## Edge Cases

- IF a música não for encontrada (id inválido) THEN o sistema SHALL mostrar "Música não encontrada" com a ação "Voltar à Biblioteca", como as outras telas.
- IF a leitura da música falhar no repositório THEN o sistema SHALL mostrar um erro com "Tentar de novo", que refaz a leitura.
- IF a música não tiver nenhuma faixa THEN o sistema SHALL mostrar o estado vazio "Esta música ainda não tem faixas" com a ação "Enviar faixa", sem controles de reprodução.
- IF o carregamento das faixas no motor de áudio falhar (arquivo ausente ou ilegível) THEN o sistema SHALL mostrar "Não foi possível tocar as faixas desta música." com "Tentar de novo", sem controles de reprodução.
- WHEN a pessoa arrasta a barra para depois do fim do loop ligado THEN o sistema SHALL voltar ao início do trecho no próximo instante de posição (mesma regra do AC P3-5).
- IF a pessoa toca "Tocar"/"Pausar" várias vezes seguidas THEN o sistema SHALL refletir no botão o último toque, sem deixar faixas fora de sincronia (cada comando age sobre todas as faixas).

---

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | Volume 0–100 % (P2-AC2); fim do loop > início (P3-AC4); seek limitado a 0..duração (P1-AC6) |
| Failure / partial-failure | Não encontrada, erro de leitura, falha ao carregar o áudio (Edge Cases) |
| Idempotency / retry / duplicates | "Tentar de novo" refaz a leitura/carregamento; toques repetidos em Tocar/Pausar (Edge Cases) |
| Auth boundaries & rate limits | N/A because é uma tela local, sem sala nem papéis: todo dono da biblioteca pode usá-la (UX §6.12 "Papéis: todos") |
| Concurrency / ordering | Comandos de reprodução sempre agem sobre todas as faixas juntas (Edge Cases); o salto do loop é disparado pelo fluxo de posição |
| Data lifecycle / expiry | Nada é persistido; o mix e o loop vivem enquanto a tela está aberta (P2-AC7) |
| Observability | N/A because o app não tem infraestrutura de log/telemetria e o PRD proíbe envio para servidor |
| External-dependency failure | Arquivo de áudio ausente/ilegível → erro de carregamento (Edge Cases). Não há dependência de rede (P1-AC9) |
| State-transition integrity | pausado ↔ tocando → fim (P1-AC3/4/7); loop: nenhum → início marcado → ligado → nenhum (P3) |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| SOLO-01 | P1-AC1: rota a partir do Detalhe | Specify | Pending |
| SOLO-02 | P1-AC2: carregar faixas, estado inicial | Specify | Pending |
| SOLO-03 | P1-AC3/AC4: tocar e pausar | Specify | Pending |
| SOLO-04 | P1-AC5: tempo atual | Specify | Pending |
| SOLO-05 | P1-AC6: arrastar a barra | Specify | Pending |
| SOLO-06 | P1-AC7: fim da música | Specify | Pending |
| SOLO-07 | P1-AC8: parar ao sair | Specify | Pending |
| SOLO-08 | P1-AC9: sem rede | Specify | Pending |
| SOLO-09 | P2-AC1/AC6: linhas de mix e estado não só por cor | Specify | Pending |
| SOLO-10 | P2-AC2: volume por faixa | Specify | Pending |
| SOLO-11 | P2-AC3: mudo | Specify | Pending |
| SOLO-12 | P2-AC4/AC5: isolar exclusivo | Specify | Pending |
| SOLO-13 | P2-AC7: mix só na sessão | Specify | Pending |
| SOLO-14 | P3-AC1/AC2/AC7: marcar início | Specify | Pending |
| SOLO-15 | P3-AC3/AC4: marcar fim e validar | Specify | Pending |
| SOLO-16 | P3-AC5: repetir o trecho | Specify | Pending |
| SOLO-17 | P3-AC6: desligar seguindo da posição atual | Specify | Pending |
| SOLO-18 | P3-AC8: trecho na barra de progresso | Specify | Pending |
| SOLO-19 | P4-AC1/AC2: LyricView passada/atual/próxima | Specify | Pending |
| SOLO-20 | P4-AC3: selo + "Naipe · dinâmica" | Specify | Pending |
| SOLO-21 | P4-AC4: sem letra sincronizada | Specify | Pending |
| SOLO-22 | P4-AC5: região viva | Specify | Pending |
| SOLO-23 | Edge: não encontrada / erro de leitura | Specify | Pending |
| SOLO-24 | Edge: música sem faixas | Specify | Pending |
| SOLO-25 | Edge: falha ao carregar o áudio | Specify | Pending |

**ID format:** `SOLO-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 25 total, 0 mapped to tasks (Tasks phase pending)

---

## Success Criteria

- [ ] Uma pessoa sem rede abre "Ensaiar só", toca, ajusta o mix e repete um trecho sem sair da tela.
- [ ] Todas as faixas ficam no mesmo instante depois de tocar, pausar, arrastar a barra e saltar no loop.
- [ ] Nenhum áudio continua tocando depois de sair do Modo solo.
