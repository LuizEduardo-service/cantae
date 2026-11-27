# Cantaê — Especificação de telas

> Especificação por tela, alinhada ao canvas "Cantaê — UX/UI" e às seções 5–7 do PRD de UX/UI.
> Componentes citados estão em `COMPONENTS.md`. Regras gerais em `UI_GUIDELINES.md`.
> Studio (corte de áudio) está em `prd-cantae-studio-corte-audio.md` e não é repetido aqui.

## Mapa de navegação

```
Onboarding (1ª vez)
  → Biblioteca (hub)
       → Nova música → Detalhe da música
       → Detalhe da música
            → Faixas (Enviar faixa)
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
- [P] Cadastrar primeira música (abre "Nova música", §6.4) · [S] Abrir pacote .cantae.
- Card inferior: "Tem ensaio rolando por perto?" + "Entrar em sala".

## 6.3 Detalhe da música
- **Topo:** ‹ Biblioteca · Exportar.
- **Cabeçalho:** título, "Autor · duração · origem".
- **Banner warning (condicional):** rascunho do Studio pendente → "Retomar corte" / "Descartar" (Descartar pede confirmação).
- **Naipes:** grupo com 4 linhas; faltante com selo tracejado e "Enviar faixa" (abre "Faixas" já no seletor daquele naipe, §6.4). Naipes extras aparecem abaixo, com selo neutro e a inicial.
- **Preparar:** Cortar áudio no Studio › · Alinhar entradas › · Sincronizar letra (3 de 5) › · Ensaios anteriores (7) ›.
- **Rodapé:** [S] Ensaiar só · [P] Ensaiar em grupo.
- **Papéis:** Cantor que recebeu a música vê versão somente leitura: sem "Preparar" nem "Enviar faixa"; mantém "Ensaiar só" e uma seção "Ensaios" só com "Ensaios anteriores (N)" (o histórico vale para todos os papéis, PRD UX §6.16).
- **Estados:** completa, incompleta (aviso de naipe faltando), rascunho pendente.

## 6.4 Nova música / Faixas
- **Entradas:** "Cadastrar primeira música" (Biblioteca vazia) abre "Nova música". "Enviar faixa" no Detalhe, no Modo solo e no Alinhamento abre "Faixas" da música. No Detalhe, o seletor de arquivos já abre no naipe tocado.
- **Topo:** ‹ Biblioteca (nova) ou ‹ nome da música. Título "Nova música" ou "Faixas".
- **Campos:** Nome (obrigatório, até 80) e Autor (opcional, até 80). O limite aparece no campo.
- **Naipes:** 4 linhas (Soprano, Contralto, Tenor, Baixo). Cada linha tem selo, nome e uma linha de estado:
  - "Sem faixa";
  - "Conferindo arquivo…";
  - nome do arquivo · tamanho em mono ("12,4 MB");
  - "Faixa salva", para faixas antigas sem nome de arquivo.
- **Ações por linha:** "Escolher arquivo", ou "Trocar" e "Remover". Trocar ou remover uma faixa já salva pede `ConfirmSheet`. A faixa trocada entra com atraso zero.
- **Playback:** linha "Playback (opcional)", sem selo, com as mesmas ações.
- **Naipes extras:**
  - Linhas com selo neutro e a inicial, mais "Tirar naipe".
  - [S] "Adicionar naipe" abre uma folha com "Naipes já criados" e o campo "Novo naipe" + "Criar naipe". O nome tem até 24 caracteres e não repete um naipe padrão, "Playback" ou um naipe extra já existente.
  - Com 4 extras, o botão fica desabilitado e aparece "Até 4 naipes extras por música.".
- **Rodapé:** [P] Salvar música. Fica desabilitado com nome inválido ou arquivo em conferência, e mostra andamento enquanto salva. Ao salvar, abre o Detalhe.
- **Estados:**
  - *Carregando*.
  - *Música não encontrada*: EmptyState + "Voltar à Biblioteca".
  - *Erro de leitura*: banner + "Tentar de novo".
  - *Música recebida*: só leitura, com banner explicando o motivo e sem ações nem "Salvar música".
  - *Arquivo recusado*: mensagem na linha ("Este arquivo não é um áudio aceito (MP3, M4A ou WAV).", "Arquivo maior que 100 MB.", "Não foi possível ler este arquivo.").
  - *Seletor indisponível*: banner "Não foi possível abrir os arquivos.".
  - *Falha ao salvar*: banner "Não foi possível salvar a música. Tente de novo.". As escolhas continuam na tela.
  - *Alterações não salvas*: sair pede confirmação.

## 6.5 Alinhamento de faixas
- **Topo:** ‹ nome da música. Título "Alinhar entradas" + instrução.
- **Conteúdo:** uma `TrackAlignRow` por faixa: os 4 naipes padrão na ordem e depois os naipes extras (selo neutro e nome).
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
- **Antes de tudo:** sem nome salvo, folha "Como você quer aparecer na sala?" (campo "Seu nome", 1–40 caracteres, [P] Salvar nome). Fechar a folha volta à Biblioteca.
- **Topo:** Cancelar · StatusPill `synced` "Visível neste Wi‑Fi" (sem o nome da rede: ler o nome do Wi‑Fi exige permissão de localização no Android).
- **Conteúdo:** `RoomCodeDisplay` (4827, Copiar); seção "Música": nome da música e "Trocar", ou "Nenhuma música escolhida" e "Escolher música" (folha "Música da sala" com a biblioteca e "Sem música"); seção "Pedindo para entrar · N" com `JoinRequestRow` por pessoa; seção "Na sala · N de 8" com "Você · Mestre" e quem já entrou (`RoomPersonRow`).
- **Rodapé:** [P] Começar a conduzir → sala provisória do Mestre (a Sala do Mestre completa, §6.9, chega na próxima feature). Desativado até a sala estar pronta.
- **Limite:** 8 pessoas além do Mestre (RF26; o canvas mostrava 30). Com 8, "Aprovar" fica desativado e cada pedido mostra "Sala cheia: 8 de 8."
- **Música:** opcional. Vinda do Detalhe ("Ensaiar em grupo"), já escolhida; vinda da Biblioteca, nenhuma.
- **Sair:** Cancelar ou voltar pelo sistema. Sem ninguém na sala nem pedindo, encerra direto; com alguém, `ConfirmSheet` "Encerrar sala?" ("Continuar na sala" / "Encerrar sala").
- **Estados:**
  - *Gerando código* (indicador + "Gerando código").
  - *Aguardando participantes* (sem pedidos nem pessoas: "Ninguém pediu para entrar ainda").
  - *Sem permissão de rede local* (banner error "Sem acesso à rede local" + "Abrir ajustes").
  - *Falha ao criar* (banner error "Não foi possível criar a sala." + "Tentar de novo").

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
  - Sem estados de rede. Sair da tela para o áudio e tira a notificação.
- **Segundo plano e tela bloqueada:**
  - A música continua com a tela bloqueada ou em outro app, com mix, loop e metrônomo valendo.
  - Notificação e tela bloqueada: nome da música, "Modo solo", Tocar/Pausar e a barra de posição (arrastar busca). Mesmo efeito dos controles da tela.
  - Fechar o app pela lista de recentes para o áudio.
  - Ligação ou outro app que toma o áudio: pausa tudo e não volta sozinho. Fone desconectado: pausa. Som curto de outro app: o volume abaixa e volta, sem pausar.
  - Ao voltar para a tela depois de uma pausa assim: botão "Tocar" e o toast "Música pausada: outro áudio começou" ou "Música pausada: fone desconectado" (uma vez).

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
- **Entrada:** linha "Ensaios anteriores (N)" do Detalhe da música (sem número quando não há ensaios).
- **Topo:** ‹ nome da música. Título "Ensaios" + "Registrados só neste aparelho."
- **Resumo:** 3 `StatTile` (ensaios, tempo, loops).
- **Lista:** do mais recente para o mais antigo. Cada linha: data "25 nov 2026 · 19:40"; "Modo solo · 12:30 · 8 loops" (duração em mono; "sem loops", "1 loop"). O papel aparece nos ensaios de sala, quando as salas existirem.
- **Rodapé:** [D tonal] Apagar desta música · [S] Apagar tudo, um embaixo do outro (ambos com `ConfirmSheet`; "Apagar tudo" avisa que apaga os ensaios de todas as músicas do aparelho). Sucesso: toast "Ensaios apagados".
- **Registro:** ensaio do Modo solo com pelo menos 1 minuto de música tocando, gravado ao sair do Modo solo. O tempo pausado não conta; cada volta do loop ao início do trecho conta 1.
- **Estados:**
  - vazio: "Nenhum ensaio registrado ainda" + "Ensaiar agora" (abre o Modo solo); sem rodapé;
  - carregando;
  - erro de leitura: "Não foi possível carregar os ensaios" + "Tentar de novo";
  - música não encontrada: "Voltar à Biblioteca";
  - falha ao apagar: banner "Ensaios não apagados" / "Não foi possível apagar os ensaios." e a lista continua.

## 6.17 Privacidade e exclusão
- **Topo:** ‹ Perfil. Título "Seus dados".
- **Card:** espaço usado (mono) + `StorageBar` + legenda por categoria.
- **Ações:** [S] Exportar meus dados · [D tonal] Apagar perfil e tudo deste aparelho.
- **ConfirmSheet em 2 etapas:**
  1. "Apagar tudo deste aparelho?" — consequência + sugestão de exportar → Continuar.
  2. "Última confirmação" — lista do que some, nota "Backups no NAS ficam intactos", campo "Digite APAGAR" → Apagar definitivamente (habilita só com a palavra).
