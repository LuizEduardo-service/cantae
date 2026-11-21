# Tela Alinhamento de faixas Specification

## Problem Statement

Uma música com faixas cadastradas não pode ser ensaiada em grupo com sincronismo real até que o atraso de entrada (`startDelayMs`) de cada naipe seja ajustado e testado. Hoje `SongTrack.startDelayMs` existe no domínio (RF25) mas não tem nenhuma tela para editá-lo, testá-lo com mudo/solo/loop, nem salvá-lo — e o Detalhe da música já navega para `track-align` esperando essa tela (hoje um placeholder). Além disso, o motor de áudio atual (`AudioPlaybackEngine`/`MultiTrackAudioEngine`) só sabe tocar/pausar/parar/buscar *todas* as faixas juntas — não tem mudo, solo nem posição de reprodução por faixa, que esta tela precisa.

## Goals

- [ ] Autor/mestre ajusta o `startDelayMs` de cada naipe cadastrado por um campo `mm:ss.s`, com validação e clamp (nunca negativo).
- [ ] Autor/mestre testa o alinhamento com mudo e solo reais por faixa, em loop sobre um trecho marcado, antes de salvar.
- [ ] Salvar persiste os atrasos via `SongRepository` de ponta a ponta (sem mock) e mostra confirmação; saltar sem salvar pede confirmação.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Forma de onda real (decodificada do áudio) | Não há análise de sinal no projeto hoje. Decisão do usuário: onda estilizada/placeholder, que se desloca visualmente com `startDelayMs`, mas não representa o áudio real. |
| Arrastar a forma de onda para ajustar o atraso | Decisão do usuário: só o campo digitável `mm:ss.s` nesta versão. Arrastar fica para uma melhoria futura. |
| Loop de rede (RF08-10, Sala do Mestre) | O "Teste de loop" desta tela é inteiramente local (sem sala, sem outros dispositivos) — reaproveita o `LoopController` do domínio, mas não o `LoopRepositionMessage`/broadcast de rede já usado em `PlaybackCommandHandler`. |
| Editor de letra / pré-requisito dele | Fora desta tela; só é mencionado porque a letra exige alinhamento salvo antes (seção 8.2 do PRD refatorado) — essa checagem fica para quando o Editor de letra for especificado. |
| Cortar/editar o conteúdo do arquivo de áudio em si (Studio) | Alinhamento só desloca o início na timeline (`startDelayMs`); não corta nem reamostra o arquivo. Já documentado como decisão de produto em `prd-cantae-refatorado.md` §8.1. |
| `sourceTrimStartMs` ou qualquer campo de corte real do início do arquivo | Explicitamente fora do MVP, conforme `prd-cantae-refatorado.md` §8.1. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Mudo/Solo reais (não só visuais) | Estender `AudioPlaybackEngine`/`MultiTrackAudioEngine` com controle por faixa em tempo real (mudo independente por faixa; solo exclusivo — ativar solo numa faixa desativa o solo de qualquer outra). | Escolha explícita do usuário. | y |
| Forma de onda | Barras estilizadas, geradas deterministicamente (ex.: a partir do id da faixa), sem decodificar o áudio real; deslocam-se visualmente com o `startDelayMs` atual. | Escolha explícita do usuário. | y |
| Arrastar offset | Não incluído nesta feature — só o campo `mm:ss.s`. | Escolha explícita do usuário. | y |
| "Teste de loop" | Permite marcar início/fim de um trecho (dois campos `mm:ss.s`, mesmo padrão do campo de atraso — sem gesto de arrastar, consistente com a decisão anterior) e repete esse trecho continuamente enquanto o teste estiver ativo. Primeiro consumidor real do `LoopController` do domínio. | Escolha explícita do usuário ("permitir marcar um trecho, como na Sala do Mestre"). | y |
| Duração da música para validar o trecho de loop e os campos de atraso | O motor de áudio carrega as faixas (`loadSong`) assim que a tela entra no estado "faixas carregadas" (não só quando o usuário aperta "Ouvir em loop"); a duração reportada pelo motor (maior duração entre as faixas carregadas) define o limite superior dos campos. | Sem isso, não há como validar um trecho de loop ou um atraso contra o tamanho real do áudio; carregar o motor é uma operação local (arquivo já no dispositivo), não uma chamada de rede, então não há custo de UX perceptível em antecipar o load. | n |
| `TrackAlignRow` só aparece para naipes com faixa cadastrada | Naipe sem faixa não aparece na lista (nada para alinhar); não é o mesmo que o estado "Sem faixas" (que é quando *nenhum* naipe tem faixa). | `UI_SPEC.md` descreve "4 `TrackAlignRow`" para o caso normal; um naipe faltante não tem o que alinhar — mostrar uma linha vazia/desabilitada não ajudaria o usuário. | n |
| Faixa de playback (acompanhamento instrumental), quando existir | Não aparece como `TrackAlignRow` própria nesta tela (mantém a contagem de "4" do `UI_SPEC.md`, que é por naipe). Participa do teste de loop no seu próprio `startDelayMs` já salvo (normalmente 0), sem controle de mudo/solo/atraso aqui. | Ela não é um naipe; `UI_SPEC.md` só lista 4 linhas (uma por naipe). Ajustá-la fica para uma iteração futura caso necessário. | n |
| "Alterações não salvas" (gatilho do `ConfirmSheet` ao voltar) | Só conta edição do `startDelayMs` de alguma faixa. Mudo, solo e o trecho de loop marcado são estado de teste efêmero — nunca são persistidos, então nunca contam como "não salvo". | `UI_SPEC.md`/PRD só descrevem persistência do `startDelayMs` ("Persistência do valor ao salvar"). Tratar mudo/solo/loop como "alteração" geraria confirmações sem motivo real. | n |
| Persistência | Reaproveita `SongRepository.save(song)` (reconstrói o `Song` completo com a lista de `tracks` atualizada) — não adiciona um método novo ao repositório. | `Song` já expõe todos os campos necessários para reconstrução fiel (tracks, lyrics, metronomeConfig, playbackTrack, origin, lastRehearsedAt); `save()` já faz upsert completo. Evita um método de repositório de uso único. | n |
| Navegação a partir do Detalhe da música | `song_detail_screen.dart`'s linha "Alinhar entradas" passa a navegar com `pathParameters: {'id': song.id}`; a rota `track-align` ganha o segmento `:id`. | A tela de alinhamento é por música — sem o id, não há o que carregar. Ajuste mínimo e necessário em duas linhas já existentes (`app_router.dart`, `song_detail_screen.dart`). | n |
| Toast ("Atrasos salvos") | Novo componente compartilhado `Toast` (`lib/presentation/widgets/toast.dart`), seguindo `COMPONENTS.md` (fundo `toastBg`, texto `onToast`, raio 14, check à esquerda, some em ~2,5 s). Primeiro consumidor. | `COMPONENTS.md` já define o componente; "Salvar atrasos (toast 'Atrasos salvos')" exige exatamente esse feedback. Construído como componente reutilizável antes de usar, por `AGENTS.md` §5. | n |
| Falha ao carregar o áudio no motor (arquivo ausente/corrompido) | Estado de erro dedicado (`InlineBanner` erro + "Tentar de novo"), distinto do estado "Sem faixas". | É uma falha de infraestrutura real (I/O), não a ausência de faixas cadastradas — merecem tratamentos diferentes (`UI_GUIDELINES.md`/`AGENTS.md` exigem estado de erro explícito). | n |

**Open questions:** none — todas resolvidas ou registradas acima.

---

## User Stories

### P1: Ver o alinhamento carregado ⭐ MVP

**User Story**: Como autor/mestre, quero abrir "Alinhar entradas" a partir do Detalhe da música e ver uma linha por naipe cadastrado, com seu atraso atual, para saber o que ajustar.

**Why P1**: É a tela em si.

**Acceptance Criteria**:

1. WHEN o usuário toca em "Alinhar entradas" no Detalhe de uma música THEN o sistema SHALL navegar para `track-align` com o `id` dessa música.
2. WHILE a música e suas faixas estão sendo buscadas the system SHALL exibir um estado de carregamento, sem `TrackAlignRow` nem rodapé de ações.
3. IF a música não tiver nenhuma faixa cadastrada (nenhum naipe) THEN o sistema SHALL exibir um `EmptyState` ("Sem faixas") com ações para ir ao Studio (`goNamed('studio')`) ou enviar faixa (`goNamed('track-upload')`), sem exibir nenhum `TrackAlignRow` nem rodapé.
4. WHEN a música tem ao menos uma faixa cadastrada THEN o sistema SHALL exibir um `TrackAlignRow` para cada naipe com faixa (nunca para um naipe sem faixa), mostrando selo do naipe, atraso atual formatado `mm:ss.s` e uma forma de onda estilizada deslocada visualmente por esse atraso.
5. WHEN as faixas carregam no motor de áudio com sucesso THEN o sistema SHALL habilitar os campos de atraso, o trecho de loop e "Ouvir em loop".
6. IF o motor de áudio falhar ao carregar alguma faixa (arquivo ausente/corrompido) THEN o sistema SHALL exibir um `InlineBanner` de erro com ação "Tentar de novo", sem travar a tela.

**Independent Test**: Abrir o alinhamento de uma música com 2 de 4 naipes cadastrados e confirmar que só 2 `TrackAlignRow` aparecem; abrir uma música sem nenhuma faixa e ver o `EmptyState`.

---

### P1: Editar o atraso por campo

**User Story**: Como autor/mestre, quero digitar o atraso de uma faixa em `mm:ss.s` para corrigir o sincronismo sem depender de um gesto de arrastar.

**Why P1**: É a ação central da tela (RF25).

**Acceptance Criteria**:

1. WHEN o usuário digita um valor válido no campo de atraso de uma faixa THEN o sistema SHALL atualizar o `startDelayMs` dessa faixa em memória e deslocar visualmente sua forma de onda de acordo.
2. IF o usuário digitar um valor negativo ou um texto que não corresponda ao formato `mm:ss.s` THEN o sistema SHALL rejeitar a edição e manter o último valor válido, sem permitir que `startDelayMs` fique negativo (`SongTrack` já impõe isso via `assert`).
3. WHEN qualquer atraso é editado e ainda não salvo THEN o sistema SHALL marcar a tela como tendo alterações não salvas.

**Independent Test**: Editar o atraso de uma faixa para `0:01.5`, confirmar que a forma de onda daquela linha se desloca e que tentar voltar sem salvar aciona a confirmação.

---

### P1: Testar com mudo, solo e loop

**User Story**: Como autor/mestre, quero isolar (solo) ou silenciar (mudo) faixas e repetir um trecho em loop para ouvir se o ajuste ficou certo antes de salvar.

**Why P1**: É o propósito de teste descrito em RF25/§8.2 do PRD.

**Acceptance Criteria**:

1. WHEN o usuário ativa "Mudo" numa faixa durante o teste THEN o sistema SHALL parar de reproduzir o áudio dessa faixa, mantendo as demais, e esmaecer sua forma de onda (25%).
2. WHEN o usuário ativa "Solo" numa faixa durante o teste THEN o sistema SHALL reproduzir só essa faixa (silenciando as demais, independente do estado de Mudo delas) e destacar seu card com borda `accent`.
3. WHEN o usuário ativa "Solo" numa faixa enquanto outra já está em solo THEN o sistema SHALL desativar o solo da anterior (solo é exclusivo — nunca duas faixas em solo ao mesmo tempo).
4. WHEN o usuário define início e fim de um trecho (dois campos `mm:ss.s`) e toca em "Ouvir em loop" THEN o sistema SHALL tocar todas as faixas não mudadas a partir do início do trecho e, ao alcançar o fim, retornar ao início continuamente, até o usuário tocar em "Parar".
5. IF o fim do trecho for menor ou igual ao início, ou maior que a duração conhecida da música THEN o sistema SHALL rejeitar a edição desse campo e manter o último valor válido.
6. WHILE o teste está ativo the system SHALL mostrar o botão "Ouvir em loop" como "Parar".
7. WHEN o usuário toca em "Parar" THEN o sistema SHALL parar a reprodução e voltar o botão para "Ouvir em loop", mantendo os atrasos editados (não descarta edições).

**Independent Test**: Marcar um trecho de 2s, tocar em "Ouvir em loop", confirmar que reinicia ao fim do trecho continuamente; mutar uma faixa e confirmar que ela some do áudio sem parar as demais; ativar solo numa segunda faixa e confirmar que o solo da primeira desliga.

---

### P1: Salvar ou descartar

**User Story**: Como autor/mestre, quero salvar os atrasos ajustados ou ser avisado se eu tentar saltar sem salvar.

**Why P1**: Sem persistência real, o ajuste não serve a nada (RF25: "persistência de `startDelayMs`").

**Acceptance Criteria**:

1. WHEN o usuário toca em "Salvar atrasos" THEN o sistema SHALL chamar `SongRepository.save` com a música atualizada (mesmos dados, `tracks` com os novos `startDelayMs`) e, em caso de sucesso, mostrar um `Toast` "Atrasos salvos" e limpar a marca de alterações não salvas.
2. IF `save` falhar THEN o sistema SHALL manter a tela como está (sem navegar, sem limpar a marca de não salvo) e exibir um aviso de erro.
3. WHEN o usuário toca em "‹ nome da música" com alterações não salvas THEN o sistema SHALL abrir um `ConfirmSheet` perguntando se quer descartar; confirmando, o sistema SHALL navegar para `song-detail` sem salvar; cancelando, o sistema SHALL permanecer na tela.
4. WHEN o usuário toca em "‹ nome da música" sem alterações não salvas THEN o sistema SHALL navegar direto para `song-detail`, sem confirmação.
5. WHEN o usuário salva com sucesso e depois toca em "‹ nome da música" THEN o sistema SHALL navegar direto, sem confirmação (não há mais alterações não salvas).

**Independent Test**: Editar um atraso, tentar voltar e ver a confirmação; cancelar, salvar, voltar de novo e confirmar que não pede mais confirmação.

---

## Edge Cases

- IF o `id` da rota não corresponder a nenhuma música THEN o sistema SHALL exibir o mesmo estado "não encontrada" usado pelo Detalhe da música (`EmptyState` + voltar à Biblioteca) — não há alinhamento sem música.
- IF o usuário navegar para fora da tela enquanto o teste de loop está ativo (ex.: botão de voltar do sistema) THEN o sistema SHALL parar a reprodução ao sair, para não deixar áudio tocando em segundo plano indefinidamente.
- WHEN a música tem exatamente 1 faixa cadastrada THEN o sistema SHALL ainda assim permitir testar/editar/salvar normalmente (loop e solo funcionam com uma única faixa).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| ALIGN-01 | P1: Ver o alinhamento carregado | T8 | Implementing |
| ALIGN-02 | P1: Ver o alinhamento carregado | T4, T7 | Implementing |
| ALIGN-03 | P1: Ver o alinhamento carregado | T4, T7 | Implementing |
| ALIGN-04 | P1: Ver o alinhamento carregado | T4, T5, T7 | Implementing |
| ALIGN-05 | P1: Ver o alinhamento carregado | T4, T7 | Implementing |
| ALIGN-06 | P1: Ver o alinhamento carregado | T4, T7 | Implementing |
| ALIGN-07 | P1: Editar o atraso por campo | T2, T4, T5 | Implementing |
| ALIGN-08 | P1: Editar o atraso por campo | T4, T5 | Implementing |
| ALIGN-09 | P1: Editar o atraso por campo | T4 | Implementing |
| ALIGN-10 | P1: Testar com mudo, solo e loop | T2, T4, T5 | Implementing |
| ALIGN-11 | P1: Testar com mudo, solo e loop | T2, T4, T5 | Implementing |
| ALIGN-12 | P1: Testar com mudo, solo e loop | T2, T4 | Implementing |
| ALIGN-13 | P1: Testar com mudo, solo e loop | T4, T7 | Implementing |
| ALIGN-14 | P1: Testar com mudo, solo e loop | T4, T7 | Implementing |
| ALIGN-15 | P1: Testar com mudo, solo e loop | T4, T7 | Implementing |
| ALIGN-16 | P1: Testar com mudo, solo e loop | T4, T7 | Implementing |
| ALIGN-17 | P1: Salvar ou descartar | T4, T6, T7 | Implementing |
| ALIGN-18 | P1: Salvar ou descartar | T4, T7 | Implementing |
| ALIGN-19 | P1: Salvar ou descartar | T4, T7 | Implementing |
| ALIGN-20 | P1: Salvar ou descartar | T4, T7 | Implementing |
| ALIGN-21 | P1: Salvar ou descartar | T4, T7 | Implementing |

**Coverage:** 21 total, 21 mapped to tasks, 0 unmapped. All 21 reach the real screen end-to-end (Implementing) as of T8; awaiting the independent Verifier to promote to Verified.

---

## Success Criteria

- [ ] Uma música com faixas cadastradas tem alinhamento editável, testável (mudo/solo/loop reais) e salvável de ponta a ponta.
- [ ] Nenhum áudio continua tocando depois que o usuário sai da tela.
- [ ] `AudioPlaybackEngine`/`MultiTrackAudioEngine` ganham mudo/solo/posição/duração por faixa sem quebrar nenhum consumidor existente (`PlaybackCommandHandler`, `BackgroundAudioHandler`).
- [ ] `flutter analyze`/`flutter test` passam com os arquivos novos/alterados; `check_layers.py` e `dart analyze lib/domain/` continuam limpos.
