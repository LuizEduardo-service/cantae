# Ensaios anteriores (rehearsal-history) Specification

## Problem Statement

O RF39 (Should) pede um histórico local de ensaios por música, e o RF40 (Must) pede que esse histórico possa ser apagado por música ou por inteiro. O UI_SPEC §6.16 descreve a tela "Ensaios". Hoje nada registra ensaio:
- o `SongRepository.markRehearsed` existe e nunca é chamado, então a ordenação "Último ensaio" da Biblioteca nunca muda;
- a linha "Ensaios anteriores" do Detalhe da música abre a tela "em breve";
- não existe tabela nem entidade de ensaio.

As telas de sala ainda não existem, então hoje só o Modo solo pode gerar ensaios.

## Goals

- [ ] Um ensaio no Modo solo com pelo menos 60 s de música tocando fica registrado neste aparelho.
- [ ] A pessoa abre "Ensaios anteriores" de uma música e vê o resumo (ensaios, tempo, loops) e a lista de ensaios.
- [ ] A pessoa apaga os ensaios de uma música, ou todos os ensaios do aparelho, com confirmação.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Registrar ensaios de sala (Mestre, Cantor, Visitante) | As telas de sala ainda não existem. A tabela já guarda modo, papel e participantes para quando elas chegarem. |
| Apagar todos os dados do aparelho (Privacidade, §6.17) | Tela própria, ainda não construída. |
| Exportar ou fazer backup do histórico | O PRD exclui históricos pessoais do pacote exportado. |
| Desligar o registro de ensaios | O PRD diz "registrados por padrão", mas não define onde desligar; nenhuma tela de preferências existe ainda. |
| Editar um ensaio registrado | Não pedido. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Duração de um ensaio | Soma dos trechos em que a música estava tocando | Decisão do usuário | y |
| Loops de um ensaio | Quantas vezes o loop voltou ao início do trecho | Decisão do usuário | y |
| Mínimo para registrar | 60 s de duração (tocando) | PRD, "Histórico de ensaios" | y: segue o PRD |
| Quando o ensaio é gravado | Ao sair do Modo solo. Se o sistema fechar o app antes, aquele ensaio se perde | Uma sessão termina quando a pessoa sai da tela; gravar a cada pausa criaria vários ensaios por sessão | n: assumido |
| Papel no Modo solo | Nenhum (o campo fica vazio); participantes = 1 | O PRD lista papéis de sala (mestre, cantor, visitante); no solo não há sala | n: assumido |
| Início e fim | Início = primeiro "Tocar"; fim = saída do Modo solo | Campos `startedAt`/`endedAt` do `RehearsalLog` do PRD | n: assumido |
| Último ensaio da música | Gravar um ensaio também atualiza `lastRehearsedAt` (ordenação "Último ensaio" da Biblioteca) | `markRehearsed` existe para isso e nunca foi chamado | n: assumido |
| Apagar uma música | Apaga também os ensaios dela | Sem a música, o ensaio não tem onde aparecer | n: assumido |
| Falha ao gravar o ensaio | O ensaio se perde sem aviso: a pessoa já saiu da tela | Não há tela para mostrar o erro; o Modo solo não pode travar a saída | n: assumido |
| Formato da data | "25 nov 2026 · 19:40" | pt-BR, curto, sem pacote de localização | n: assumido |
| Formato de duração | `m:ss` abaixo de 1 hora, `h:mm:ss` a partir de 1 hora, em Geist Mono | AGENTS.md: todo número em Geist Mono | n: assumido |
| Ordem da lista | Mais recente primeiro | Uso comum de histórico | n: assumido |
| Música recebida no Detalhe | Mostra uma seção "Ensaios" só com "Ensaios anteriores (N)"; o resto do "Preparar" continua escondido | PRD UX §6.16: histórico para todos os papéis; PRD > UI_SPEC (AGENTS.md §2). Decidido no T8 | n: decidido no T8 |

**Open questions:** none; all resolved or logged above.

---

## User Stories

### P1: Registrar ensaios do Modo solo ⭐ MVP

**User Story**: Como cantor, quero que meus ensaios no Modo solo fiquem registrados, para acompanhar quanto ensaiei cada música.

**Why P1**: Sem registro, a tela de histórico fica sempre vazia.

**Acceptance Criteria**:

1. WHILE o Modo solo está aberto, o sistema SHALL somar como duração só o tempo em que a música está tocando.
2. WHILE o Modo solo está aberto, o sistema SHALL contar 1 loop cada vez que o loop volta ao início do trecho.
3. WHEN a pessoa sai do Modo solo com duração de pelo menos 60 s THEN o sistema SHALL gravar um ensaio com: música, início (primeiro "Tocar"), fim (saída), duração, modo "solo", papel vazio, 1 participante e o número de loops.
4. WHEN a pessoa sai do Modo solo com duração abaixo de 60 s THEN o sistema SHALL NOT gravar ensaio.
5. WHEN um ensaio é gravado THEN o sistema SHALL atualizar o último ensaio da música para o fim desse ensaio.
6. The system SHALL NOT gravar áudio, letra nem dados de outras pessoas no ensaio.
7. IF gravar o ensaio falhar THEN o sistema SHALL sair do Modo solo normalmente.

**Independent Test**: abrir o Modo solo, tocar, avançar o relógio da sessão 75 s com 3 voltas de loop, sair e conferir no repositório um ensaio de 75 s, modo solo, 3 loops, e o último ensaio da música atualizado.

---

### P2: Ver os ensaios de uma música

**User Story**: Como cantor, quero ver quantas vezes e por quanto tempo ensaiei uma música.

**Why P2**: É o RF39 (Should) e a tela do UI_SPEC §6.16. Depende de P1 para ter dados.

**Acceptance Criteria**:

1. The system SHALL mostrar na linha do Detalhe da música "Ensaios anteriores (N)", com N = número de ensaios da música, e "Ensaios anteriores" quando N = 0.
2. WHEN a pessoa toca essa linha THEN o sistema SHALL abrir a tela "Ensaios" daquela música.
3. The system SHALL mostrar no topo "‹" com o nome da música, o título "Ensaios" e a frase "Registrados só neste aparelho.".
4. The system SHALL mostrar 3 resumos: número de ensaios, tempo total e total de loops.
5. The system SHALL listar os ensaios do mais recente para o mais antigo, cada um com data e hora, "Modo solo", duração e loops.
6. WHERE a música não tem ensaios, the system SHALL mostrar "Nenhum ensaio registrado ainda" e o botão "Ensaiar agora", que abre o Modo solo da música.
7. WHILE os ensaios carregam, the system SHALL mostrar o estado de carregando.
8. IF ler os ensaios falhar THEN o sistema SHALL mostrar o erro com "Tentar de novo".
9. IF a música não existir THEN o sistema SHALL mostrar que ela não foi encontrada, com "Voltar à Biblioteca".

**Independent Test**: com 2 ensaios gravados (12:30 com 8 loops, 3:05 sem loops), abrir a tela e conferir "2", "15:35", "8" nos resumos e os dois ensaios na ordem certa.

---

### P3: Apagar ensaios

**User Story**: Como cantor, quero apagar os ensaios de uma música, ou todos, para controlar o que fica guardado no aparelho.

**Why P3**: É o RF40 (Must), mas só faz sentido com P1 e P2.

**Acceptance Criteria**:

1. WHERE a música tem ensaios, the system SHALL oferecer "Apagar desta música" (destrutivo, tonal) e "Apagar tudo" (secundário).
2. WHEN a pessoa toca "Apagar desta música" THEN o sistema SHALL pedir confirmação; WHEN confirma THEN o sistema SHALL apagar só os ensaios dessa música e mostrar o estado vazio.
3. WHEN a pessoa toca "Apagar tudo" THEN o sistema SHALL pedir confirmação dizendo que apaga os ensaios de todas as músicas; WHEN confirma THEN o sistema SHALL apagar todos os ensaios do aparelho e mostrar o estado vazio.
4. WHEN a pessoa cancela a confirmação THEN o sistema SHALL NOT apagar nada.
5. IF apagar falhar THEN o sistema SHALL manter a lista e mostrar "Não foi possível apagar os ensaios.".
6. WHEN os ensaios são apagados THEN o sistema SHALL mostrar o toast "Ensaios apagados" e o Detalhe da música SHALL mostrar o novo número.
7. WHEN uma música é apagada THEN o sistema SHALL apagar também os ensaios dela.

**Independent Test**: com ensaios em duas músicas, apagar os da primeira e conferir que a segunda mantém os seus; depois "Apagar tudo" e conferir que nenhuma tem ensaios.

---

## Edge Cases

- WHEN a música chega ao fim e a pessoa toca de novo THEN o sistema SHALL continuar somando no mesmo ensaio.
- WHEN a pessoa pausa por uma interrupção (ligação, fone) THEN o tempo pausado SHALL NOT contar.
- WHILE o app está em segundo plano e a música toca THEN o tempo SHALL contar normalmente.
- WHEN a pessoa nunca toca "Tocar" THEN o sistema SHALL NOT gravar ensaio.
- WHEN há muitos ensaios THEN a lista SHALL rolar sem travar a tela (lista preguiçosa).

---

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | Duração ≥ 60 s para gravar (P1-AC3/AC4); loops ≥ 0 |
| Failure / partial-failure | Falha ao gravar (P1-AC7); ao ler (P2-AC8); ao apagar (P3-AC5) |
| Idempotency / retry / duplicates | Sair do Modo solo grava no máximo um ensaio por sessão; apagar uma música sem ensaios não falha |
| Auth boundaries & rate limits | N/A because o histórico é local e pessoal, sem papéis nem rede |
| Concurrency / ordering | A lista sempre em ordem do mais recente; o Detalhe mostra a contagem atualizada depois de apagar (P3-AC6) |
| Data lifecycle / expiry | Ensaio persiste até ser apagado (P3) ou a música ser apagada (P3-AC7); sem expiração no PRD |
| Observability | N/A because o app não tem log/telemetria e o PRD proíbe envio para servidor |
| External-dependency failure | Só o banco local; falhas cobertas acima |
| State-transition integrity | Sessão: sem tocar → tocando ↔ pausado → saída (grava se ≥ 60 s) |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| HIST-01 | P1-AC1: duração = tempo tocando | Execute | Implementing |
| HIST-02 | P1-AC2: loops = voltas ao início do trecho | Execute | Implementing |
| HIST-03 | P1-AC3: grava ao sair com ≥ 60 s, com todos os campos | Execute | Implementing |
| HIST-04 | P1-AC4: não grava abaixo de 60 s | Execute | Implementing |
| HIST-05 | P1-AC5: atualiza o último ensaio da música | Execute | Implementing |
| HIST-06 | P1-AC6: sem áudio, letra ou dados de terceiros | Execute | Implementing |
| HIST-07 | P1-AC7: falha ao gravar não trava a saída | Execute | Implementing |
| HIST-08 | P2-AC1/AC2: linha "Ensaios anteriores (N)" abre a tela | Execute | Implementing |
| HIST-09 | P2-AC3: topo, título e frase | Execute | Implementing |
| HIST-10 | P2-AC4: 3 resumos | Execute | Implementing |
| HIST-11 | P2-AC5: lista do mais recente, com data, modo, duração e loops | Execute | Implementing |
| HIST-12 | P2-AC6: vazio com "Ensaiar agora" | Execute | Implementing |
| HIST-13 | P2-AC7/AC8/AC9: carregando, erro, música não encontrada | Execute | Implementing |
| HIST-14 | P3-AC1/AC2/AC4: apagar desta música com confirmação | Execute | Implementing |
| HIST-15 | P3-AC3/AC4: apagar tudo com confirmação | Execute | Implementing |
| HIST-16 | P3-AC5: falha ao apagar | Execute | Implementing |
| HIST-17 | P3-AC6: toast e contagem atualizada | Execute | Implementing |
| HIST-18 | P3-AC7: apagar a música apaga os ensaios | Execute | Implementing |
| HIST-19 | Edge: fim e tocar de novo, interrupções, segundo plano, nunca tocou | Execute | Implementing |

**ID format:** `HIST-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 19 total, 0 mapped to tasks, 19 unmapped

---

## Success Criteria

- [ ] Depois de ensaiar uma música por 2 minutos no Modo solo, ela aparece com 1 ensaio de cerca de 2:00 em "Ensaios anteriores".
- [ ] A Biblioteca ordenada por "Último ensaio" coloca essa música em primeiro.
- [ ] Apagar tudo deixa todas as músicas sem ensaios, em dois toques mais a confirmação.
