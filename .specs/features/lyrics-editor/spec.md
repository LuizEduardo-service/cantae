# Editor de letra (lyrics-editor) Specification

## Problem Statement

Quem prepara uma música hoje consegue cortar áudio, cadastrar faixas por naipe e alinhar as entradas, mas não existe forma de cadastrar a letra sincronizada ao áudio. Sem isso, o Mestre, o Cantor e o Visitante não têm o que a UX chama de `LyricView` durante o ensaio — a tela de Detalhe da música já reserva o atalho "Sincronizar letra · Letra não sincronizada" (`song_detail_screen.dart:270-273`), e a rota `lyrics-editor` já existe como placeholder `ComingSoonScreen`. Este é o próximo passo natural do fluxo de preparo (RF18-RF20).

## Goals

- [ ] O autor consegue cadastrar linhas de letra, marcar o instante inicial de cada uma ouvindo o áudio, e indicar naipe responsável e dinâmica por linha.
- [ ] A letra salva fica disponível em `Song.lyrics` para os consumidores já especificados de `LyricView` (Sala do Mestre, Cantor, Visitante, Modo solo) — nenhum desses consumidores é construído nesta feature.
- [ ] O autor pode sair e retomar a sincronização mais tarde sem perder linhas já digitadas, mesmo as que ainda não têm tempo marcado.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Construir o `LyricView` de reprodução (Sala do Mestre/Cantor/Visitante/Modo solo) | Consumidor da letra sincronizada; feature própria, fora do editor. |
| Excluir uma linha já criada | Não especificado em UI_SPEC §6.6 (sem ícone/ação de excluir no inventário de telas nem em COMPONENTS.md). Registrado como sugestão de UX a validar depois. |
| Reordenar manualmente linhas existentes (arrastar) | UI_SPEC §6.6 não menciona alça de arraste nesta tela (diferente de `TrackAlignRow`, que também não arrasta linhas, só o offset). Ordem é a de inserção. |
| Atribuir naipe/dinâmica a um "bloco" de várias linhas de uma vez (RF19 menciona "bloco") | RF19 é Must só para "por linha"; a atribuição em lote é um refinamento de UX, não um requisito funcional novo. |
| Editar a letra fora do app (importar `.lrc`/texto colado) | Fora do PRD consolidado para o MVP; cadastro é manual, linha a linha. |
| Pré-condição de alinhamento como bloqueio rígido | A faixa precisa existir (ver AC-LYR-02), mas UI_SPEC §6.6 pede "banner orientando", não uma tela bloqueada como em Alinhamento de faixas. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| ---------------------- | --------------- | --------- | ---------- |
| `LyricLine.onsetMs` deve aceitar "ainda não marcado" | Campo passa a ser `int?` (nulo = não marcado), com migração aditiva na tabela (`LyricLinesTable.onsetMs` permite `NULL`) | Decisão do usuário nesta sessão: opção "onsetMs opcional" | y |
| Ordem de exibição/persistência das linhas | Ordem manual = ordem em que as linhas foram salvas (o banco preserva pela ordem de inserção, `rowId`), independente de `onsetMs`; sem campo novo `orderIndex` (ver design.md) | Decisão do usuário: "ordem manual" — permite linhas não marcadas convivendo com marcadas na ordem real da letra | y |
| O que "Marcar agora" marca | Sempre a próxima linha não marcada, na ordem da letra (fluxo sequencial) | Decisão do usuário: "próxima linha não marcada" | y |
| Como o autor edita texto/naipe/dinâmica | Expande inline na própria linha (campo de texto, seletor de naipe, campo de dinâmica), sem navegação nem overlay — mesmo padrão do `TrackAlignRow` | Decisão do usuário: "expande na própria linha" | y |
| Definição de "alinhamento salvo" (pré-condição do PRD §8.2) | `song.tracks.isNotEmpty` (existe ao menos uma faixa cadastrada) | Não existe hoje nenhuma flag persistida de "alinhamento confirmado" — `track-align-screen` apenas grava `startDelayMs` nas faixas existentes. Exigir uma flag nova infla o escopo sem pedido explícito do PRD; a existência de faixas é a melhor aproximação local disponível. | n — assumido, não perguntado ao usuário por ser um fato de implementação, não uma decisão de produto |
| "Ouvir com a letra" sempre recomeça do zero ao ligar | Cada vez que o autor liga o modo de marcação (botão no topo), o motor toca a partir de `0 ms`. Dentro do modo, "Pausar"/"Continuar" retomam do ponto atual (ver linha "Comportamento de Pausar") | Mesma simplificação já usada em `track-align-screen`'s "Ouvir em loop" (reinicia do início do loop); evita um terceiro estado (tocando/pausado/retomando) sem pedido explícito de UX | n — assumido por precedente de código, registrado para validação |
| Limite de caracteres por linha de texto | 200 caracteres | PRD/UI_SPEC não definem um limite; 200 cobre qualquer verso real de música coral sem truncar, suficiente como guarda-corpo (RNF de robustez geral) | n — assumido |
| Limite de caracteres para o campo de dinâmica | 40 caracteres | Campo é um rótulo curto ("forte", "suave e lento"), não uma frase | n — assumido |
| Opções de naipe por linha | As 4 naipes padrão ou nenhum (não definido) — sem opção "Todos" | `LyricLine.naipe` é `Naipe?`, e o enum `Naipe` (domínio) não tem um valor "todos"/coro; `Naipe.custom` significa algo diferente ("naipe customizado reutilizável", AGENTS.md). Inventar um valor novo no enum de domínio só para esta tela extrapola RF19, que exige apenas "naipe responsável", não um caso de "coro unido" | n — assumido, corrigido durante o Design ao mapear contra o domínio real |
| Linha criada e nunca preenchida | A tela edita "linhas rascunho" (texto pode ficar vazio enquanto se edita); ao salvar, linhas ainda sem texto são ignoradas, não gravadas. `LyricLine` (domínio) continua proibindo texto vazio | Decisão do usuário (T5): "rascunho na tela". Excluir linha está fora de escopo, então bloquear o salvamento prenderia o autor numa linha criada por engano | y |
| Comportamento de "Pausar" | "Pausar" para o áudio e mantém o modo de marcação (rodapé visível); o botão vira "Continuar" e retoma do ponto onde parou. Sair do modo de marcação é uma ação separada; ligar "Ouvir com a letra" de novo recomeça do `0 ms` | Decisão do usuário (T5): "pausar e continuar". Corrige o design, que fazia "Pausar" sair do modo e recomeçar do zero — isso obrigaria ouvir a música desde o início para marcar as linhas do final | y |
| Marcação fora de ordem no tempo | IF o instante atual de reprodução for menor que o `onsetMs` da linha marcada anterior (na ordem da letra) THEN a marcação é rejeitada com erro inline, sem avançar a "próxima" | Garante que a ordem manual das linhas e a ordem temporal fiquem consistentes, o que os consumidores de `LyricView` (destaque da linha atual) vão precisar depois | n — assumido, é uma proteção de integridade, não uma decisão de produto |

**Open questions:** none — todas resolvidas ou registradas acima.

---

## User Stories

### P1: Cadastrar e marcar linhas da letra ⭐ MVP

**User Story**: Como autor da música, quero digitar as linhas da letra e marcar o instante em que cada uma começa ouvindo o áudio, para que a letra fique disponível sincronizada para quem ensaiar essa música.

**Why P1**: É o núcleo do RF18 — sem isso não existe letra sincronizada, e a tela continua sendo apenas o placeholder atual.

**Acceptance Criteria**:

1. WHEN o autor toca "+ Acrescentar linha" THEN o sistema SHALL criar uma nova linha vazia (texto vazio, `onsetMs` nulo, naipe nulo, dinâmica nula) ao final da ordem da letra, já expandida para edição de texto.
2. WHEN o autor confirma o texto de uma linha com pelo menos 1 caractere e no máximo 200 caracteres THEN o sistema SHALL salvar esse texto na linha.
3. IF o autor tenta confirmar uma linha com texto vazio (0 caracteres) THEN o sistema SHALL rejeitar a edição e manter o texto anterior da linha.
4. WHEN o autor toca "Ouvir com a letra" com ao menos uma faixa cadastrada na música THEN o sistema SHALL iniciar a reprodução de todas as faixas a partir de `0 ms` e entrar no estado "pré-visualizando".
5. WHILE o estado é "pré-visualizando" o sistema SHALL exibir no rodapé o texto da próxima linha não marcada e o instante atual de reprodução formatado `mm:ss.s`.
6. WHEN o autor toca "Marcar agora" durante a reprodução E existe uma linha não marcada THEN o sistema SHALL gravar o instante atual de reprodução como `onsetMs` da próxima linha não marcada, na ordem da letra, e avançar o indicador de "próxima" para a linha seguinte ainda não marcada.
7. IF o autor toca "Marcar agora" E o instante atual de reprodução for menor que o `onsetMs` da linha marcada imediatamente anterior na ordem da letra THEN o sistema SHALL rejeitar a marcação e exibir um erro inline, sem avançar o indicador de "próxima".
8. IF o autor toca "Marcar agora" E não existe nenhuma linha não marcada THEN o sistema SHALL manter o botão desabilitado (nada a marcar).
9. WHEN o autor toca "Pausar" THEN o sistema SHALL pausar a reprodução e manter o estado "pré-visualizando" com o indicador de "próxima" como estava; WHEN o autor toca "Continuar" THEN o sistema SHALL retomar a reprodução do ponto onde pausou, sem voltar a `0 ms`.
10. The system SHALL exibir, para cada linha, o `onsetMs` formatado `mm:ss.s` quando marcado, ou "—" quando `onsetMs` for nulo.
11. The system SHALL exibir no topo da tela a contagem "`X` de `Y` marcadas", onde `X` é o número de linhas com `onsetMs` não nulo e `Y` é o total de linhas.
12. WHEN o autor toca "Salvar" THEN o sistema SHALL persistir todas as linhas com texto (marcadas e não marcadas) na música via `SongRepository.save`, preservando a ordem da letra, e SHALL ignorar linhas que continuam sem texto.
13. IF a lista de linhas estiver vazia (nenhuma linha criada) THEN o sistema SHALL exibir um estado vazio com a ação "+ Acrescentar linha" em destaque, sem exibir o rodapé de marcação.
14. WHILE o estado é "pré-visualizando" o sistema SHALL destacar visualmente a linha de maior `onsetMs` marcado que seja menor ou igual ao instante atual de reprodução, entre as linhas com `onsetMs` não nulo (a "linha atual"); se nenhuma linha marcada tiver `onsetMs` menor ou igual ao instante atual, nenhuma linha é destacada.

**Independent Test**: Abrir a tela de uma música com faixas cadastradas e letra vazia, acrescentar 2 linhas, ouvir com a letra, marcar as duas, ver "2 de 2 marcadas", salvar, reabrir a tela e confirmar que as duas linhas e seus tempos persistiram.

---

### P2: Indicar naipe e dinâmica por linha

**User Story**: Como autor, quero indicar qual naipe canta cada linha e, opcionalmente, uma dinâmica (ex.: "forte", "suave"), para que quem ensaie saiba quando é a vez do seu naipe e como cantar o trecho.

**Why P2**: Cumpre RF19 (Must) e RF20 (Should), mas a letra já é útil e sincronizável sem essa informação — por isso não é bloqueante do MVP.

**Acceptance Criteria**:

1. WHEN o autor expande uma linha para edição THEN o sistema SHALL exibir um seletor com as 4 naipes padrão e "Nenhum" (não definido), com a opção atual da linha pré-selecionada.
2. WHEN o autor escolhe um dos 4 naipes padrão THEN o sistema SHALL salvar essa escolha como o naipe responsável da linha.
3. WHEN o autor escolhe "Nenhum" THEN o sistema SHALL salvar o naipe da linha como não definido (nulo).
4. WHEN o autor digita uma dinâmica com no máximo 40 caracteres e confirma THEN o sistema SHALL salvar esse texto como a dinâmica da linha.
5. IF o autor apaga o texto da dinâmica e confirma THEN o sistema SHALL salvar a dinâmica da linha como nula (dinâmica é opcional).
6. The system SHALL exibir, para cada linha com naipe definido, o selo do naipe seguido de "`Naipe` · `dinâmica`" quando a dinâmica existir, ou apenas o selo do naipe quando não existir.

**Independent Test**: Expandir uma linha já marcada, escolher "Soprano" e digitar "forte", confirmar, e ver o selo de Soprano + "Soprano · forte" na linha recolhida.

---

### P3: Orientação quando o alinhamento não está pronto

**User Story**: Como autor, quero ser avisado quando a música ainda não tem faixas cadastradas, para entender por que não consigo ouvir e marcar a letra ainda.

**Why P3**: É uma orientação de UX (banner), não bloqueia a edição de texto/naipe/dinâmica — menos crítico que poder efetivamente sincronizar.

**Acceptance Criteria**:

1. IF a música não tem nenhuma faixa cadastrada (`song.tracks` vazio) THEN o sistema SHALL exibir um banner de orientação para cadastrar faixas antes de sincronizar, com um atalho para a tela de Alinhamento de faixas.
2. WHILE a música não tem nenhuma faixa cadastrada o sistema SHALL manter "Ouvir com a letra" e "Marcar agora" desabilitados, sem impedir criar/editar o texto, naipe e dinâmica das linhas.

**Independent Test**: Abrir a tela para uma música sem faixas, ver o banner e os controles de reprodução desabilitados, confirmar que ainda é possível acrescentar e editar linhas de texto.

---

## Edge Cases

- IF a música não for encontrada (`songId` inválido) THEN o sistema SHALL exibir o estado "não encontrada", mesmo padrão já usado em `track-align-screen`.
- IF o autor tenta sair da tela com alterações não salvas (linha criada, texto editado, tempo marcado, naipe/dinâmica alterados desde o último salvamento) THEN o sistema SHALL exibir um `ConfirmSheet` perguntando se quer continuar editando ou descartar, antes de navegar para fora.
- WHEN o autor sai da tela (navegação ou fim do fluxo) THEN o sistema SHALL parar a reprodução iniciada por "Ouvir com a letra", não deixando áudio tocando em segundo plano.
- IF o salvamento falhar (erro do repositório) THEN o sistema SHALL manter a tela no estado atual, exibir um erro e não limpar as alterações não salvas do autor.

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --------------- | ----- | ----- | ------- |
| LYR-01 | P1: Cadastrar e marcar linhas da letra (AC1 — acrescentar linha) | Execute | Verified |
| LYR-02 | P1 (AC2/AC3 — editar e validar texto) | Execute | Verified |
| LYR-03 | P1 (AC4 — iniciar "Ouvir com a letra") | Execute | Verified |
| LYR-04 | P1 (AC5 — rodapé "próxima" + tempo atual) | Execute | Verified |
| LYR-05 | P1 (AC6 — marcar agora avança "próxima") | Execute | Verified |
| LYR-06 | P1 (AC7 — rejeitar marcação fora de ordem) | Execute | Verified |
| LYR-07 | P1 (AC8 — "Marcar agora" desabilitado sem linha pendente) | Execute | Verified |
| LYR-08 | P1 (AC9 — pausar) | Execute | Verified |
| LYR-09 | P1 (AC10 — exibição "—"/mm:ss.s) | Execute | Verified |
| LYR-10 | P1 (AC11 — contagem "X de Y marcadas") | Execute | Verified |
| LYR-11 | P1 (AC12 — salvar persistindo ordem) | Execute | Verified |
| LYR-12 | P1 (AC13 — estado vazio) | Execute | Verified |
| LYR-13 | P1 (AC14 — linha atual destacada) | Execute | Verified |
| LYR-14 | P2: Naipe e dinâmica por linha (AC1-AC3 — seletor de naipe) | Execute | Verified |
| LYR-15 | P2 (AC4/AC5 — dinâmica opcional) | Execute | Verified |
| LYR-16 | P2 (AC6 — exibição selo + dinâmica) | Execute | Verified |
| LYR-17 | P3: Orientação sem faixas (AC1 — banner) | Execute | Verified |
| LYR-18 | P3 (AC2 — controles desabilitados sem bloquear edição de texto) | Execute | Verified |
| LYR-19 | Edge: não encontrada | Execute | Verified |
| LYR-20 | Edge: ConfirmSheet ao saír com alterações não salvas | Execute | Verified |
| LYR-21 | Edge: parar reprodução ao saír | Execute | Verified |
| LYR-22 | Edge: falha ao salvar preserva alterações | Execute | Verified |

**ID format:** `LYR-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 22 total, 22 mapped, 0 unmapped

---

## Success Criteria

- [ ] O autor consegue cadastrar, ouvir, marcar, editar naipe/dinâmica e salvar uma letra completa sem sair do app nem usar outra ferramenta.
- [ ] Uma letra salva com linhas parcialmente marcadas reabre exatamente como foi deixada (texto, marcação, naipe, dinâmica e ordem preservados).
- [ ] Nenhuma marcação de tempo quebra a ordem temporal da letra (AC-LYR-06 nunca é violado por uma marcação aceita).
