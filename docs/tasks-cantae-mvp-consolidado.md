# PRD — Cantaê (MVP consolidado)



## Tasks detalhadas

Cada task possui resultado esperado e critério objetivo de conclusão. A ordem respeita dependências: não iniciar uma fase sem os testes e artefatos mínimos da anterior.

### Fase 0 — Fundação e qualidade

- [ ] **T0.1 — Validar estrutura Clean Architecture.** Criar/verificar módulos `presentation`, `domain`, `data` e `infrastructure`; garantir que `domain` não importa Flutter, plugins ou bibliotecas de banco/rede. **Concluído quando:** análise estática e teste de arquitetura impedem dependências proibidas.
- [ ] **T0.2 — Configurar CI.** Executar formatação, análise estática, testes unitários, testes de integração e varredura de dependências em cada pull request. **Concluído quando:** pipeline falha em código não formatado, teste quebrado, complexidade acima do limite ou dependência vulnerável conhecida.
- [ ] **T0.3 — Configurar gestão de segredos.** Criar `.gitignore`, scanner de segredos e checklist de revisão. **Concluído quando:** nenhum token, chave, arquivo de backup ou base local entra no repositório.
- [ ] **T0.4 — Padronizar falhas de domínio.** Definir `Result<Success, Failure>` ou equivalente, catálogo de erros e mapeamento para UI. **Concluído quando:** nenhuma exceção crua de domínio aparece para o usuário.
- [ ] **T0.5 — Criar fixtures de teste.** Incluir música pequena com quatro faixas, música incompleta, faixas com atrasos distintos, letra e arquivo inválido. **Concluído quando:** fixtures são reutilizadas nos testes de domínio, persistência e integração.

### Fase 1 — Domínio musical e áudio

- [ ] **T1.1 — Implementar entidades musicais.** Criar `Song`, `SongTrack`, `Naipe`, `LyricLine`, `MetronomeConfig` e regras de validação. **Concluído quando:** entidades rejeitam IDs ausentes, BPM inválido, duração negativa e referências de naipe inexistentes.
- [ ] **T1.2 — Implementar completude de música.** Calcular se todos os naipes padrão possuem faixa e ignorar Playback no cálculo. **Concluído quando:** testes cobrem música completa, incompleta, customizada e com Playback.
- [ ] **T1.3 — Implementar `AudioMixCalculator`.** Calcular ganhos por faixa para próprio naipe, coro e Playback. **Concluído quando:** troca de naipe e ajuste do slider produzem ganhos previsíveis e limitados.
- [ ] **T1.4 — Implementar timeline compartilhada.** Definir conversão entre posição da timeline e posição por faixa usando `startDelayMs`. **Concluído quando:** testes comprovam que letras, loops e metrônomo usam a mesma referência temporal.
- [ ] **T1.5 — Implementar alinhamento de faixas.** Validar `startDelayMs`, salvar rascunho de ajuste e aplicar no cálculo de reprodução. **Concluído quando:** uma faixa atrasada mantém sua entrada musical no instante correto sem cortar o arquivo-fonte.
- [ ] **T1.6 — Implementar `LoopController`.** Validar limites, detectar fim de loop e calcular reposicionamento local. **Concluído quando:** loops inválidos são rejeitados e o reinício usa a timeline compartilhada.
- [ ] **T1.7 — Implementar metrônomo de domínio.** Gerar agenda de pulsos a partir de BPM, compasso, acento inicial e posição de timeline. **Concluído quando:** pulsações reiniciam de forma determinística em início, pausa e loop.
- [ ] **T1.8 — Cobertura TDD do domínio de áudio.** Criar testes antes ou junto com cada regra. **Concluído quando:** regras de mix, loop, alinhamento e metrônomo têm cobertura de cenários normais e limites.

### Fase 2 — Perfil, biblioteca e persistência

- [ ] **T2.1 — Modelar schema SQLite.** Criar tabelas para perfil, preferências, músicas, faixas, letras, naipes, histórico, biblioteca, destino de backup e mestres conhecidos. **Concluído quando:** schema possui chaves, índices e migrações aditivas versionadas.
- [ ] **T2.2 — Implementar `UserProfile`.** Persistir nome, avatar opcional, naipe padrão e preferências de compartilhamento. **Concluído quando:** usuário cria e edita perfil sem login, e avatar fica no sandbox privado.
- [ ] **T2.3 — Implementar `UserPreferences`.** Salvar tema, volumes, tela ligada, backup e preferências de metrônomo. **Concluído quando:** alterações sobrevivem ao reinício e afetam apenas o dispositivo local.
- [ ] **T2.4 — Implementar CRUD de músicas.** Salvar música, naipes, faixas, hashes, versão e letra com transação. **Concluído quando:** falha em qualquer etapa não deixa registros órfãos.
- [ ] **T2.5 — Implementar repositório de biblioteca sem N+1.** Carregar resumos de músicas e detalhes em lote. **Concluído quando:** teste de consulta verifica número limitado de queries para bibliotecas grandes.
- [ ] **T2.6 — Implementar origem da biblioteca.** Registrar `created`, `received` e `participated`. **Concluído quando:** a UI pode filtrar ou identificar origem sem inferência por nome.
- [ ] **T2.7 — Implementar uso de armazenamento.** Calcular espaço por áudio, pacote, temporários e banco. **Concluído quando:** exclusão/refatoração atualiza o uso apresentado.
- [ ] **T2.8 — Implementar exclusão transacional.** Remover metadados, faixas e temporários com confirmação. **Concluído quando:** não há arquivos acessíveis sem registro nem registro apontando para arquivo inexistente.
- [ ] **T2.9 — Implementar histórico de ensaios.** Criar `RehearsalLog`, ignorar por padrão sessões abaixo de 60 segundos e permitir limpeza. **Concluído quando:** histórico não guarda áudio, letra ou dados individuais de terceiros.
- [ ] **T2.10 — Testar migrações.** Executar banco de versões anteriores contra o schema atual. **Concluído quando:** migrações não apagam biblioteca, perfil ou histórico do usuário.

### Fase 3 — Sala, protocolo e segurança

- [ ] **T3.1 — Implementar identidade do dispositivo.** Gerar e persistir `deviceId` UUID separado do `personId`. **Concluído quando:** reinstalação gera nova identidade e mensagens usam somente `deviceId` como remetente.
- [ ] **T3.2 — Implementar estados da sessão.** Criar máquina `disconnected -> discovering -> awaitingApproval -> negotiating -> joined -> preparing -> ready -> playing`. **Concluído quando:** mensagens fora do estado permitido são rejeitadas sem crash.
- [ ] **T3.3 — Implementar descoberta mDNS/Bonjour.** Publicar e localizar o serviço `_cantae._tcp`. **Concluído quando:** aparelhos Android e iOS físicos se descobrem em Wi-Fi compatível.
- [ ] **T3.4 — Implementar permissões de rede.** Adicionar priming e recuperação no iOS; adquirir/liberar multicast lock somente quando necessário no Android. **Concluído quando:** o app explica permissão negada e não mantém lock sem sessão ou descoberta ativa.
- [ ] **T3.5 — Implementar criação de sala.** Gerar código visual, `sessionId`, estado de mestre e TTL de inatividade. **Concluído quando:** mestre entra automaticamente como participante e sala expira após 30 minutos inativa.
- [ ] **T3.6 — Implementar solicitação e aprovação de entrada.** Criar fluxos de `solicitar_entrada`, aprovar e rejeitar. **Concluído quando:** ninguém entra ou recebe estado/arquivo antes da aprovação.
- [ ] **T3.7 — Implementar handshake seguro.** Usar biblioteca criptográfica estabelecida para derivar chave temporária. **Concluído quando:** segredo de sessão não aparece em texto puro, log, banco ou pacote exportado.
- [ ] **T3.8 — Implementar envelope autenticado.** Assinar/verificar HMAC-SHA-256, `messageId`, sequência e timestamp. **Concluído quando:** mensagens alteradas, duplicadas, expiradas ou de sessão desconhecida são descartadas.
- [ ] **T3.9 — Implementar autorização.** Validar papel antes de processar controles globais. **Concluído quando:** cantor/visitante não consegue iniciar música, alterar loop, configurar metrônomo ou encerrar sala.
- [ ] **T3.10 — Implementar sala cheia e visitante.** Aplicar limite de oito pessoas, papel visitante e capacidades restritas. **Concluído quando:** visitante acompanha estado mas não baixa áudio automaticamente nem controla sessão.
- [ ] **T3.11 — Implementar transferência de mestre.** Validar alvo ativo, confirmar mudança e replicar autoridade. **Concluído quando:** somente mestre atual transfere e novo mestre pode controlar a sala após confirmação.
- [ ] **T3.12 — Implementar encerramento.** Enviar `encerrar_sessao`, desconectar clientes e descartar chaves temporárias. **Concluído quando:** participantes recebem estado claro e não aceitam comandos antigos da sessão.
- [ ] **T3.13 — Implementar ping/pong.** Medir RTT, perda e disponibilidade por participante. **Concluído quando:** métricas atualizam sem afetar reprodução ou causar tráfego excessivo.
- [ ] **T3.14 — Implementar diagnósticos.** Mapear falhas para permissão negada, sala ausente, código inválido, aprovação pendente, rede isolada, mestre desconectado e versão incompatível. **Concluído quando:** cada falha tem mensagem compreensível e próxima ação.
- [ ] **T3.15 — Testar protocolo adversarialmente.** Simular payload inválido, replay, papel errado, sequência fora de ordem e queda de conexão. **Concluído quando:** nenhuma simulação produz alteração indevida de estado ou exceção não tratada.

### Fase 4 — Transferência, sincronização e players

- [ ] **T4.1 — Implementar metadados de transferência.** Criar `transfer_offer` com tamanho, MIME, hashes, versão e total de chunks. **Concluído quando:** destino valida a oferta antes de reservar espaço ou gravar dados.
- [ ] **T4.2 — Implementar transferência direta.** Transferir arquivo menor que 5 MB para temporário privado. **Concluído quando:** hash final é obrigatório antes de publicar na biblioteca.
- [ ] **T4.3 — Implementar transferência em chunks.** Usar blocos de 512 KB, ACK individual, hash por chunk e limite de uma transferência por participante. **Concluído quando:** queda de rede retoma a partir do último chunk confirmado.
- [ ] **T4.4 — Implementar limpeza de transferências.** Remover temporários corrompidos e expirar transferências abandonadas. **Concluído quando:** nenhum arquivo parcial aparece como música disponível.
- [ ] **T4.5 — Integrar players multipista.** Criar um player por faixa e carregar em paralelo com limites de erro. **Concluído quando:** faixas iniciam/paralisam juntas localmente e falha de faixa é mostrada de modo acionável.
- [ ] **T4.6 — Aplicar mix e alinhamento ao player.** Conectar `AudioMixCalculator` e `startDelayMs` às APIs de player. **Concluído quando:** mudar volume/naipe não reinicia áudio e alinhamento persiste entre sessões.
- [ ] **T4.7 — Implementar preparação coletiva.** Processar `preparar_reproducao`, validar versão/hash e responder `pronto_para_tocar`. **Concluído quando:** mestre vê participantes prontos, pendentes e com erro.
- [ ] **T4.8 — Implementar disparo agendado.** Usar RTT e `startAtMs` futuro para agendar play local. **Concluído quando:** teste físico mede desvio de início até 100 ms no cenário definido.
- [ ] **T4.9 — Integrar loop coletivo.** Receber configuração uma vez e repetir localmente. **Concluído quando:** loop não envia tráfego por repetição e mantém alinhamento/metrônomo.
- [ ] **T4.10 — Integrar metrônomo real.** Misturar clique local, volume individual e acento de compasso. **Concluído quando:** mestre controla estado global e cada pessoa controla apenas volume próprio.
- [ ] **T4.11 — Configurar áudio em segundo plano.** Integrar `audio_service`, foreground service Android e sessão `.playback` no iOS. **Concluído quando:** áudio carregado continua com tela bloqueada e interrupções exigem retomada explícita.
- [ ] **T4.12 — Benchmark físico.** Testar 2, 4 e 8 aparelhos em Wi-Fi doméstico e hotspots Android/iPhone. **Concluído quando:** relatório registra latência, perdas, tempo de preparo, transferência e desvio de áudio.

### Fase 5 — Pacotes e backup

- [ ] **T5.1 — Definir manifesto `.cantae`.** Criar `manifest.json` versionado com conteúdo, hashes, versão e arquivos. **Concluído quando:** parser rejeita campos obrigatórios ausentes e versões incompatíveis.
- [ ] **T5.2 — Exportar pacote.** Gerar ZIP `.cantae` com música, faixas, letra, naipes, alinhamento e hashes. **Concluído quando:** pacote exportado pode ser validado e não contém perfil, logs, chaves ou dados de outros participantes.
- [ ] **T5.3 — Importar pacote.** Extrair em temporário, validar todos os hashes e só então persistir em transação. **Concluído quando:** pacote corrompido não altera biblioteca.
- [ ] **T5.4 — Resolver conflito de importação.** Comparar `songId`, versão e `contentHash`; oferecer manter ambas, ignorar ou substituir após confirmação. **Concluído quando:** nenhuma substituição ocorre sem escolha explícita.
- [ ] **T5.5 — Modelar destino de backup.** Persistir nome, chave/certificado aprovado, último backup e status; segredo no Keystore/Keychain. **Concluído quando:** apagar destino revoga acesso e remove credenciais locais.
- [ ] **T5.6 — Implementar conexão segura ao backup.** Validar certificado/chave do destino e estabelecer canal autenticado/criptografado. **Concluído quando:** SSID igual, mas destino não aprovado, não é aceito automaticamente.
- [ ] **T5.7 — Implementar backup incremental.** Comparar `contentHash`, enviar somente conteúdo ausente e registrar resultado. **Concluído quando:** segundo backup sem mudança não reenvia arquivos íntegros.
- [ ] **T5.8 — Implementar políticas de execução.** Permitir automático somente em rede Wi-Fi/destino aprovado; bloquear rede móvel/desconhecida. **Concluído quando:** tentativas fora da política geram status explicativo sem transferência.
- [ ] **T5.9 — Implementar backup manual e gerenciamento.** Iniciar, pausar, desativar, revogar e mostrar última execução. **Concluído quando:** usuário controla integralmente o recurso sem precisar apagar a biblioteca.

### Fase 6 — Interfaces e experiência

- [ ] **T6.1 — Criar onboarding.** Explicar local-first, solicitar nome, oferecer naipe e preferências de compartilhamento. **Concluído quando:** usuário chega à biblioteca sem login, e foto segue desativada para envio por padrão.
- [ ] **T6.2 — Criar tela de perfil.** Editar nome, foto, naipe padrão, volumes, tema, tela ligada, privacidade e exclusão total. **Concluído quando:** alterações persistem localmente e a exclusão exige confirmação reforçada.
- [ ] **T6.3 — Criar tela de biblioteca.** Mostrar músicas, completude, origem, uso de espaço e histórico resumido. **Concluído quando:** listas longas usam carregamento eficiente e não travam UI.
- [ ] **T6.4 — Criar cadastro de música.** Incluir naipes, arquivos, validações, letra, playback e estado de completude. **Concluído quando:** erro de arquivo aponta o campo e não persiste dados parciais.
- [ ] **T6.5 — Criar tela de alinhamento.** Exibir forma de onda, arrasto, campo `mm:ss.s`, mudo, solo e teste. **Concluído quando:** ambos controles atualizam o mesmo `startDelayMs` e salvar persiste o ajuste.
- [ ] **T6.6 — Criar fluxo de sala.** Implementar criar/entrar, código, aprovação, status de preparo e lista de participantes. **Concluído quando:** mestre diferencia cantor, visitante, pronto, pendente, conexão e erro.
- [ ] **T6.7 — Criar painel do mestre.** Oferecer tocar, loop, metrônomo, transferência de mestre, encerramento e qualidade de rede. **Concluído quando:** controles indisponíveis para papéis sem autorização.
- [ ] **T6.8 — Criar player do cantor/visitante.** Selecionar naipe, controlar mix local, acompanhar letra e ver estado de conexão. **Concluído quando:** visitante não vê controles proibidos e cantor não vê ações exclusivas do mestre.
- [ ] **T6.9 — Criar histórico.** Exibir ensaios por música e comandos de exclusão. **Concluído quando:** dados exibidos correspondem ao `RehearsalLog` e limpeza é imediata.
- [ ] **T6.10 — Criar telas de importação/exportação/backup.** Incluir progresso, validação, conflito, último backup e falhas. **Conclído quando:** ações destrutivas ou substitutivas pedem confirmação explícita.
- [ ] **T6.11 — Implementar temas e acessibilidade.** Aplicar tokens de tema, contraste, escala de fonte, labels semânticos e estados não dependentes apenas de cor. **Concluído quando:** golden tests e testes de widget passam nos dois temas e fonte ampliada.
- [ ] **T6.12 — Responsividade para tablet.** Adaptar painel do mestre para telas maiores. **Concluído quando:** nenhuma função de sala exige rolagem horizontal ou fica inacessível.

### Fase 7 — Validação e release

- [ ] **T7.1 — Testes end-to-end.** Cobrir criar sala, entrar, aprovar, preparar, tocar, loop, metrônomo, visitante, transferência e encerrar. **Concluído quando:** fluxo passa em Android e iOS físicos.
- [ ] **T7.2 — Testes de segurança.** Cobrir HMAC inválido, replay, expiração, autorização, pacote malformado e backup não confiável. **Concluído quando:** testes negativos estão automatizados e não deixam dados persistidos indevidamente.
- [ ] **T7.3 — Testes de privacidade.** Validar exportação, logs, exclusão completa e ausência de segredos em pacote/backup. **Concluído quando:** inspeção automatizada não encontra tokens, chaves ou letras completas nos artefatos proibidos.
- [ ] **T7.4 — Teste de paridade.** Executar checklist de todos os requisitos em Android e iOS. **Concluído quando:** diferenças inevitáveis são documentadas e comunicadas na interface.
- [ ] **T7.5 — Beta controlado.** Rodar ensaios reais com grupos pequenos e coletar somente feedback opt-in. **Concluído quando:** são avaliados sincronização, rede, usabilidade, bateria, transferência e backup.
- [ ] **T7.6 — Gate de release.** Revisar critérios de aceite, crash-free rate local disponível, permissões, política de privacidade e builds de loja. **Concluído quando:** todos os itens Must e critérios críticos de segurança passam.

## Dependências críticas

| Antes de | Deve estar pronto |
|---|---|
| Tela de sala | Máquina de estados, descoberta, aprovação e autorização |
| Reprodução coletiva | Players locais, preparação, hash de música e disparo agendado |
| Loop coletivo | Timeline compartilhada, alinhamento e player multipista |
| Visitante | Controle de papéis e autorização de sessão |
| Pacote `.cantae` | Modelo de música versionado e hashes de faixa |
| Backup automático | Destino autenticado, hashes e política de rede confiável |
| Release | Teste físico Android/iOS, segurança, privacidade e paridade |
