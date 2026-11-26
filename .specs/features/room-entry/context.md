# Criar sala + Entrar em sala — Decisões da discussão

Data: 2026-11-26. Respostas do usuário às áreas cinzentas levantadas na especificação.

| # | Área cinzenta | Decisão | Consequência na spec |
|---|---|---|---|
| D1 | Nome da pessoa na sala (não existe Perfil/Onboarding) | Pedir na primeira vez que a pessoa criar ou entrar em sala; salvar no aparelho | História P1 "Nome na sala" (ROOM-01..04). O Perfil futuro reaproveita o mesmo nome. |
| D2 | Destino de "Começar a conduzir" e da aprovação, antes da Sala do Mestre / Tela do Cantor | Tela provisória da sala | História P1 "Sala provisória" (ROOM-30..36). A feature seguinte a substitui. |
| D3 | Papel Visitante (RF33, Should) | Deixar para a feature do Visitante | Todos entram como Cantor. "Sala cheia" não oferece "Entrar como visitante". |
| D4 | Música obrigatória para criar sala | Opcional | Vindo do Detalhe, já escolhida; vindo da Biblioteca, "Escolher música". |

Decisões tomadas por precedência de documentos (PRD > UI_SPEC), sem pergunta:

| Conflito | Fonte vencedora | Valor |
|---|---|---|
| Limite da sala: UI_SPEC "5/30 na sala", "Sala cheia (30 de 30)" × RF26 "8 participantes" | PRD (RF26) | 8 pessoas além do Mestre |
| Rodapé "O Mestre pode mudar seu papel" × D3 (sem troca de papel nesta feature) | Decisão D3 | Rodapé reduzido a "Você entra como Cantor." |
