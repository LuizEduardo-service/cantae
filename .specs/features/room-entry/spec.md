# Criar sala + Entrar em sala Specification

## Problem Statement

A camada de sessão da Fase 3 já cria salas, anuncia-as no Wi‑Fi, recebe pedidos de entrada, aprova com handshake autenticado e limita a 8 participantes, mas nenhuma tela usa isso: "Criar sala" e "Entrar em sala" abrem a tela "Em breve". Sem essas duas telas, o ensaio coletivo — o centro do Cantaê (RF01, RF02, RF26, RF27) — não pode começar.

## Goals

- [ ] Um Mestre cria uma sala, vê o código de 4 dígitos e aprova ou recusa cada pedido de entrada pelo nome da pessoa.
- [ ] Um Cantor encontra a sala na lista do Wi‑Fi ou pelo código, pede para entrar e chega à sala depois da aprovação.
- [ ] Cada falha de entrada da seção "Diagnóstico de rede" do PRD (permissão, nenhuma sala, código inválido, aguardando, recusado, cheia, protocolo, conexão perdida) aparece como um estado visual distinto, com uma ação.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Sala do Mestre completa (§6.9): preparar, tocar, loop, metrônomo, latência | Próxima feature; aqui há uma sala provisória (context.md D2) |
| Tela do Cantor completa (§6.10): naipe, mix, letra | Próxima feature (D2) |
| Papel Visitante, "Entrar como visitante", troca de papel pelo Mestre (RF33–RF36) | Feature do Visitante (D3) |
| Transferência e preparação das faixas da música escolhida | Pertence à Sala do Mestre; a música aqui é só anunciada |
| Lista de mestres conhecidos (RF21) e transferência de autoridade (RF28) | Prioridade Should, fora do fluxo de entrada |
| Tela de Perfil e Onboarding (§6.1, §6.13) | Só o nome na sala é pedido aqui (D1) |
| Nome da rede Wi‑Fi na StatusPill ("Visível no Coral‑WiFi") | Ler o nome da rede exige permissão de localização no Android; fora do MVP desta tela |
| QR Code como alternativa ao código | PRD §12: fallback futuro |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Limite da sala (UI_SPEC diz 30, PRD diz 8) | 8 pessoas além do Mestre; texto "N de 8 na sala" e "Sala cheia (8 de 8)" | PRD > UI_SPEC (RF26); a máquina de estados já usa 8 | y (precedência) |
| Rodapé de Entrar em sala | "Você entra como Cantor." | Sem troca de papel nesta feature (D3) | y |
| Tamanho do nome na sala | 1 a 40 caracteres depois de tirar espaços das pontas | Cabe numa linha de `RoomTile` e `ParticipantRow` em 360 dp | n |
| Tempo até "Nenhuma sala neste Wi‑Fi" | 10 s sem nenhuma sala encontrada | Descoberta mDNS costuma responder em 1–3 s; 10 s evita falso "nenhuma" | n |
| Pedido sem resposta do Mestre | O pedido expira em 60 s (regra já existente na máquina de estados) e o Cantor vê "O Mestre não respondeu" | Reaproveita o prazo de NET-07 em vez de criar outro | n |
| Detecção de "sem permissão de rede local" | Android: erro de segurança informado pelo sistema. iOS: não detectável; dica no banner "Nenhuma sala" (ROOM-57) | O plugin de mDNS no iOS nunca informa permissão negada, só não encontra salas | y (context.md D6) |
| "Abrir ajustes" | Abre a página de ajustes do Cantaê no sistema | PRD §12 iOS: "Oferecer atalho para Ajustes" | n |
| "Versão do app incompatível" | Ação "Escolher outra sala" + frase "Atualize o Cantaê nos dois aparelhos." em vez de "Atualizar o app" | Não há loja nem servidor para onde levar a pessoa; a frase diz o que fazer | n |
| O Mestre sai da tela Criar sala ou da sala provisória | Com ninguém na sala nem pedindo: encerra sem perguntar. Com alguém: `ConfirmSheet` "Encerrar sala?" | Encerrar derruba os outros: ação com efeito fora da tela (AGENTS.md) | n |
| Cantor sabe por que saiu da sala | Uma única mensagem "A sala foi encerrada ou a conexão caiu." | O protocolo atual não distingue encerramento de queda de conexão | n |
| Música anunciada | Nome da música escolhida aparece no `RoomTile`; sem música, "Sem música escolhida" | D4; o Cantor reconhece a sala certa pela música | y |
| Código no anúncio do Wi‑Fi | Nunca anunciado; o `RoomTile` não mostra o código e o cantor sempre digita o que vê na tela do Mestre | NET-01 da Fase 3 (verificado) proíbe o código no anúncio; o código vira prova de que a pessoa vê a tela do Mestre (context.md D7) | y |
| "N pessoas" no `RoomTile` | Fora desta feature | Exige reanunciar o serviço a cada entrada/saída; a lista de quem entrou já aparece depois de entrar | n |

**Open questions:** none - all resolved or logged above.

---

## User Stories

### P1: Nome na sala ⭐ MVP

**User Story**: Como pessoa do coral, quero dizer uma vez como apareço na sala para que o Mestre saiba quem está pedindo para entrar.

**Why P1**: O Mestre aprova pelo nome (RF27, aprovação visual); sem nome não há como decidir.

**Acceptance Criteria**:

1. WHEN a pessoa abre Criar sala ou Entrar em sala sem nome salvo THEN o app SHALL mostrar a folha "Como você quer aparecer na sala?" antes de criar a sala ou procurar salas. (ROOM-01)
2. IF o nome, sem espaços nas pontas, tiver 0 ou mais de 40 caracteres THEN o app SHALL manter "Salvar nome" desativado e, acima de 40, mostrar "Use até 40 caracteres." (ROOM-02)
3. WHEN a pessoa toca "Salvar nome" THEN o app SHALL guardar o nome no aparelho e seguir para a tela pedida, sem perguntar de novo nas próximas vezes, inclusive depois de reabrir o app. (ROOM-03)
4. WHEN a pessoa fecha a folha sem salvar THEN o app SHALL voltar à Biblioteca sem criar sala nem procurar salas. (ROOM-04)

**Independent Test**: Abrir Criar sala num app limpo, digitar "Marina", salvar; fechar e reabrir o app; abrir Entrar em sala e ver que a folha não aparece.

---

### P1: Criar sala (Mestre) ⭐ MVP

**User Story**: Como Mestre, quero criar uma sala e aprovar quem entra para que só o meu coral participe do ensaio.

**Why P1**: RF01, RF26, RF27, RF29.

**Acceptance Criteria**:

1. WHEN Criar sala abre com nome salvo THEN o app SHALL mostrar "Gerando código" até a sala estar anunciada no Wi‑Fi e, em seguida, o `RoomCodeDisplay` com o código de 4 dígitos em Geist Mono e a `StatusPill` "Visível neste Wi‑Fi". (ROOM-05)
2. WHEN o Mestre toca "Copiar" THEN o app SHALL copiar o código para a área de transferência e mostrar o toast "Código copiado". (ROOM-06)
3. WHERE Criar sala foi aberta pelo Detalhe de uma música THEN o app SHALL mostrar essa música já escolhida, com "Trocar". (ROOM-07)
4. WHERE Criar sala foi aberta pela Biblioteca THEN o app SHALL mostrar "Escolher música", e a sala SHALL funcionar sem música. (ROOM-08)
5. WHEN o Mestre escolhe ou troca a música numa lista das músicas da biblioteca THEN o app SHALL mostrar o nome dela na linha "Música" e anunciá-lo para quem procura salas. (ROOM-09)
6. WHILE não há pedidos nem pessoas na sala THEN o app SHALL mostrar "Ninguém pediu para entrar ainda". (ROOM-10)
7. WHEN chega um pedido de entrada THEN o app SHALL listá-lo na seção "Pedindo para entrar · N" com o nome da pessoa e os botões "Recusar" e "Aprovar", cada um com rótulo de leitor de tela que inclui o nome. (ROOM-11)
8. WHEN o Mestre toca "Aprovar" THEN o app SHALL tirar a pessoa dos pedidos e, quando a conexão segura estiver pronta, mostrá-la na lista "Na sala" com o contador "N de 8 na sala". (ROOM-12)
9. WHEN o Mestre toca "Recusar" THEN o app SHALL tirar o pedido da lista e o Cantor SHALL ver "Entrada recusada". (ROOM-13)
10. WHILE 8 pessoas estão na sala THEN o app SHALL desativar "Aprovar" com a frase "Sala cheia: 8 de 8." visível e anunciada pelo leitor de tela. (ROOM-14)
11. IF um pedido expira (60 s sem resposta) ou a pessoa cancela ou perde a conexão THEN o app SHALL tirá-lo da seção de pedidos. (ROOM-15)
12. IF uma pessoa da sala perde a conexão THEN o app SHALL tirá-la da lista "Na sala" e atualizar o contador. (ROOM-16)
13. WHEN o Mestre toca "Começar a conduzir" THEN o app SHALL abrir a sala provisória do Mestre com a mesma sala, sem gerar novo código. (ROOM-17)
14. WHEN o Mestre toca "Cancelar" ou volta pelo sistema com alguém na sala ou pedindo THEN o app SHALL pedir confirmação em `ConfirmSheet` ("Encerrar sala?", "Continuar na sala" / "Encerrar sala") e, ao confirmar, encerrar a sala e voltar à Biblioteca. (ROOM-18)
15. WHEN o Mestre toca "Cancelar" ou volta pelo sistema sem ninguém na sala nem pedindo THEN o app SHALL encerrar a sala e voltar à Biblioteca sem pedir confirmação. (ROOM-19)
16. IF o anúncio da sala falha por falta de permissão de rede local THEN o app SHALL mostrar o banner de erro "Sem acesso à rede local" com "Abrir ajustes", que abre os ajustes do Cantaê no sistema. (ROOM-20)
17. IF a criação ou o anúncio da sala falha por outro motivo THEN o app SHALL mostrar o banner de erro "Não foi possível criar a sala." com "Tentar de novo", que repete a criação. (ROOM-21)

**Independent Test**: Com dois aparelhos (ou um teste ponta a ponta com transporte em memória), criar a sala, receber um pedido, aprovar e ver "1 de 8 na sala"; recusar um segundo pedido e ver o Cantor receber "Entrada recusada".

---

### P1: Entrar em sala (Cantor) ⭐ MVP

**User Story**: Como cantor, quero achar a sala do meu Mestre e pedir para entrar para ensaiar junto.

**Why P1**: RF02; estados de "Diagnóstico de rede" do PRD §12.

**Acceptance Criteria**:

1. WHEN Entrar em sala abre com nome salvo THEN o app SHALL começar a procurar salas e mostrar "Salas neste Wi‑Fi" com "Procurando salas…" enquanto nenhuma foi encontrada. (ROOM-22)
2. WHEN uma sala é encontrada THEN o app SHALL mostrar um `RoomTile` com o nome do Mestre e o nome da música ou "Sem música escolhida", sem o código. (ROOM-23)
3. IF nenhuma sala é encontrada em 10 s THEN o app SHALL mostrar o banner "Nenhuma sala neste Wi‑Fi" com "Procurar de novo", que reinicia a busca; salas encontradas depois disso SHALL aparecer na lista. (ROOM-24)
4. WHEN o cantor digita 4 dígitos no `CodeInput` e toca "Entrar" sem sala escolhida THEN o app SHALL pedir entrada às salas encontradas, uma por vez na ordem da lista, até uma não responder "código errado", e só essa SHALL ficar com o pedido. (ROOM-25)
5. IF nenhuma sala encontrada aceita o código digitado (ou a sala escolhida responde "código errado") THEN o app SHALL mostrar a borda de erro no `CodeInput`, o banner "Código não encontrado" e "Digitar de novo", que limpa o campo e devolve o foco a ele. (ROOM-26)
6. The `CodeInput` SHALL aceitar só dígitos, no máximo 4, e "Entrar" SHALL ficar desativado com menos de 4. (ROOM-27)
7. WHEN o cantor toca um `RoomTile` THEN o app SHALL marcar essa sala como escolhida (borda de 2 px `accent`), pôr o foco no `CodeInput` com a frase "Digite o código que aparece na tela de <nome do Mestre>.", e "Entrar" SHALL pedir entrada só nessa sala. (ROOM-28)
8. WHILE o pedido aguarda o Mestre THEN o app SHALL mostrar o banner "Aguardando <nome do Mestre> aprovar" com "Cancelar pedido", destacar o `RoomTile` com borda de 2 px `accent` e desativar o `CodeInput` e os outros `RoomTile`s. (ROOM-29)
9. WHEN o cantor toca "Cancelar pedido" THEN o app SHALL desistir do pedido, voltar à lista e o pedido SHALL sumir da tela do Mestre. (ROOM-30)
10. WHEN o Mestre aprova e a conexão segura fica pronta THEN o app SHALL abrir a sala provisória do Cantor. (ROOM-31)
11. WHEN o Mestre recusa THEN o app SHALL mostrar "Entrada recusada" com "Escolher outra sala", que volta à lista. (ROOM-32)
12. IF a sala está cheia THEN o app SHALL mostrar "Sala cheia (8 de 8)" com "Escolher outra sala". (ROOM-33)
13. IF o app do Mestre usa outra versão do protocolo de sala THEN o app SHALL mostrar "Versão do app incompatível", a frase "Atualize o Cantaê nos dois aparelhos." e "Escolher outra sala". (ROOM-34)
14. IF o pedido expira sem resposta do Mestre THEN o app SHALL mostrar "O Mestre não respondeu" com "Tentar de novo", que repete o pedido. (ROOM-35)
15. IF a conexão com a sala cai ou não abre enquanto o pedido está em andamento THEN o app SHALL mostrar "Não foi possível falar com a sala" com "Tentar de novo". (ROOM-36)
16. IF a busca falha e o sistema informa permissão de rede local negada (Android) THEN o app SHALL mostrar "Sem acesso à rede local" com "Abrir ajustes". (ROOM-37)
17. The app SHALL mostrar no rodapé "Você entra como Cantor." (ROOM-38)
18. WHERE o aparelho é iOS, WHEN o banner "Nenhuma sala neste Wi‑Fi" aparece THEN o app SHALL acrescentar a frase "Se você negou o acesso à rede local, libere nos ajustes." e a ação secundária "Abrir ajustes". (ROOM-57)

**Independent Test**: Teste ponta a ponta com descoberta e transporte em memória: o cantor vê a sala, digita um código errado (erro), digita o certo, aguarda, o Mestre aprova e o cantor chega à sala provisória; repetir com recusa, sala cheia e versão diferente.

---

### P1: Sala provisória ⭐ MVP

**User Story**: Como Mestre ou cantor, quero ver quem está na sala e poder sair dela enquanto as telas completas de ensaio não existem.

**Why P1**: Fecha o fluxo de entrada com um destino real (D2) e cumpre RF29 (encerrar a sala).

**Acceptance Criteria**:

1. WHEN a sala provisória do Mestre abre THEN o app SHALL mostrar o título "Sala <código>", o Mestre como "Você · Mestre" e cada pessoa aprovada como "<nome> · Cantor". (ROOM-39)
2. WHILE houver pedidos de entrada THEN a sala provisória do Mestre SHALL mostrar a seção "Pedindo para entrar · N" com "Recusar" e "Aprovar", com as mesmas regras de ROOM-11 a ROOM-15. (ROOM-40)
3. WHEN o Mestre toca "Encerrar sala" e confirma no `ConfirmSheet` THEN o app SHALL encerrar a sala, desconectar todos, parar o anúncio e voltar à Biblioteca. (ROOM-41)
4. WHEN a sala provisória do Cantor abre THEN o app SHALL mostrar "Você está na sala de <nome do Mestre>", a música anunciada (ou "Sem música escolhida") e o aviso "O ensaio começa quando o Mestre conduzir." (ROOM-42)
5. WHEN o cantor toca "Sair da sala" THEN o app SHALL fechar a conexão, voltar à Biblioteca e a pessoa SHALL sumir da lista do Mestre. (ROOM-43)
6. IF a sala é encerrada pelo Mestre ou a conexão cai THEN a sala provisória do Cantor SHALL voltar à Biblioteca e mostrar o toast "A sala foi encerrada ou a conexão caiu." (ROOM-44)
7. WHEN o Mestre volta pelo sistema na sala provisória THEN o app SHALL agir como "Encerrar sala" (ROOM-18/ROOM-19). (ROOM-45)

**Independent Test**: Com uma sala com 2 cantores, o Mestre encerra e ambos voltam à Biblioteca com o toast; noutra rodada, um cantor sai e some da lista do Mestre.

---

### P1: Base comum da sala ⭐ MVP

**User Story**: Como pessoa do coral, quero que entrar numa sala funcione no meu celular e respeite as regras de segurança do app.

**Why P1**: Sem permissões declaradas a sala não funciona num app de release; sem as regras de segurança, o código de 4 dígitos viraria senha (RNF-SEC-02).

**Acceptance Criteria**:

1. The app SHALL só colocar uma pessoa na lista "Na sala" depois de o Mestre tocar "Aprovar"; o código de 4 dígitos nunca admite ninguém sozinho. (ROOM-46)
2. The app SHALL manter no máximo uma sala ativa por aparelho, como Mestre ou como Cantor. (ROOM-47)
3. The app SHALL identificar o aparelho na sala por um identificador gerado na instalação e mantido entre aberturas do app, e o nome da pessoa SHALL viajar só como texto exibido, nunca como identidade. (ROOM-48)
4. The app SHALL declarar as permissões de rede local das plataformas: no Android, acesso à rede e multicast; no iOS, `NSLocalNetworkUsageDescription` (em pt-BR) e `NSBonjourServices` com `_cantae._tcp`. (ROOM-49)
5. The app SHALL manter o bloqueio de multicast do Android só enquanto procura ou anuncia salas e liberá-lo ao sair dessas telas. (ROOM-50)
6. The telas desta feature SHALL usar só tokens de tema, funcionar nos temas claro e escuro, ter alvos de toque ≥ 44 dp, caber em 360 dp com fonte a 130 % e anunciar cada banner de estado como região viva. (ROOM-51)
7. The textos desta feature SHALL estar em pt-BR, sem termos técnicos (mDNS, handshake, sessionId, protocolo). (ROOM-52)

**Independent Test**: Teste de widget em 360 dp e fonte 130 % nos dois temas; revisão dos manifests; teste ponta a ponta mostrando que um pedido com código certo fica pendente até "Aprovar".

---

## Edge Cases

- IF dois pedidos chegam ao mesmo tempo THEN o app SHALL listar os dois, cada um com seus botões. (ROOM-53)
- IF o Mestre toca "Aprovar" quando a 8ª vaga já foi ocupada por outro pedido THEN o app SHALL manter o pedido na lista com "Aprovar" desativado e a frase "Sala cheia: 8 de 8." (ROOM-54)
- IF o cantor toca "Entrar" ou um `RoomTile` de novo durante um pedido em andamento THEN o app SHALL ignorar o toque (os controles já estão desativados). (ROOM-55)
- WHEN a mesma sala é encontrada mais de uma vez THEN o app SHALL mostrar um único `RoomTile` para ela. (ROOM-56)
- IF o app do Cantor fecha durante o pedido THEN o Mestre SHALL ver o pedido sumir (ROOM-15).
- IF duas salas usam o mesmo código THEN o pedido digitado sem sala escolhida SHALL ir só para a primeira da lista que aceitar, e o banner "Aguardando <nome do Mestre> aprovar" SHALL nomear o Mestre dela, para o cantor cancelar se não for o seu. (ROOM-58)

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| ROOM-01 | P1: Nome na sala | Design | Pending |
| ROOM-02 | P1: Nome na sala | Execute | Implementing |
| ROOM-03 | P1: Nome na sala | Design | Pending |
| ROOM-04 | P1: Nome na sala | Design | Pending |
| ROOM-05 | P1: Criar sala | Execute | Implementing |
| ROOM-06 | P1: Criar sala | Design | Pending |
| ROOM-07 | P1: Criar sala | Design | Pending |
| ROOM-08 | P1: Criar sala | Design | Pending |
| ROOM-09 | P1: Criar sala | Execute | Implementing |
| ROOM-10 | P1: Criar sala | Design | Pending |
| ROOM-11 | P1: Criar sala | Execute | Implementing |
| ROOM-12 | P1: Criar sala | Design | Pending |
| ROOM-13 | P1: Criar sala | Execute | Implementing |
| ROOM-14 | P1: Criar sala | Design | Pending |
| ROOM-15 | P1: Criar sala | Execute | Implementing |
| ROOM-16 | P1: Criar sala | Design | Pending |
| ROOM-17 | P1: Criar sala | Design | Pending |
| ROOM-18 | P1: Criar sala | Design | Pending |
| ROOM-19 | P1: Criar sala | Design | Pending |
| ROOM-20 | P1: Criar sala | Execute | Implementing |
| ROOM-21 | P1: Criar sala | Execute | Implementing |
| ROOM-22 | P1: Entrar em sala | Design | Pending |
| ROOM-23 | P1: Entrar em sala | Execute | Implementing |
| ROOM-24 | P1: Entrar em sala | Design | Pending |
| ROOM-25 | P1: Entrar em sala | Design | Pending |
| ROOM-26 | P1: Entrar em sala | Design | Pending |
| ROOM-27 | P1: Entrar em sala | Design | Pending |
| ROOM-28 | P1: Entrar em sala | Design | Pending |
| ROOM-29 | P1: Entrar em sala | Design | Pending |
| ROOM-30 | P1: Entrar em sala | Design | Pending |
| ROOM-31 | P1: Entrar em sala | Design | Pending |
| ROOM-32 | P1: Entrar em sala | Design | Pending |
| ROOM-33 | P1: Entrar em sala | Design | Pending |
| ROOM-34 | P1: Entrar em sala | Execute | Implementing |
| ROOM-35 | P1: Entrar em sala | Execute | Implementing |
| ROOM-36 | P1: Entrar em sala | Execute | Implementing |
| ROOM-37 | P1: Entrar em sala | Design | Pending |
| ROOM-38 | P1: Entrar em sala | Design | Pending |
| ROOM-39 | P1: Sala provisória | Design | Pending |
| ROOM-40 | P1: Sala provisória | Design | Pending |
| ROOM-41 | P1: Sala provisória | Design | Pending |
| ROOM-42 | P1: Sala provisória | Design | Pending |
| ROOM-43 | P1: Sala provisória | Design | Pending |
| ROOM-44 | P1: Sala provisória | Design | Pending |
| ROOM-45 | P1: Sala provisória | Design | Pending |
| ROOM-46 | P1: Base comum da sala | Execute | Implementing |
| ROOM-47 | P1: Base comum da sala | Design | Pending |
| ROOM-48 | P1: Base comum da sala | Execute | Implementing |
| ROOM-49 | P1: Base comum da sala | Design | Pending |
| ROOM-50 | P1: Base comum da sala | Design | Pending |
| ROOM-51 | P1: Base comum da sala | Design | Pending |
| ROOM-52 | P1: Base comum da sala | Design | Pending |
| ROOM-53 | Edge cases | Design | Pending |
| ROOM-54 | Edge cases | Design | Pending |
| ROOM-55 | Edge cases | Design | Pending |
| ROOM-56 | Edge cases | Design | Pending |
| ROOM-57 | P1: Entrar em sala | Design | Pending |
| ROOM-58 | Edge cases | Design | Pending |

**Coverage:** 58 total, 0 mapped to tasks, 58 unmapped ⚠️ (tasks not written yet)

---

## Implicit-requirement sweep

| Dimension | Coverage |
| --- | --- |
| Input validation & bounds | Nome 1–40 (ROOM-02); código só dígitos, 4 (ROOM-27); limite de 8 (ROOM-14, ROOM-54) |
| Failure / partial-failure states | Permissão (ROOM-20, ROOM-37, ROOM-57), criação (ROOM-21), nenhuma sala (ROOM-24), código (ROOM-26), recusa (ROOM-32), cheia (ROOM-33), protocolo (ROOM-34), expirado (ROOM-35), conexão (ROOM-36, ROOM-44) |
| Idempotency / retry / duplicates | "Tentar de novo"/"Procurar de novo" (ROOM-21, 24, 35, 36); toque repetido (ROOM-55); sala duplicada (ROOM-56); código repetido entre salas (ROOM-58); pedido repetido do mesmo aparelho já é recusado pela máquina de estados (NET-18) |
| Auth boundaries & rate limits | Aprovação obrigatória (ROOM-46); só o Mestre aprova (existente, PRD §6.3); rate limit N/A porque o Mestre aprova um a um e pedidos expiram em 60 s |
| Concurrency / ordering | Pedidos simultâneos (ROOM-53); corrida pela 8ª vaga (ROOM-54); uma sala por aparelho (ROOM-47) |
| Data lifecycle / expiry | Pedido expira em 60 s (ROOM-15, ROOM-35); sala some ao encerrar (ROOM-41); TTL de 30 min já existente (RNF-CONF-05), N/A de nova regra; nome guardado até apagar dados (ROOM-03) |
| Observability | N/A porque esta feature não cria mensagens novas de autoridade; descartes já são registrados pela camada de sessão |
| External-dependency failure | mDNS/Bonjour e permissões (ROOM-20, 21, 37); multicast lock (ROOM-50) |
| State-transition integrity | Pedido: procurando → aguardando → (aprovado → sala | recusado | cheia | protocolo | expirado | conexão) (ROOM-29..36); Mestre: gerando → aguardando → conduzindo → encerrada (ROOM-05, 17, 41) |

---

## Success Criteria

- [ ] Num teste ponta a ponta com descoberta e transporte em memória, um cantor entra numa sala em ≤ 4 toques depois de abrir Entrar em sala (tocar a sala → aprovação → sala provisória).
- [ ] Cada um dos 9 estados de entrada de ROOM-22..37 tem um teste de widget com o texto e a ação esperados.
- [ ] Um pedido com o código certo nunca aparece em "Na sala" sem "Aprovar" (teste ponta a ponta).
