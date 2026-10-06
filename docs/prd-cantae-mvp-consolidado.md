# PRD — Cantaê (MVP consolidado)

## Visão geral

**Cantaê** é um aplicativo Flutter para grupos vocais ensaiarem com faixas por naipe sincronizadas em dispositivos móveis. O produto é local-first: dados e biblioteca ficam no dispositivo; a sala opera peer-to-peer em Wi-Fi local, sem backend obrigatório.

O foco do MVP é ensaio coletivo confiável, prática solo, organização de repertório e privacidade proporcional ao ambiente local.

## Papéis e identidade

| Papel | Definição |
|---|---|
| Mestre | Cria a sala, aprova participantes e controla ações globais |
| Cantor | Entra na sala, escolhe seu naipe e controla apenas o próprio mix |
| Visitante | Acompanha a sessão sem comandos globais e sem download automático |

Uma pessoa pode assumir papéis diferentes em sessões distintas.

| Entidade | Finalidade |
|---|---|
| `Person` | Perfil lógico local do usuário |
| `Device` | Instalação do app; é a identidade usada na rede |
| `SessionParticipant` | Papel e status em uma sessão temporária |

## Requisitos funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF01 | Criar sala e gerar código numérico de 4 dígitos para descoberta visual | Must |
| RF02 | Entrar em sala existente usando código e aprovação do mestre | Must |
| RF03 | Mostrar somente os naipes disponíveis na música selecionada | Must |
| RF04 | Permitir seleção de naipe por participante a cada música | Must |
| RF05 | Reproduzir faixas simultâneas com mix individual por naipe | Must |
| RF06 | Ajustar volume relativo entre própria voz e coro | Must |
| RF07 | Iniciar reprodução coletiva por preparação prévia e disparo agendado | Must |
| RF08 | Definir trecho de loop por timeline | Must |
| RF09 | Executar loop localmente em cada dispositivo | Must |
| RF10 | Encerrar loop e seguir reprodução normal da posição atual | Must |
| RF11 | Tocar músicas locais em modo solo | Must |
| RF12 | Manter biblioteca local com músicas criadas, recebidas ou usadas em sessões | Must |
| RF13 | Cadastrar música com arquivo por naipe, validação de formato, tamanho e hash | Must |
| RF14 | Vincular música ao autor; mesmo nome não implica mesma música | Must |
| RF15 | Marcar música completa quando todos os naipes vocais padrão tiverem faixa | Must |
| RF16 | Permitir Playback opcional | Must |
| RF17 | Manter naipes padrão e naipes customizados reutilizáveis | Must |
| RF18 | Cadastrar letra por linhas sincronizadas | Must |
| RF19 | Marcar naipe responsável por linha/bloco | Must |
| RF20 | Marcar dinâmica e descrição textual opcional | Should |
| RF21 | Manter lista local de mestres conhecidos | Should |
| RF22 | Continuar tocando áudio carregado após perda de rede | Must |
| RF23 | Oferecer temas claro e escuro | Must |
| RF24 | Reproduzir em segundo plano e com tela bloqueada | Must |
| RF25 | Alinhar faixas manualmente com `startDelayMs`, mudo, solo e teste de loop | Must |
| RF26 | Limitar a sala a 8 participantes | Must |
| RF27 | Exigir aprovação do mestre para ingresso | Must |
| RF28 | Permitir transferência manual de mestre | Should |
| RF29 | Encerrar sala e invalidar material temporário de sessão | Must |
| RF30 | Medir RTT com `ping`/`pong` autenticado | Must |
| RF31 | Exibir qualidade de conexão de cada participante | Must |
| RF32 | Exibir orientação acionável para conexão degradada | Must |
| RF33 | Permitir aprovação como visitante | Should |
| RF34 | Impedir visitante de controlar sala, editar música ou baixar áudio automaticamente | Must |
| RF35 | Permitir visitante acompanhar letra, dinâmica e estado de sala | Must |
| RF36 | Permitir áudio a visitante somente se já existir localmente ou se mestre aprovar transferência | Must |
| RF37 | Registrar resumo local de ensaios por música | Should |
| RF38 | Registrar início, fim, duração, modo, papel local, loops e máximo de participantes | Should |
| RF39 | Exibir histórico local por música | Should |
| RF40 | Permitir apagar histórico por música ou global | Must |
| RF41 | Exportar música como pacote `.cantae` | Should |
| RF42 | Importar pacote `.cantae` validando manifesto e hashes | Should |
| RF43 | Nunca sobrescrever música silenciosamente durante importação | Must |
| RF44 | Resolver conflito: manter ambas, ignorar ou substituir após confirmação | Must |
| RF45 | Cadastrar e remover destinos confiáveis de backup local | Should |
| RF46 | Executar backup incremental apenas em Wi-Fi e destino previamente aprovados | Should |
| RF47 | Exibir resultado, data e falhas do último backup | Should |
| RF48 | Oferecer backup manual, pausa e desligamento do automático | Must |
| RF49 | Não fazer backup automático em rede móvel, pública ou desconhecida | Must |
| RF50 | Configurar BPM, compasso e acento do primeiro tempo por música | Should |
| RF51 | Permitir ao mestre ativar/desativar metrônomo coletivo | Must |
| RF52 | Sincronizar metrônomo com início e loop da música | Must |
| RF53 | Permitir volume local do metrônomo | Should |
| RF54 | Permitir metrônomo independente no modo solo | Should |
| RF55 | Criar e editar perfil local com nome de exibição | Must |
| RF56 | Adicionar foto de perfil opcional em armazenamento privado | Should |
| RF57 | Definir naipe padrão como sugestão | Should |
| RF58 | Configurar preferências locais de áudio, interface e ensaio | Must |
| RF59 | Visualizar uso de armazenamento por categoria | Should |
| RF60 | Exportar dados pessoais locais sem segredos de sessão | Should |
| RF61 | Apagar perfil e dados locais por confirmação reforçada | Must |
| RF62 | Escolher se nome e foto são compartilhados ao solicitar entrada em sala | Must |

## Requisitos não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-PERF-01 | Diferença de início entre dispositivos | Até 100 ms em rede típica validada |
| RNF-PERF-02 | Preparação de reprodução já disponível localmente | Até 2 s |
| RNF-PERF-03 | Fluidez das telas de ensaio | 60 fps sem travamento perceptível |
| RNF-UX-01 | Contraste nos temas | WCAG AA mínimo |
| RNF-UX-02 | Área de toque | Pelo menos 44 x 44 dp |
| RNF-UX-03 | Escala de fonte do sistema | Sempre respeitada |
| RNF-CONF-01 | Sala sem rede durante reprodução | Áudio carregado continua |
| RNF-CONF-02 | Incompatibilidade de protocolo | Bloqueia entrada e orienta atualização |
| RNF-CONF-03 | Inatividade da sala | Expira após 30 minutos |
| RNF-PLAT-01 | Plataformas mínimas | Android 8/API 26 e iOS 14 |
| RNF-SEC-01 | Sessão | `sessionId` aleatório e aprovação do mestre |
| RNF-SEC-02 | Mensagens | Integridade por HMAC-SHA-256, sequência e anti-replay |
| RNF-SEC-03 | Arquivos | Validação de tipo, tamanho, hash por chunk e hash final |
| RNF-SEC-04 | Segredos | Keystore Android e Keychain iOS |
| RNF-SEC-05 | Logs | Sem áudio, letras, tokens, chaves ou segredos |

## Arquitetura

```text
lib/
  presentation/     widgets, telas e view models
  domain/           entidades e casos de uso puros
  data/             repositórios e fontes de dados
  infrastructure/   SQLite, filesystem, rede, criptografia e players
```

Stack: Flutter/Dart, Riverpod, `just_audio`, `audio_service`, SQLite, mDNS/Bonjour e canal TCP confiável ou equivalente para sessão/transferência.

Regras arquiteturais:

- `domain` não depende de Flutter, plugins ou rede
- Consultas de biblioteca evitam N+1
- Hashing, parsing e arquivos grandes rodam fora da thread de UI
- Players, rede, persistência e mixagem são responsabilidades distintas
- TDD cobre regras de domínio, loop, protocolo e validações

## Segurança da sessão

O código de quatro dígitos identifica visualmente a sala, mas **não autentica** o participante. A entrada exige aprovação do mestre e handshake com biblioteca criptográfica consolidada; criptografia própria não é permitida.

### Fluxo de entrada

```text
Mestre cria sala -> gera sessionId e material temporário
Participante descobre sala por mDNS -> solicita entrada com código
Mestre aprova/rejeita -> handshake autenticado
Participante entra -> mensagens posteriores usam chave temporária
```

### Envelope de mensagens

```json
{
  "protocolVersion": 1,
  "sessionId": "uuid",
  "messageId": "uuid",
  "senderDeviceId": "uuid",
  "sequenceNumber": 42,
  "timestampMs": 1730000000000,
  "type": "tocar_agora",
  "payload": {},
  "authTag": "hmac-base64"
}
```

Mensagens com versão incompatível, sessão desconhecida, MAC inválido, sequência repetida ou autoridade inadequada são descartadas e registradas sem conteúdo sensível.

| Ação | Mestre | Cantor | Visitante |
|---|---|---|---|
| Aprovar entrada | Sim | Não | Não |
| Escolher próprio naipe | Sim | Sim | Não |
| Iniciar, configurar loop e metrônomo | Sim | Não | Não |
| Acompanhar letra/dinâmica | Sim | Sim | Sim |
| Solicitar arquivo | Sim | Sim | Não |
| Receber áudio | Sim | Sim | Apenas mediante aprovação |
| Transferir mestre ou encerrar sessão | Sim | Não | Não |

## Sincronização e áudio

### Disparo coletivo

1. Mestre envia `preparar_reproducao`.
2. Cada dispositivo confere versão e hash, carrega faixas e aplica alinhamento.
3. Participante responde `pronto_para_tocar`.
4. Mestre envia `tocar_agora` com `startAtMs` futuro.
5. Cada dispositivo agenda o play localmente no instante combinado.

`ping`/`pong` calcula RTT e uma estimativa simples de diferença de relógio. O mestre dispara o próprio player diretamente, sem aguardar o tráfego de rede retornar ao próprio dispositivo.

### Conexão

| Estado | RTT estimado | Mensagem |
|---|---:|---|
| Boa | Menor que 50 ms | Conexão boa |
| Atenção | 50 a 150 ms | Conexão instável |
| Ruim | Acima de 150 ms ou perda recorrente | Aproximar do roteador ou usar hotspot |
| Indisponível | Sem resposta | Sem conexão com o mestre |

O indicador de RTT é operacional; ele não substitui a medição de desvio real de início de áudio.

### Alinhamento e loop

`startDelayMs` representa o atraso de entrada de uma faixa na timeline compartilhada. Ele não corta o começo do arquivo. Se futuramente houver corte real de fonte, será outro campo (`sourceTrimStartMs`).

A letra, o loop e o metrônomo usam a timeline compartilhada. O loop obedece `inicioMs >= 0`, `fimMs > inicioMs` e `fimMs <= duração da timeline`; ao ser encerrado, a música continua da posição atual.

### Metrônomo

Cada música pode ter `bpm`, `beatsPerBar`, `accentFirstBeat` e `enabledByDefault`. Em sala, apenas o mestre ativa/desativa o metrônomo coletivo; o volume do clique permanece preferência local. No modo solo, o usuário controla o metrônomo individualmente.

## Transferência, importação e backup

### Transferência na sala

- Arquivos abaixo de 5 MB: transferência única
- Arquivos a partir de 5 MB: chunks de 512 KB
- Máximo de uma transferência ativa por participante no MVP
- Escrita inicial em diretório temporário privado
- Arquivo entra na biblioteca apenas após hash final válido

Cada transferência possui `transferId`, `songId`, versão, tipo, tamanho, total de chunks e `fileSha256`. Cada chunk possui índice e hash. Falhas removem temporários ou mantêm estado de retomada dentro de janela limitada.

### Pacote `.cantae`

Formato físico: ZIP com extensão `.cantae`.

Conteúdo:

```text
manifest.json
metadados da música
naipes e letras
startDelayMs
faixas de áudio
songVersion e contentHash
hashes das faixas
```

Não incluir perfil, dados de outros participantes, lista de mestres, históricos pessoais, logs, tokens, chaves ou segredos. Importação inválida não muda a biblioteca; conflito exige escolha explícita.

### Backup local confiável

O usuário pode cadastrar um computador ou NAS como destino de backup. Backup automático só ocorre em rede Wi-Fi e destino previamente aprovados; nunca em rede móvel, pública ou desconhecida.

- Validar destino por certificado ou chave pública previamente aceita, não somente por SSID
- Usar canal autenticado e criptografado
- Guardar credenciais no Keystore/Keychain
- Fazer backup incremental por `contentHash`
- Mostrar último resultado, falha e espaço estimado
- Permitir backup manual, pausa, desativação e revogação de destino

Excluir dados locais não apaga cópias externas automaticamente sem confirmação explícita.

## Perfil e preferências

O perfil é local e não requer e-mail, senha, telefone, contatos, localização ou conta em nuvem. Ele não é mecanismo de autenticação da sala.

### UserProfile

| Campo | Obrigatório | Observação |
|---|---|---|
| `personId` | Sim | UUID local |
| `displayName` | Sim | Nome mostrado apenas conforme permissão |
| `avatarPath` | Não | Arquivo privado, envio desligado por padrão |
| `defaultVoicePartId` | Não | Sugestão, não seleção obrigatória |
| `shareDisplayNameInRoom` | Sim | Preferência explícita |
| `shareAvatarInRoom` | Sim | Padrão: falso |
| `createdAt`, `updatedAt` | Sim | Auditoria local mínima |

### UserPreferences

| Campo | Função |
|---|---|
| `themeMode` | Sistema, claro ou escuro |
| `ownVoiceVolume` | Volume padrão da própria voz |
| `choirVolume` | Volume padrão do coro |
| `metronomeVolume` | Volume padrão do metrônomo |
| `keepScreenOnDuringRehearsal` | Manter tela ligada durante ensaio |
| `autoBackupEnabled` | Habilitar backup automático |
| `trustedBackupDestinationId` | Destino confiável selecionado |

Primeiro uso: explicar que os dados ficam no dispositivo, pedir nome, oferecer naipe padrão opcional e perguntar como o nome será compartilhado em salas. A foto nunca é enviada automaticamente.

A exclusão total remove perfil, preferências, biblioteca, históricos, temporários, mestres conhecidos e logs locais.

## Histórico de ensaios

Ensaios com pelo menos 60 segundos são registrados localmente por padrão. O histórico não armazena áudio, letra, comportamento individual ou dados de outros participantes.

### RehearsalLog

| Campo | Tipo |
|---|---|
| `id` | UUID |
| `songId` | UUID |
| `startedAt`, `endedAt` | datetime |
| `durationMs` | int |
| `mode` | `solo` ou `sala` |
| `localRole` | `mestre`, `cantor` ou `visitante` |
| `maxParticipants` | int |
| `loopCount` | int |

O usuário pode apagar históricos por música ou todos os históricos locais.

## Modelos adicionais

| Modelo | Campos principais |
|---|---|
| `Song` | `id`, `nome`, `authorId`, `version`, `contentHash`, `createdAt` |
| `SongTrack` | `id`, `songId`, `naipeId`, `arquivoAudioPath`, `startDelayMs`, `fileSize`, `fileSha256` |
| `MusicLibraryEntry` | `songId`, `origem` (`created`, `received`, `participated`), datas |
| `MetronomeConfig` | `songId`, `bpm`, `beatsPerBar`, `accentFirstBeat`, `enabledByDefault` |
| `BackupDestination` | `id`, nome, chave/certificado aprovado, último backup e status |

## Plataforma

### iOS

- Declarar `NSLocalNetworkUsageDescription` e `NSBonjourServices`
- Exibir explicação antes da permissão de rede local
- Oferecer rota para Ajustes se a permissão for negada
- Usar sessão de áudio `.playback`
- Aceitar limitação de rede em background; áudio carregado continua

### Android

- Declarar permissões de Wi-Fi necessárias
- Usar multicast lock apenas durante descoberta/conexão
- Usar foreground service e notificação persistente para áudio em segundo plano

A UI diferencia: permissão negada, sala não encontrada, código inválido, aprovação pendente, sala cheia, mestre desconectado, protocolo incompatível, rede isolada e transferência interrompida.

## Trade-offs consolidados

| Tema | Decisão do MVP | Reavaliar quando |
|---|---|---|
| Código de sala | Descoberta visual, não autenticação | Nunca como único controle de acesso |
| Host único | Aceito com transferência manual | Se falhas do mestre forem recorrentes |
| Descoberta | mDNS/Bonjour | Se bloqueio de multicast for frequente |
| Sincronização | Preparação + disparo agendado | Se desvio superar 100 ms |
| Transferência | Chunk de 512 KB a partir de 5 MB | Após benchmark real |
| Limite de sala | 8 participantes | Após testes físicos de carga |
| Backup | Local, opcional e em destino confiável | Se houver demanda por nuvem |
| Metrônomo | Manual, configurado pelo mestre | Se houver demanda por mapa de tempo |
| Perfil | Local, sem login ou coleta de dados | Se houver necessidade comprovada de multi-dispositivo remoto |
| Visitante | Visual por padrão; áudio mediante autorização | Após validar uso em ensaios reais |

## Plano de construção

### Fase 1 — Domínio de áudio

- [ ] Seleção de naipe e mix pessoal
- [ ] Timeline compartilhada e `startDelayMs`
- [ ] `LoopController`
- [ ] Metrônomo e reinício correto no loop
- [ ] Testes TDD de regras de áudio

### Fase 2 — Persistência local

- [ ] Schema SQLite e migrações aditivas
- [ ] Biblioteca, músicas, faixas, letras e naipes sem N+1
- [ ] Perfil e preferências
- [ ] Histórico de ensaios
- [ ] MetronomeConfig, hashes e versões
- [ ] Exclusão transacional e limpeza total de dados

### Fase 3 — Sessão e conectividade

- [ ] mDNS/Bonjour e permissões por plataforma
- [ ] Máquina de estados da sala
- [ ] Entrada com aprovação, visitante e limite de participantes
- [ ] Handshake e mensagens autenticadas
- [ ] Controle de autoridade, anti-replay e TTL
- [ ] Ping/pong, qualidade de conexão e diagnósticos
- [ ] Transferência de mestre e encerramento de sessão

### Fase 4 — Arquivos, backup e players

- [ ] Transferência direta/chunks, integridade e retomada
- [ ] Players multipista, mix, preparação e disparo agendado
- [ ] Áudio em segundo plano
- [ ] Exportação/importação `.cantae` com resolução de conflito
- [ ] Backup incremental em destino confiável
- [ ] Benchmark de sincronização em aparelhos físicos

### Fase 5 — Telas

- [ ] Biblioteca, cadastro e alinhamento de música
- [ ] Sala do mestre e tela de cantor/visitante
- [ ] Perfil, preferências e onboarding
- [ ] Histórico por música
- [ ] Importação/exportação e backup
- [ ] Metrônomo, temas e acessibilidade mínima

### Fase 6 — Qualidade e release

- [ ] CI com testes, análise estática, dependências e varredura de segredos
- [ ] Testes de autoridade, privacidade, importação e backup
- [ ] Build/testes Android e iOS em cada PR
- [ ] Testes físicos em ambos sistemas antes de release

## Critérios de aceite

- [ ] Até 8 dispositivos aprovados entram na sala
- [ ] Visitante não executa ações de controle nem recebe áudio automaticamente
- [ ] Mensagens forjadas, repetidas ou não autorizadas não alteram estado
- [ ] Início de áudio fica dentro de 100 ms no cenário de rede aceito
- [ ] Qualidade de conexão e falhas são visíveis e acionáveis
- [ ] Loop, letra e metrônomo respeitam a mesma timeline
- [ ] Arquivo só aparece após hash final válido
- [ ] Pacote inválido não altera biblioteca; conflito não sobrescreve silenciosamente
- [ ] Backup só executa em destino e rede aprovados, sem segredos nos dados enviados
- [ ] Perfil funciona sem login, e dados locais podem ser totalmente apagados
- [ ] Histórico não inclui conteúdo sensível e pode ser removido
- [ ] Áudio em segundo plano funciona em Android e iOS
