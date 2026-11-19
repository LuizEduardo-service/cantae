# PRD — Cantaê (UX/UI e System Design de Telas)

> Este documento complementa `prd-cantae-refatorado.md` (requisitos e arquitetura), `prd-cantae-mvp-consolidado.md` (consolidação de escopo) e `prd-cantae-studio-corte-audio.md` (Studio). Ele não repete RF/RNF já definidos — traduz esses requisitos em telas, fluxos de navegação e estados de interface, servindo de base para a Fase 5 (Telas).

## 1. Por que este documento existe

Os PRDs existentes definem **o que** o app faz e **como** os dados e a rede funcionam. Nenhum deles define **o que a pessoa vê e toca** em cada momento. A Fase 5 do plano de construção lista apenas 6 itens de checklist sem inventário de telas, sem mapa de navegação e sem estados de erro/vazio/carregamento — e `lib/presentation/` ainda não existe no código. Este documento preenche essa lacuna antes que qualquer widget seja escrito.

## 2. Visão e papéis (resumo)

Cantaê sincroniza faixas de áudio por naipe entre dispositivos em uma sala P2P local, para ensaio coletivo com fone de ouvido. Três papéis situacionais por sessão:

| Papel | Pode controlar sala | Pode editar música | Recebe áudio automaticamente |
|---|---|---|---|
| Mestre | Sim | Sim | Sim |
| Cantor | Não | Não | Sim |
| Visitante | Não | Não | Só com aprovação explícita |

## 3. Personas e contexto de uso

As personas abaixo são guias de uso, não dados de pesquisa — marcadas como suposição (minha inferência a partir dos requisitos existentes) onde não há confirmação explícita do time.

### 3.1 O Mestre (regente/organizador do ensaio)
Está de pé ou sentado à frente do grupo, segurando o celular com uma mão enquanto a outra pode estar livre para gesticular ou apontar partitura. Precisa ver rapidamente quem está pronto, iniciar a música no momento certo e reagir a problemas de conexão sem travar o ensaio. *(Suposição: baixa tolerância a múltiplos toques para uma ação crítica — iniciar a reprodução coletiva deve ser rápido e inequívoco.)*

### 3.2 O Cantor
Está com fone de ouvido, celular na mão, estante ou bolso — olha para a tela em momentos curtos entre uma frase e outra, não o tempo todo. Precisa ajustar o próprio mix (minha voz vs. coro) sem perder a letra de vista, e identificar rapidamente se perdeu sincronismo. *(Suposição: tela é consultada "de relance"; textos e estados de áudio devem ser legíveis em 1-2 segundos de atenção.)*

### 3.3 O Visitante
Observa o ensaio sem participar ativamente do controle — pode ser alguém testando o app, um ouvinte ou um membro aguardando aprovação. Vê a letra e o estado da sala, mas não recebe áudio automaticamente. A experiência precisa deixar claro, sem frustração, por que certas ações estão bloqueadas.

## 4. Princípios de UX específicos do Cantaê

Estes princípios nascem direto dos RNF-UX já definidos nos PRDs anteriores e do contexto físico de ensaio:

1. **Ação crítica em um toque.** Iniciar, pausar, mutar e trocar de naipe não podem exigir navegação profunda — são usadas no meio do ensaio, sob pressão de tempo.
2. **Estado sempre visível, nunca só por cor.** Conexão, naipe selecionado, mudo/solo e status de preparo usam texto ou ícone além de cor (RNF-UX-05 do PRD refatorado).
3. **Falha de rede explica e orienta.** Toda tela que depende de rede tem uma variação de "conexão degradada" com ação recomendada, não apenas um erro genérico.
4. **Visitante nunca vê um botão que não pode usar sem entender por quê.** Ações bloqueadas aparecem desabilitadas com explicação, não escondidas sem contexto nem clicáveis sem efeito.
5. **Tema claro/escuro e fonte do sistema sempre respeitados** (RNF-UX-02/03).

## 5. Mapa de navegação

```text
Splash/Onboarding (1ª vez)
  -> Biblioteca (tela inicial padrão)
       -> Detalhe da música
            -> Cadastro/edição de música
                 -> Studio (corte de áudio)
                 -> Alinhamento de faixas
                 -> Letra sincronizada (editor)
            -> Modo solo (player individual)
            -> Entrar em sala (a partir desta música)
            -> Histórico da música
       -> Criar sala (como Mestre)
       -> Entrar em sala (buscar por mDNS / código)
       -> Perfil e Preferências
            -> Backup
            -> Importar/Exportar .cantae
            -> Privacidade e exclusão de dados

Sala (após handshake)
  -> Sala do Mestre        (papel: mestre)
  -> Tela do Cantor         (papel: cantor)
  -> Tela do Visitante      (papel: visitante)
       todas renderizam a mesma "Letra sincronizada" como componente compartilhado
  -> Encerramento de sala -> volta para Biblioteca
```

Regra de navegação: **Biblioteca é o hub.** Toda tela secundária tem caminho de volta para ela; nenhuma tela de sala é acessível fora de um fluxo de criar/entrar.

## 6. Inventário de telas

Cada tela lista: objetivo, estados obrigatórios, ações primárias, dados exibidos e papel(is) que a acessam. "Suposição" marca decisão minha ainda não validada com você.

### 6.1 Onboarding (primeiro uso)
- **Objetivo:** explicar que os dados ficam no dispositivo, coletar nome de exibição, oferecer naipe padrão opcional, perguntar como o nome/foto serão compartilhados em salas (conforme already definido no PRD refatorado, seção Perfil).
- **Estados:** único fluxo linear, sem erro de rede (tudo local).
- **Ações primárias:** continuar, pular foto, escolher naipe padrão (opcional).
- **Papéis:** todos, uma única vez.

### 6.2 Biblioteca
- **Objetivo:** listar músicas criadas, recebidas e usadas em sessões; ponto de entrada para tudo.
- **Estados:** vazio (nenhuma música — oferece "criar primeira música" ou "importar pacote"), carregando (lista grande), populada, filtrado sem resultado.
- **Ações primárias:** abrir música, criar música, importar `.cantae`, criar sala, entrar em sala, abrir perfil.
- **Dados exibidos:** nome, autor, completude (ícone se naipes faltando), origem (criada/recebida/participada), último ensaio.
- **Papéis:** todos.

### 6.3 Detalhe da música
- **Objetivo:** hub de uma música específica — naipes cadastrados, letra, histórico, ações de edição.
- **Estados:** música incompleta (naipes faltando, destaque visual), completa, rascunho de Studio pendente (retomar ou descartar).
- **Ações primárias:** tocar solo, editar (Studio/alinhamento/letra), criar sala a partir desta música, exportar, ver histórico, excluir.
- **Papéis:** o autor/mestre vê todas as ações; um cantor que recebeu a música via sala vê versão somente leitura + tocar solo.

### 6.4 Studio — corte de áudio
- Já especificado em detalhe no `prd-cantae-studio-corte-audio.md` (seção "Interface proposta"). Este documento apenas a referencia como parte do fluxo de edição de música, acessível a partir do Detalhe da música. Sem alterações aqui.

### 6.5 Alinhamento de faixas
- **Objetivo:** ajustar `startDelayMs` por faixa com mudo/solo/teste de loop (RF25, seção 8 do PRD refatorado).
- **Estados:** nenhuma faixa (bloqueia tela, orienta cadastrar via Studio ou upload direto), faixas carregadas, testando (player ativo), salvo.
- **Ações primárias:** mudo por faixa, solo por faixa, arrastar offset, digitar `mm:ss.s`, testar loop, salvar.
- **Dados exibidos:** waveform com deslocamento visual, offset atual por faixa.
- **Papéis:** mestre/autor.

### 6.6 Letra sincronizada — editor
- **Objetivo:** cadastrar linhas de letra com instante inicial, naipe responsável e dinâmica opcional (RF18-RF20).
- **Estados:** sem linhas (vazio), editando, pré-visualizando sincronismo contra o áudio.
- **Ações primárias:** adicionar linha, marcar tempo (ouvir e tocar "marcar agora"), associar naipe/bloco, marcar dinâmica.
- **Papéis:** mestre/autor. *(Suposição: disponível só depois do alinhamento de faixas salvo, conforme já exigido na seção 8.2 do PRD refatorado.)*

### 6.7 Criar sala
- **Objetivo:** virar Mestre de uma sessão a partir de uma música da biblioteca.
- **Estados:** gerando código/sessionId, sala aberta aguardando participantes, erro de permissão de rede local (iOS/Android).
- **Ações primárias:** copiar/mostrar código de 4 dígitos, abrir Sala do Mestre.
- **Papéis:** quem cria assume Mestre.

### 6.8 Entrar em sala
- **Objetivo:** descobrir salas via mDNS e solicitar entrada por código.
- **Estados:** buscando (lista de salas encontradas), nenhuma sala encontrada, código inválido, aguardando aprovação do mestre, rejeitado, sala cheia, protocolo incompatível, sem permissão de rede local. Esses estados já estão listados na seção "Diagnóstico de rede" do PRD refatorado — aqui eles se tornam telas/estados visuais explícitos, não apenas texto de log.
- **Ações primárias:** digitar/selecionar código, entrar como visitante (se oferecido), cancelar solicitação.
- **Papéis:** cantor ou visitante entrando.

### 6.9 Sala do Mestre
- **Objetivo:** tela de controle central durante o ensaio — aprovar participantes, escolher música, preparar/disparar reprodução, loop, metrônomo, qualidade de conexão de cada participante, transferir mestre, encerrar sala.
- **Estados:** aguardando aprovações pendentes (badge), preparando reprodução (lista de quem está pronto), em reprodução, em loop, participante com conexão degradada (destaque na lista), sala próxima do limite de 30 min de inatividade.
- **Ações primárias:** aprovar/rejeitar entrada, iniciar reprodução, ativar/encerrar loop, ligar/desligar metrônomo, transferir mestre, encerrar sala.
- **Dados exibidos:** lista de participantes com naipe, papel, status de preparo e RTT/qualidade; letra sincronizada (compartilhada); controles de loop na timeline.
- **Papéis:** mestre.

### 6.10 Tela do Cantor
- **Objetivo:** tela de uso durante o ensaio — escolher naipe, ajustar mix pessoal, acompanhar letra, ver estado da sala.
- **Estados:** aguardando mestre preparar, pronto, em reprodução, em loop, conexão degradada (própria), áudio carregado continuando após perda de rede (RNF-CONF-02 — a tela deve deixar claro que o áudio segue mesmo sem rede).
- **Ações primárias:** escolher/trocar naipe, ajustar slider "minha voz vs. coro", mutar metrônomo local (volume), sair da sala.
- **Dados exibidos:** letra sincronizada com destaque na linha atual e no naipe responsável, indicador de conexão, naipe atual.
- **Papéis:** cantor.

### 6.11 Tela do Visitante
- **Objetivo:** acompanhar sem controlar.
- **Estados:** aguardando aprovação de áudio, assistindo sem áudio (padrão), áudio liberado pelo mestre.
- **Ações primárias:** solicitar áudio (se já não solicitado), sair.
- **Dados exibidos:** letra sincronizada, estado geral da sala (música atual, se está tocando) — sem controles de naipe/mix.
- **Papéis:** visitante. Visualmente esta tela deve deixar claro, sem ambiguidade, por que não há controles (texto fixo curto, não apenas ausência de botão).

### 6.12 Modo solo (player individual)
- **Objetivo:** tocar uma música sem sala, com todos os naipes e metrônomo individual.
- **Estados:** sem rede (funciona igual — é 100% local), tocando, em loop.
- **Ações primárias:** mix por naipe, loop, metrônomo próprio, mutar/isolar naipe.
- **Papéis:** todos (dono da biblioteca local).

### 6.13 Perfil e Preferências
- **Objetivo:** editar nome/foto, naipe padrão, preferências de áudio/tema/ensaio, e compartilhamento de identidade em salas.
- **Estados:** padrão; sem estados de erro de rede (tudo local).
- **Ações primárias:** editar nome, trocar foto, naipe padrão, tema claro/escuro/sistema, toggles de compartilhamento de nome/foto em sala.
- **Papéis:** todos.

### 6.14 Backup local
- **Objetivo:** cadastrar destino confiável (PC/NAS), ver status do último backup, ativar/pausar automático.
- **Estados:** nenhum destino cadastrado, destino cadastrado sem backup ainda, backup em andamento, sucesso, falha (com motivo), rede não é Wi-Fi/confiável (backup automático bloqueado, mensagem explicativa).
- **Ações primárias:** cadastrar destino, backup manual, pausar automático, revogar destino.
- **Papéis:** mestre/autor (quem administra a biblioteca local).

### 6.15 Importar/Exportar `.cantae`
- **Objetivo:** exportar música como pacote; importar pacote validando manifesto e hash.
- **Estados:** exportando, pacote inválido (hash/manifesto falhou — bloqueia import), conflito de música existente (manter ambas / ignorar / substituir — exige confirmação explícita).
- **Ações primárias:** exportar música, selecionar arquivo `.cantae`, resolver conflito.
- **Papéis:** todos.

### 6.16 Histórico de ensaios
- **Objetivo:** mostrar resumo local de ensaios por música (duração, modo, papel, loops).
- **Estados:** vazio (nenhum ensaio registrado ainda), populado.
- **Ações primárias:** apagar histórico de uma música, apagar todo o histórico.
- **Papéis:** todos (histórico é por dispositivo/pessoa local).

### 6.17 Privacidade e exclusão de dados
- **Objetivo:** visualizar uso de armazenamento por categoria, exportar dados pessoais, apagar perfil e todos os dados locais.
- **Estados:** padrão, confirmação reforçada antes de apagar tudo (ação destrutiva e irreversível).
- **Ações primárias:** exportar dados, apagar tudo (com confirmação em duas etapas).
- **Papéis:** todos.

## 7. Padrões de estado reutilizáveis

Para manter consistência (e reduzir retrabalho de widgets), três estados se repetem em quase toda tela com dados:

| Padrão | Quando aparece | Regra de UI |
|---|---|---|
| Vazio | Nenhum dado ainda (biblioteca, histórico, backup) | Mensagem curta + uma ação clara para resolver, nunca tela em branco sem explicação |
| Degradado/erro de conexão | Qualquer tela dependente de rede em sala | Texto + ícone, nunca só cor; ação recomendada visível (ex.: "aproxime do roteador") |
| Confirmação de ação destrutiva/irreversível | Excluir dados, substituir faixa, sobrescrever música, apagar histórico | Sempre uma etapa de confirmação explícita; nunca ocorre em silêncio |

## 8. Diretrizes visuais (herdadas dos RNF já aprovados)

- Tema claro e escuro, contraste mínimo WCAG AA (RNF-UX-02 / RNF-UX-01).
- Área de toque mínima 44x44dp em qualquer elemento interativo (RNF-UX-04).
- Texto respeita escala de fonte do sistema (RNF-UX-03).
- Estado nunca depende só de cor (RNF-UX-05).
- Layout pensado para celular primeiro; tablet é melhoria da Fase 5, não bloqueador.

## 9. O que falta decidir (próximos passos)

- **Wireframes de baixa fidelidade** por tela listada na seção 6 — próximo passo natural após aprovação deste documento.
- **Sistema de design (tokens):** paleta, tipografia e espaçamento ainda não definidos — sugiro usar a skill `flutter-ui-ux` deste projeto como guia ao implementar cada tela.
- **Validação das personas da seção 3** com você ou com um ensaio real, já que estão marcadas como suposição.
- Decidir se a Tela do Visitante e a Tela do Cantor compartilham o mesmo widget-base (parecem ter ~70% de UI em comum) ou são implementações separadas — decisão de implementação, não de produto.
