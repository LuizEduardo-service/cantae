# AGENTS.md — Cantaê

Instruções para agentes de IA (e pessoas) que trabalham neste repositório, em especial na camada de interface.

## 1. Contexto do produto

Cantaê sincroniza faixas de áudio **por naipe** (Soprano, Contralto, Tenor, Baixo) entre celulares numa **sala P2P local**, para ensaio coletivo de coral com fone de ouvido. Tudo é local: não há servidor nem conta na nuvem.

Papéis por sessão:
- **Mestre** — controla a sala, aprova entradas, inicia/pausa para todos, loop, metrônomo.
- **Cantor** — escolhe o próprio naipe e o mix "minha voz × coro".
- **Visitante** — acompanha a letra; recebe áudio só se o Mestre liberar.

## 2. Ordem de leitura antes de mexer em UI

1. `docs/prd-cantae-refatorado.md` — requisitos (RF/RNF) e arquitetura.
2. `docs/prd-cantae-mvp-consolidado.md` — escopo do MVP.
3. `docs/prd-cantae-ux-telas.md` — personas, mapa de navegação, inventário de telas.
4. `docs/design/DESIGN_SYSTEM.md` — tokens (cor, tipografia, espaço, raio).
5. `docs/design/UI_GUIDELINES.md` — regras de construção e comportamento.
6. `docs/design/COMPONENTS.md` — componentes reutilizáveis.
7. `docs/design/UI_SPEC.md` — especificação de cada tela e seus estados.

Se houver conflito: **PRD de requisitos > UI_SPEC > UI_GUIDELINES > DESIGN_SYSTEM > este arquivo.** Se a dúvida persistir, pergunte; não invente.

## 3. Regras obrigatórias

### Visual
- **Nunca** use cor, tamanho de fonte, espaçamento ou raio literal em widget. Use os tokens (`CantaeColors`, `CantaeTypography`, constantes de espaço).
- Toda tela nova funciona **nos temas claro e escuro** sem código condicional no widget.
- Fonte **Geist** para UI e letra; **Geist Mono** para todo número (tempo, código, atraso, latência, MB).
- Uma única ação primária (verde, `accent`) por tela.
- **Proibido:** gradientes, brilhos, neon, roxo/ciano decorativo, ícone de estrelinha/sparkles, emoji na UI, sombras pesadas, grades de cards idênticos com ícone centralizado.

### Comportamento
- Ações críticas de ensaio (iniciar, pausar, mutar, trocar naipe) em **um toque**.
- Toda interação tem feedback visual imediato; mudança com efeito fora da tela mostra **toast**.
- Toda tela com dados implementa: vazio, carregando, erro e, se depende de rede, degradado. Ver `UI_SPEC.md`.
- Ação destrutiva ou irreversível usa `ConfirmSheet`. Apagar todos os dados exige duas etapas e confirmação digitada.
- O Visitante nunca vê um controle que não pode usar sem uma frase explicando por quê.

### Acessibilidade
- Área de toque ≥ 44×44 dp.
- Contraste WCAG AA nos dois temas.
- Semântica correta (button, tab, radio, switch, região viva para status).
- Respeitar escala de fonte do sistema e "reduzir movimento".
- Nenhuma informação transmitida só por cor (naipe = cor + letra/nome).

### Texto
- Português do Brasil, frases curtas, "você".
- Rótulos de botão = verbo + objeto ("Criar sala", "Salvar atrasos").
- Sem jargão técnico na UI (mDNS, RTT, hash, sessionId).
- Sem clichês de marketing ("potencialize", "desbloqueie", "inteligente") e sem nomes de teste (Jane Doe, Acme). Use dados plausíveis do domínio (músicas de coral em domínio público, nomes brasileiros comuns).
- Toda string vem do arquivo de localização; nada hardcoded.

## 4. Estrutura sugerida da camada de apresentação

```
lib/presentation/
  theme/        cantae_colors.dart, cantae_typography.dart, cantae_spacing.dart, voice_part_colors.dart, app_theme.dart
  widgets/      um arquivo por componente de COMPONENTS.md
  screens/
    onboarding/ library/ song_detail/ alignment/ lyrics_editor/
    room_create/ room_join/ room_master/ room_singer/ room_visitor/
    solo_player/ profile/ backup/ package_import/ history/ privacy/
```

Proposta inicial — siga o padrão de estado/injeção já usado no restante do projeto. Tela não conhece rede nem banco diretamente: consome estado exposto pela camada de aplicação.

## 5. Como implementar uma tela

1. Leia a seção da tela em `UI_SPEC.md` e liste todos os estados.
2. Monte com componentes de `COMPONENTS.md`. Se faltar um, crie-o como componente reutilizável (com teste) antes de usar.
3. Implemente cada estado, incluindo vazio, erro e degradado.
4. Verifique os dois temas e a fonte do sistema em 130%.
5. Escreva testes de widget: renderização por estado, ação primária, semântica.
6. Rode o checklist de acessibilidade de `UI_GUIDELINES.md` §11.

## 6. Ao propor mudanças

- Não adicione funcionalidades fora dos PRDs. Se achar que falta algo, registre como sugestão.
- Mudança de token ou componente compartilhado: atualize `DESIGN_SYSTEM.md` / `COMPONENTS.md` no mesmo PR.
- Nova tela ou novo estado: atualize `UI_SPEC.md` no mesmo PR.
- Descreva no PR: telas afetadas, estados cobertos, verificação nos dois temas.

## 7. Checklist antes de concluir

- [ ] Nenhum valor visual literal fora de `theme/`.
- [ ] Claro e escuro conferidos.
- [ ] Estados da `UI_SPEC.md` implementados.
- [ ] Toque ≥ 44 dp, contraste AA, semântica e leitor de tela ok.
- [ ] Textos em pt‑BR vindos da localização, sem jargão nem clichê.
- [ ] Testes de widget passando.
- [ ] Docs atualizadas se tokens, componentes ou telas mudaram.
