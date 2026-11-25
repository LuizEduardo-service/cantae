# Cantaê — Especificação de telas

> Especificação por tela, alinhada ao canvas "Cantaê — UX/UI" e às seções 5–7 do PRD de UX/UI.
> Componentes citados estão em `COMPONENTS.md`. Regras gerais em `UI_GUIDELINES.md`.
> Studio (corte de áudio) está em `prd-cantae-studio-corte-audio.md` e não é repetido aqui.

## Mapa de navegação

```
Onboarding (1ª vez)
  → Biblioteca (hub)
       → Detalhe da música
            → Studio · Alinhamento · Editor de letra · Histórico
            → Modo solo
            → Criar sala (a partir da música)
       → Criar sala → Sala do Mestre
       → Entrar em sala → Tela do Cantor | Tela do Visitante
       → Perfil → Backup · Importar/Exportar · Privacidade
Encerrar/Sair de sala → Biblioteca
```

Legenda: **[P]** ação primária · **[S]** secundária · **[D]** destrutiva · **Tema** = tem versão escura projetada.

---

## 6.1 Onboarding — perfil (passo 2 de 3)
- **Topo:** progresso em 3 barras + "Passo 2 de 3".
- **Conteúdo:** título "Como o grupo vai te chamar?"; card com avatar (inicial), "Escolher foto" (opcional), campo "Nome de exibição"; grade 2×2 de `ChoiceTile` para naipe padrão (opcional); frase "Tudo fica neste aparelho…".
- **Rodapé:** [S] Voltar · [P] Continuar.
- **Validação:** nome obrigatório (1–40 caracteres); Continuar desabilitado com dica se vazio.
- **Estados:** único fluxo local, sem erro de rede.

## 6.2 Biblioteca — Tema
- **Topo:** título "Biblioteca"; "Importar" (NavPill) e avatar → Perfil.
- **Conteúdo:** `SearchField`; `SegmentedControl` Todas / Criadas / Recebidas; contagem ("5 músicas") + ordenação; lista de `SongRow`. O último ensaio aparece destacado.
- **Rodapé:** [S] Entrar em sala · [P] Criar sala.
- **Estados:**
  - *Populada* (padrão).
  - *Vazia* (ver 6.2b).
  - *Carregando* — esqueleto de 5 linhas.
  - *Filtro sem resultado* — "Nada encontrado para “…”" + "Limpar busca".
- **Feedback:** filtro aplica na hora; tocar em música abre o Detalhe.

## 6.2b Biblioteca vazia
- `EmptyState`: "Nenhuma música ainda" + frase.
- [P] Cadastrar primeira música · [S] Abrir pacote .cantae.
- Card inferior: "Tem ensaio rolando por perto?" + "Entrar em sala".

## 6.3 Detalhe da música
- **Topo:** ‹ Biblioteca · Exportar.
- **Cabeçalho:** título, "Autor · duração · origem".
- **Banner warning (condicional):** rascunho do Studio pendente → "Retomar corte" / "Descartar" (Descartar pede confirmação).
- **Naipes:** grupo com 4 linhas; faltante com selo tracejado e "Enviar faixa".
- **Preparar:** Cortar áudio no Studio › · Alinhar entradas › · Sincronizar letra (3 de 5) › · Ensaios anteriores (7) ›.
- **Rodapé:** [S] Ensaiar só · [P] Ensaiar em grupo.
- **Papéis:** Cantor que recebeu a música vê versão somente leitura: sem "Preparar" nem "Enviar faixa"; mantém "Ensaiar só".
- **Estados:** completa, incompleta (aviso de naipe faltando), rascunho pendente.

## 6.5 Alinhamento de faixas
- **Topo:** ‹ nome da música. Título "Alinhar entradas" + instrução.
- **Conteúdo:** 4 `TrackAlignRow`.
- **Rodapé:** [S] Ouvir em loop · [P] Salvar atrasos (toast "Atrasos salvos").
- **Estados:**
  - *Sem faixas*: EmptyState que leva ao Studio ou ao upload.
  - *Testando*: player ativo, botão vira "Parar".
  - *Alterações não salvas*: sair pede confirmação.

## 6.6 Editor de letra
- **Pré‑condição:** ao menos uma faixa cadastrada; caso contrário, banner warning "Sem faixas para ouvir" com ação "Alinhar faixas" e "Ouvir com a letra" desabilitado. Digitar, editar e salvar a letra continuam liberados.
- **Topo:** Voltar · "Ouvir com a letra" (vira "Parar de ouvir" no modo de marcação). Título "Letra" + "3 de 5 marcadas" (números em mono, região viva).
- **Conteúdo:** grupo de `LyricLineRow`: tempo (mono, "—" se não marcado), texto, selo do naipe + "Naipe · dinâmica", "Editar" (expande na própria linha). A linha atual aparece destacada. "+ Acrescentar linha".
- **Rodapé (editando):** [P] Salvar letra.
- **Rodapé (marcando):** card "Próxima: … 0:21.8" (ou "Todas as linhas marcadas") · [P] Marcar agora · [S] Pausar/Continuar · [S] Salvar letra. Marcação fora de ordem mostra banner "Marcação recusada".
- **Estados:** carregando, não encontrada, erro ao abrir (banner + "Tentar de novo"), vazio (sem linhas, sem rodapé; ação "Acrescentar linha"), editando, marcando (tocando), marcando (pausado: "Continuar" retoma de onde parou, "Marcar agora" desabilitado), erro ao tocar as faixas (banner, edição continua), erro ao salvar (banner, alterações mantidas). Sair com alterações não salvas abre `ConfirmSheet`; sair para o áudio.

## 6.7 Criar sala
- **Topo:** Cancelar · StatusPill "Visível no Coral‑WiFi".
- **Conteúdo:** `RoomCodeDisplay` (4827, Copiar); linha "Música · Trocar"; seção "Pedindo para entrar · N" com Recusar/Aprovar por pessoa e "5/30 na sala"; lista de quem já entrou.
- **Rodapé:** [P] Começar a conduzir → Sala do Mestre.
- **Estados:**
  - *Gerando código*.
  - *Aguardando participantes* (sem pedidos: "Ninguém pediu para entrar ainda").
  - *Sem permissão de rede local* (banner error + "Abrir ajustes").

## 6.8 Entrar em sala
- **Topo:** ‹ Biblioteca. Título "Entrar em sala".
- **Conteúdo:** card com `CodeInput` + [P] Entrar; "Salas neste Wi‑Fi" com `RoomTile`s; banner de estado.
- **Rodapé:** "Você entra como Cantor. O Mestre pode mudar seu papel."
- **Estados (banner):**

| Estado | Título | Ação |
|---|---|---|
| buscando | — (lista + "procurando…") | — |
| nenhuma | Nenhuma sala neste Wi‑Fi | Procurar de novo |
| aguardando | Aguardando a Marina aprovar | Cancelar pedido |
| rejeitado | Entrada recusada | Escolher outra sala |
| cheia | Sala cheia (30 de 30) | Entrar como visitante |
| protocolo | Versão do app incompatível | Atualizar o app |
| permissão | Sem acesso à rede local | Abrir ajustes |
| código inválido | Código não encontrado (borda de erro no campo) | Digitar de novo |

## 6.9 Sala do Mestre — Tema
- **Topo:** "Sala 4827" · botão "N pedidos para entrar" (abre a lista de aprovação).
- **Cabeçalho:** nome da música + resumo ("4 de 5 prontos · Pedro ainda carregando" / "Tocando · 0:52 de 2:58").
- **Participantes:** `ParticipantRow` × N com papel, estado e latência.
- **Banner warning:** participante com conexão fraca + orientação.
- **Rodapé:** linha de controles (Marcar loop / Loop 0:41–1:12 · Metrônomo · Passar mestre) · [D tonal] Encerrar · [P] Iniciar para todos / Pausar para todos.
- **Estados:** preparando, tocando, em loop, pedidos pendentes, participante degradado, perto do limite de 30 min de inatividade (banner "A sala fecha em 5 min sem atividade" + "Manter aberta").
- **Confirmações:** Encerrar (ConfirmSheet: "Encerrar a sala? Todos saem e o áudio para."), Passar mestre (escolher pessoa + confirmar).

## 6.10 Tela do Cantor — Tema
- **Topo:** Sair (abre ConfirmSheet) · StatusPill Sincronizado / Conexão fraca / Sem rede.
- **Cabeçalho:** nome da música; `PlaybackProgress`; "Repetindo trecho … · Mestre: Marina".
- **Naipe:** `SegmentedControl` Soprano / Contralto / Tenor / Baixo (toast ao trocar).
- **Letra:** `LyricView` com "Próxima é sua" quando aplicável.
- **Painel inferior:** `MixSlider`; Metrônomo (volume local); Silenciar (toggle com toast).
- **Estados:** aguardando o Mestre preparar, pronto, tocando, em loop, conexão fraca, **sem rede com áudio continuando** (ver 6.10b).

## 6.10b Cantor — sem rede (escuro)
- StatusPill "× Sem rede".
- Card: "Seu áudio continua tocando" + "A faixa já está no aparelho. Pausas e loops do Mestre chegam quando a rede voltar." + "Reconectando… tentativa 3".
- Painel inferior com o mix e [P] Reconectar agora.

## 6.11 Tela do Visitante — Tema
- **Topo:** Sair · StatusPill "Visitante".
- **Cabeçalho:** nome da música, "Sala de Marina · tocando 0:52".
- **Card de áudio (estado):**
  - *Sem áudio*: "Você está sem áudio" + [P] Pedir áudio.
  - *Aguardando*: "Pedido enviado" + Cancelar pedido.
  - *Liberado*: success "Áudio liberado".
- **Letra:** `LyricView` (sem destaque "sua vez").
- **Rodapé:** frase fixa explicando por que não há controles.

## 6.12 Modo solo — Tema
- **Topo:** ‹ Voltar (→ Detalhe da música) · `StatusPill` neutro "Funciona offline". O texto não diz "Sozinha", para não supor o gênero de quem usa.
- **Conteúdo:**
  - título (nome da música) e autor;
  - letra compacta (`LyricView`: passada, atual, "Próxima"), ou "Esta música ainda não tem letra sincronizada";
  - "Mix por naipe": um `MixTrackRow` por faixa, incluindo o Playback, com volume, M e S. Com o metrônomo ligado, também uma linha "Metrônomo" com volume e M, sem S.
  - Em música criada por você e com andamento: "72 BPM · 4 tempos" + `TonalButton` "Ajustar andamento" (abre a `TempoSheet`).
- **Rodapé:** `PlaybackProgress` (arrastar busca ao soltar); linha 1: loop (tonal) · metrônomo (tonal); linha 2: [P] Tocar/Pausar. São duas linhas para as três ações caberem em 360 dp com a fonte a 130 %.
  - **Loop:** "Marcar início do loop" → "Marcar fim do loop" → "Desligar loop" (positivo), com a legenda "Repetindo trecho 0:41–1:12". Marcar só funciona tocando. Um fim antes do início mostra o banner "Trecho recusado".
  - **Metrônomo:**
    - **com andamento:** "Metrônomo ♩ 72" liga e desliga (positivo quando ligado). O clique segue tocar, pausar, arrastar e o loop, e continua soando quando uma voz é isolada.
    - **sem andamento, música criada:** "Metrônomo" abre a `TempoSheet` "Andamento". Salvar grava na música, liga o metrônomo e mostra o toast "Andamento salvo".
    - **música recebida sem andamento:** botão desabilitado, com a frase "Música recebida: só quem criou pode definir o andamento."
    - **música recebida com andamento:** liga e desliga, mas não ajusta.
    - **falha ao preparar o clique:** banner "Metrônomo desligado", com "Não foi possível preparar o metrônomo."
    - **"ligar ao abrir":** com essa opção salva no andamento, a tela abre com o metrônomo ligado.
- **Estados:**
  - tocando, pausado, em loop e fim da música (o próximo "Tocar" recomeça do zero);
  - carregando;
  - não encontrada ("Voltar à Biblioteca");
  - erro de leitura ("Tentar de novo");
  - sem faixas (EmptyState "Esta música ainda não tem faixas" + "Enviar faixa");
  - falha ao carregar o áudio ("Tentar de novo").
  - Sem estados de rede. Sair da tela para o áudio; ainda não toca em segundo plano.

## 6.13 Perfil e Preferências — Tema
- **Topo:** ‹ Biblioteca.
- **Card de perfil:** avatar, nome, naipe padrão, Editar.
- **Aparência:** `SegmentedControl` Claro / Escuro / Sistema, com aplicação imediata + toast; frase de ajuda por opção.
- **Nas salas, mostrar:** switches Meu nome / Minha foto (toast ao mudar).
- **Seus dados:** Backup local (último backup), Importar e exportar, Privacidade e exclusão (uso em MB).

## 6.14 Backup local
- **Topo:** ‹ Perfil. Título + frase "Nada sai para a internet".
- **Card de status:**

| Estado | Variante | Título | Botão do rodapé |
|---|---|---|---|
| sucesso | success | Tudo copiado e conferido | [P] Fazer backup agora |
| em andamento | info + progresso | nome da música em cópia, 3 de 6 | [S] Cancelar backup |
| falha | error | O NAS ficou sem espaço | [P] Tentar de novo |
| rede não confiável | warning | Você está em Café‑Guest | desabilitado: "Disponível no Wi‑Fi do coral" |
| sem destino | EmptyState | Nenhum destino cadastrado | [P] Cadastrar destino |

- **Grupo:** destino (nome + IP em mono + Revogar com confirmação) · switch Backup automático.

## 6.15 Importar `.cantae` — conflito
- **Folha inferior** sobre scrim.
- Nome do arquivo (mono) + selo "✓ Pacote íntegro".
- Título "Você já tem esta música" + comparação lado a lado (Sua versão / Do pacote).
- `ChoiceTile`s: Manter as duas · Ignorar o pacote · **Substituir a minha** (vermelho).
- Aviso de perda aparece ao escolher Substituir.
- Rodapé: [S] Cancelar · botão de confirmação que muda de texto e cor conforme a opção.
- **Outros estados:** exportando (progresso), pacote inválido (error, bloqueia importação: "Este pacote está corrompido ou foi alterado").

## 6.16 Histórico de ensaios
- **Topo:** ‹ nome da música. Título "Ensaios" + "Registrados só neste aparelho."
- **Resumo:** 3 `StatTile` (ensaios, tempo, loops).
- **Lista:** data · modo, papel, duração (mono), loops.
- **Rodapé:** [D tonal] Apagar desta música · [S] Apagar tudo (ambos com confirmação).
- **Vazio:** "Nenhum ensaio registrado ainda" + "Ensaiar agora".

## 6.17 Privacidade e exclusão
- **Topo:** ‹ Perfil. Título "Seus dados".
- **Card:** espaço usado (mono) + `StorageBar` + legenda por categoria.
- **Ações:** [S] Exportar meus dados · [D tonal] Apagar perfil e tudo deste aparelho.
- **ConfirmSheet em 2 etapas:**
  1. "Apagar tudo deste aparelho?" — consequência + sugestão de exportar → Continuar.
  2. "Última confirmação" — lista do que some, nota "Backups no NAS ficam intactos", campo "Digite APAGAR" → Apagar definitivamente (habilita só com a palavra).
