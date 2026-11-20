# Tela Detalhe da música Specification

## Problem Statement

A Biblioteca já lista músicas, mas tocar numa `SongRow` hoje cai num placeholder genérico ("Em breve"). Não há como ver os naipes cadastrados, identificar o que falta, excluir uma música ou seguir para ensaiar (só ou em grupo). O Detalhe da música é o hub descrito em `UI_SPEC.md` §6.3 e `prd-cantae-ux-telas.md` §6.3 — próximo passo natural do mapa de navegação a partir da Biblioteca.

## Goals

- [ ] Autor/dono vê o estado real da música (naipes presentes/faltantes, origem) e consegue agir (excluir, seguir para preparo, ensaiar).
- [ ] Cantor que recebeu a música (`origin == received`) vê a mesma tela em modo somente leitura, sem controles de edição.
- [ ] Toda sub-funcionalidade ainda não construída (Studio, Alinhamento, Letra, Histórico, Modo solo, Criar sala, Enviar faixa, Exportar) tem um destino de navegação real (placeholder "Em breve"), nunca um botão morto.

## Out of Scope

Documentado para evitar scope creep.

| Feature | Reason |
| --- | --- |
| Banner "rascunho do Studio pendente" (retomar/descartar corte) | Depende do Studio (corte de áudio), que ainda não existe no domínio (sem entidade de rascunho). Fica para quando o Studio for especificado. |
| Tela de cadastro/edição de música | Fora do mapa desta feature; é o próximo nó do grafo de navegação, não este. A rota `song-detail` com `id: 'new'` (usada hoje pelo botão "Cadastrar primeira música" da Biblioteca) cai no estado "não encontrada" até essa tela existir. |
| Contagem real de "Ensaios anteriores (N)" | O domínio só guarda `lastRehearsedAt` (um timestamp), não uma contagem de ensaios. Decisão do usuário: não estender o domínio agora. |
| Studio, Alinhamento de faixas, Editor de letra, Histórico, Modo solo, Enviar faixa, Exportar, Criar sala — as telas em si | Cada uma é uma feature própria (fora do grafo desta tela). Aqui apenas garantimos que o Detalhe navega para um placeholder real. |
| Internacionalização / arquivo de localização formal | O projeto ainda não tem `.arb`/l10n (confirmado: `library-screen` também usa literais pt-BR direto nos widgets). Esta feature segue o mesmo padrão já em produção; não introduz l10n sozinha. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| "Ensaios anteriores (N)" sem contagem | A linha "Histórico" navega para um placeholder "Em breve", sem número. | Domínio não guarda contagem de ensaios; usuário escolheu não estender agora. | y |
| Ação "Excluir música" | Incluída nesta feature: `DestructiveButton` tonal no card de edição → `ConfirmSheet` de 1 etapa (sem confirmação digitada) → `repository.delete()` → volta para a Biblioteca. | Usuário escolheu incluir agora; `SongRepository.delete()` já existe. `AGENTS.md` só exige 2 etapas + confirmação digitada para "apagar todos os dados" (exclusão ampla), não para um item. | y |
| Duração no cabeçalho ("Autor · duração · origem") | Cabeçalho mostra apenas "Autor · Origem" — duração omitida. | Nem `Song` nem `SongTrack` guardam duração do áudio; obter isso exigiria sondar o arquivo (I/O pesado, fora do escopo de uma tela). Fica para quando houver metadado de duração. | n |
| "Enviar faixa" (naipe faltante) | Navega para um placeholder nomeado `track-upload` (`ComingSoonScreen`). | Não existe fluxo de importação/gravação de faixa individual ainda; precisa de destino real, não botão morto. | n |
| Novas rotas placeholder necessárias | Adicionar ao `GoRouter`: `solo-player`, `studio`, `track-align`, `lyrics-editor`, `song-history`, `track-upload` — todas `ComingSoonScreen`, seguindo o padrão do AD-012. | Mesmo padrão já usado em `room-create`, `room-join`, `profile`, `package-import`: toda tela ainda não construída recebe uma rota nomeada real, nunca um `onTap` vazio. | n |
| "Criar sala a partir desta música" | Reusa a rota existente `room-create` (sem parâmetro de música por ora). | A tela de criar sala ainda é só placeholder; passar um `songId` hoje não teria consumidor. Quando `room-create` for especificada, ela decide se/como recebe esse parâmetro. | n |
| "Ensaiar em grupo" para música recebida (`origin == received`) | Permanece visível e habilitado. | Nada nos PRDs restringe criar/entrar numa sala a quem é autor da música — o papel de Mestre é da sessão, não da música. Só "Preparar" e "Enviar faixa" (ações de edição) são ocultos no modo somente leitura, conforme `UI_SPEC.md` §6.3. | n |
| "Excluir música" para música recebida | Permanece visível e habilitado. | É a cópia local do próprio usuário; apagá-la da biblioteca não é uma ação de edição da música em si (que seria proibida), é gestão do próprio armazenamento. | n |
| "Sincronizar letra" — texto da linha | Mostra "N linhas" quando `lyrics.isNotEmpty`, ou "Letra não sincronizada" quando vazio — sem a fração "3 de 5" do mock (não há um total esperado de linhas no domínio). | `Song.lyrics` só expõe uma lista; não há conceito de "total esperado" de linhas para formar uma fração. Inventar esse total seria fabricar requisito. | n |

**Open questions:** none — todas resolvidas ou registradas acima.

---

## User Stories

### P1: Ver o hub da música ⭐ MVP

**User Story**: Como autor de uma música, quero abrir o Detalhe a partir da Biblioteca e ver seu estado (naipes, origem, completude) para decidir o que fazer a seguir.

**Why P1**: É a tela em si — sem isso não há feature.

**Acceptance Criteria**:

1. WHEN o usuário toca numa `SongRow` da Biblioteca THEN o sistema SHALL navegar para `song-detail` com o `id` dessa música.
2. WHEN a tela `song-detail` carrega com um `id` existente THEN o sistema SHALL exibir nome, autor e origem ("Criada por você" / "Recebida") no cabeçalho.
3. WHILE a busca da música está em andamento the system SHALL exibir um estado de carregamento (esqueleto), sem naipes nem rodapé de ações.
4. IF o `id` da rota não corresponde a nenhuma música salva THEN o sistema SHALL exibir um estado "Música não encontrada" com uma ação para voltar à Biblioteca, sem exibir naipes, cabeçalho de dados ou rodapé de ações.
5. IF a busca da música falhar por erro do repositório (não por ausência) THEN o sistema SHALL exibir um `InlineBanner` de erro com ação "Tentar de novo".
6. The system SHALL exibir um grupo de 4 linhas de naipe (Soprano, Contralto, Tenor, Baixo): `VoicePartBadge` preenchido quando a música tem uma `SongTrack` não-playback daquele naipe, `VoicePartBadge` tracejado + ação "Enviar faixa" quando não tem.
7. WHEN a música tem os 4 naipes padrão cobertos THEN o sistema SHALL tratá-la como completa (sem aviso de naipe faltando); WHEN falta ao menos um THEN o sistema SHALL exibir um indicativo de incompletude visível no cabeçalho ou na seção de naipes.

**Independent Test**: Abrir a Biblioteca, tocar numa música completa e numa incompleta, confirmar que o cabeçalho e os selos de naipe refletem o estado real de cada uma; tocar numa `SongRow` cujo id foi removido do banco entre a listagem e o toque (ou navegar direto para um `id` inexistente) e ver o estado "não encontrada".

---

### P1: Preparar e ensaiar

**User Story**: Como autor, quero seguir do Detalhe para as etapas de preparo (Studio, Alinhamento, Letra) e para o ensaio (só ou em grupo), mesmo que essas telas ainda não existam.

**Why P1**: É o motivo de a tela existir no mapa de navegação — sem destinos reais, os links do hub seriam inertes.

**Acceptance Criteria**:

1. The system SHALL exibir a seção "Preparar" com 4 linhas: "Cortar áudio no Studio", "Alinhar entradas", "Sincronizar letra", "Ensaios anteriores".
2. WHEN o usuário toca em qualquer linha de "Preparar" THEN o sistema SHALL navegar para a rota placeholder correspondente (`studio`, `track-align`, `lyrics-editor`, `song-history` respectivamente).
3. WHEN o usuário toca em "Enviar faixa" de um naipe faltante THEN o sistema SHALL navegar para a rota placeholder `track-upload`.
4. The system SHALL exibir no rodapé uma ação secundária "Ensaiar só" e uma ação primária "Ensaiar em grupo".
5. WHEN o usuário toca em "Ensaiar só" THEN o sistema SHALL navegar para a rota placeholder `solo-player`.
6. WHEN o usuário toca em "Ensaiar em grupo" THEN o sistema SHALL navegar para a rota `room-create`.

**Independent Test**: Em uma música completa, tocar cada uma das 6 ações (4 de "Preparar" + 2 do rodapé) e confirmar que cada uma abre o placeholder/rota certo.

---

### P1: Modo somente leitura (música recebida)

**User Story**: Como cantor que recebeu uma música de outra pessoa, quero ver o Detalhe sem controles de edição que não me pertencem, para não ser levado a ações que não fazem sentido para mim.

**Why P1**: Requisito explícito do PRD/UI_SPEC para `origin == received`; sem isso o modo leitura simplesmente não existe.

**Acceptance Criteria**:

1. WHILE a música tem `origin == received` the system SHALL ocultar a seção "Preparar" por completo.
2. WHILE a música tem `origin == received` the system SHALL ocultar a ação "Enviar faixa" em qualquer naipe faltante (o selo tracejado continua visível, só a ação some).
3. WHILE a música tem `origin == received` the system SHALL manter visíveis e habilitadas: "Ensaiar só", "Ensaiar em grupo" e "Excluir música".

**Independent Test**: Abrir uma música com `origin: created` e uma com `origin: received`; confirmar que só a segunda esconde "Preparar" e "Enviar faixa", mantendo o resto idêntico.

---

### P1: Excluir música

**User Story**: Como autor (ou dono da cópia local), quero excluir uma música da minha Biblioteca quando não preciso mais dela, com uma confirmação que evite toques acidentais.

**Why P1**: Ação destrutiva explícita no PRD; `SongRepository.delete()` já existe, sem chamador — decisão do usuário foi ligar isso agora.

**Acceptance Criteria**:

1. The system SHALL exibir uma ação "Apagar desta música" (`DestructiveButton` variante tonal).
2. WHEN o usuário toca em "Apagar desta música" THEN o sistema SHALL abrir um `ConfirmSheet` de 1 etapa com ação destrutiva "Apagar definitivamente" e ação segura "Cancelar".
3. WHEN o usuário confirma em "Apagar definitivamente" THEN o sistema SHALL chamar `SongRepository.delete(id)` e, em caso de sucesso, navegar de volta para a Biblioteca.
4. IF `delete(id)` falhar THEN o sistema SHALL manter o usuário na tela do Detalhe e exibir um aviso de erro, sem navegar.
5. WHEN o usuário toca em "Cancelar" no `ConfirmSheet` THEN o sistema SHALL fechar a folha sem chamar `delete`.

**Independent Test**: Excluir uma música e confirmar que ela some da Biblioteca ao voltar; abrir o `ConfirmSheet` e cancelar, confirmar que a música continua intacta.

---

### P2: Exportar

**User Story**: Como autor, quero um atalho para exportar a música, mesmo que a exportação real ainda não exista.

**Why P2**: Citado no topo da tela pelo `UI_SPEC.md`, mas não bloqueia nenhuma das histórias P1 — é só mais um destino placeholder.

**Acceptance Criteria**:

1. The system SHALL exibir uma `NavPill` de ação "Exportar" no topo da tela.
2. WHEN o usuário toca em "Exportar" THEN o sistema SHALL navegar para a rota placeholder `package-import` reaproveitada como destino genérico de pacote — *(ver nota)*.

> Nota de implementação: `package-import` hoje só cobre importação. Caso o nome confunda no `ComingSoonScreen`, usar o título exibido (não a rota) para deixar claro que é "Exportar" — sem criar uma rota nova só para isso neste P2. Se isso for considerado confuso na implementação, cortar este P2 e registrar como follow-up é aceitável (P2 não é obrigatório para fechar a feature).

---

## Edge Cases

- IF o `id` da rota for `'new'` (usado hoje pelo botão "Cadastrar primeira música" da Biblioteca) THEN o sistema SHALL tratá-lo como "não encontrada" (mesmo caminho do AC "Ver o hub da música" #4), já que não existe tela de cadastro ainda.
- IF a música não tiver nenhum naipe cadastrado (lista `tracks` vazia) THEN o sistema SHALL exibir as 4 linhas de naipe todas como faltantes, sem erro.
- WHEN o usuário volta da tela (NavPill "‹ Biblioteca") THEN o sistema SHALL retornar à Biblioteca preservando o estado de busca/filtro/ordenação anteriores (comportamento padrão do `go_router`, sem estado extra a gerenciar aqui).

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| DETAIL-01 | P1: Ver o hub da música | Design | Verified |
| DETAIL-02 | P1: Ver o hub da música | Design | Verified |
| DETAIL-03 | P1: Ver o hub da música | Design | Verified |
| DETAIL-04 | P1: Ver o hub da música | Design | Verified |
| DETAIL-05 | P1: Ver o hub da música | Design | Verified |
| DETAIL-06 | P1: Ver o hub da música | Design | Verified |
| DETAIL-07 | P1: Ver o hub da música | Design | Verified |
| DETAIL-08 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-09 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-10 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-11 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-12 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-13 | P1: Preparar e ensaiar | Design | Verified |
| DETAIL-14 | P1: Modo somente leitura | Design | Verified |
| DETAIL-15 | P1: Modo somente leitura | Design | Verified |
| DETAIL-16 | P1: Modo somente leitura | Design | Verified |
| DETAIL-17 | P1: Excluir música | Design | Verified |
| DETAIL-18 | P1: Excluir música | Design | Verified |
| DETAIL-19 | P1: Excluir música | Design | Verified |
| DETAIL-20 | P1: Excluir música | Design | Verified |
| DETAIL-21 | P1: Excluir música | Design | Verified |
| DETAIL-22 | P2: Exportar | Design | Verified |
| DETAIL-23 | P2: Exportar | Design | Verified |

**Coverage:** 23 total, 23 mapped, 0 unmapped.

---

## Success Criteria

- [ ] Toda `SongRow` da Biblioteca abre um Detalhe funcional (não mais `ComingSoonScreen`).
- [ ] Música completa, incompleta, recebida (somente leitura) e inexistente têm telas distintas e corretas.
- [ ] Excluir uma música remove-a da Biblioteca de ponta a ponta (repositório real, não mock).
- [ ] Nenhum botão da tela fica sem destino de navegação (todo placeholder é uma rota real, nunca um `onTap` vazio).
