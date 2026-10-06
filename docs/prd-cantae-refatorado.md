# PRD — Cantaê (Refatorado)

## 1. Visão geral

**Cantaê** é um aplicativo mobile em Flutter para grupos vocais ensaiarem com cada cantor ouvindo, no próprio fone, a mesma música sincronizada e com seu naipe em destaque. O MVP é local-first: comunicação peer-to-peer em Wi-Fi local, sem servidor externo e com os dados mantidos no dispositivo.

**Princípio de engenharia:** adotar a solução de menor complexidade que resolva o problema de forma robusta. Segurança, sincronização e integridade de arquivos não são opcionais porque fazem parte do valor central do produto.

## 2. Papéis e identidades

Os papéis são situacionais por sessão.

| Papel | Definição |
|---|---|
| Mestre | Cria a sala, aprova participantes e controla a reprodução coletiva |
| Cantor | Entra na sala e participa do ensaio |

Uma pessoa pode ser mestre em uma sessão e cantora em outra.

### 2.1 Identidades separadas

| Entidade | Propósito | Persistência |
|---|---|---|
| `Person` | Identidade lógica e nome exibido | Local, longo prazo |
| `Device` | Instalação física do app | Local, por dispositivo |
| `SessionParticipant` | Participação e papel em uma sala | Somente durante a sessão |

**Regra:** mensagens de rede usam `deviceId` como remetente. `personId` é opcional e não é usado como identidade de transporte.

## 3. Requisitos funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF01 | Criar uma sala de ensaio e gerar um código numérico de 4 dígitos para descoberta visual | Must |
| RF02 | Entrar em sala existente informando o código e aguardando aprovação do mestre | Must |
| RF03 | Exibir apenas os naipes cadastrados na música selecionada para todos os participantes, inclusive mestre | Must |
| RF04 | Permitir que cada participante escolha seu naipe a cada música, sem persistir a escolha entre músicas | Must |
| RF05 | Reproduzir todas as faixas simultaneamente em cada dispositivo, ajustando o volume relativo pelo naipe escolhido | Must |
| RF06 | Permitir ajuste do mix entre “minha voz” e “coro completo” | Must |
| RF07 | Permitir que o mestre inicie reprodução coletiva com preparação prévia e disparo agendado | Must |
| RF08 | Permitir que o mestre defina trecho de loop por marcação ou alças na timeline | Must |
| RF09 | Repetir loop localmente em cada dispositivo, sem sinal de rede a cada repetição | Must |
| RF10 | Permitir que o mestre encerre o loop e retome a reprodução normal | Must |
| RF11 | Permitir reprodução de músicas locais sem sala, no modo solo | Must |
| RF12 | Manter biblioteca local com músicas criadas, recebidas ou usadas em sessões do participante | Must |
| RF13 | Permitir cadastrar música com uma faixa de áudio por naipe, validando formato, tamanho e integridade | Must |
| RF14 | Vincular música ao autor; músicas com mesmo nome e autores diferentes são entidades distintas | Must |
| RF15 | Considerar uma música completa quando todos os naipes vocais padrão tiverem arquivo cadastrado | Must |
| RF16 | Permitir Playback opcional sem afetar a completude da música | Must |
| RF17 | Manter quatro naipes predefinidos e permitir naipes customizados reutilizáveis | Must |
| RF18 | Permitir cadastrar letra por linhas, com instante inicial previamente definido | Must |
| RF19 | Permitir indicar naipe responsável por linha ou bloco da letra | Must |
| RF20 | Permitir marcação de dinâmica e descrição opcional por linha ou bloco | Should |
| RF21 | Manter lista local de mestres conhecidos para reconexão facilitada | Should |
| RF22 | Continuar tocando áudio já carregado após perda de conexão | Must |
| RF23 | Oferecer temas claro e escuro | Must |
| RF24 | Continuar reprodução em segundo plano e com tela bloqueada | Must |
| RF25 | Oferecer tela de alinhamento de faixas com mudo, solo, teste de loop e persistência de `startDelayMs` | Must |
| RF26 | Limitar uma sala a 8 participantes simultâneos | Must |
| RF27 | Exigir aprovação visual do mestre para novos participantes | Must |
| RF28 | Permitir transferência manual da autoridade de mestre a um participante conectado | Should |
| RF29 | Permitir encerrar explicitamente uma sala e invalidar as chaves temporárias da sessão | Must |

### Fora de escopo

| Item | Motivo |
|---|---|
| Transposição em tempo real | Exige DSP nativo e aumenta risco técnico |
| Áudio ao vivo entre cantores | Latência de rede inviabiliza sincronismo de canto |
| Eleição automática de mestre | Alta complexidade de estado e conflitos |
| Sincronização avançada de relógio | Será revisitada se o disparo agendado não atingir a meta |
| Desktop/notebook | Não é central para o caso de uso com fones em ensaio |

## 4. Requisitos não funcionais

### Desempenho e sincronização

| ID | Requisito | Meta |
|---|---|---|
| RNF-PERF-01 | Diferença de início audível entre dispositivos | Até 100 ms em rede típica |
| RNF-PERF-02 | Preparação de reprodução após comando do mestre | Até 2 s, excluindo download de arquivos |
| RNF-PERF-03 | Fluidez nas telas do ensaio | 60 fps sem travamento perceptível |
| RNF-PERF-04 | Resposta de troca de naipe na UI e no áudio | Até 50 ms percebidos |

### Confiabilidade

| ID | Requisito |
|---|---|
| RNF-CONF-01 | O modo solo funciona sem rede ou internet |
| RNF-CONF-02 | O áudio já preparado continua após perda de rede |
| RNF-CONF-03 | Incompatibilidade de protocolo bloqueia a entrada e orienta atualização |
| RNF-CONF-04 | Sessão é encerrada se o app for finalizado pelo sistema operacional |
| RNF-CONF-05 | Uma sala expira após 30 minutos sem atividade de controle ou presença |

### Usabilidade e acessibilidade

| ID | Requisito |
|---|---|
| RNF-UX-01 | Interface utilizável durante ensaio, com ações essenciais em poucos toques |
| RNF-UX-02 | Tema claro e escuro com contraste mínimo AA |
| RNF-UX-03 | Textos respeitam escala de fonte do sistema |
| RNF-UX-04 | Elementos interativos têm área mínima de toque de 44 x 44 dp |
| RNF-UX-05 | Estado de naipe, mudo, solo e conexão usa texto/ícone além de cor |
| RNF-UX-06 | Falhas de conectividade apresentam diagnóstico e ação recomendada |

### Plataforma e qualidade

| ID | Requisito |
|---|---|
| RNF-PLAT-01 | iOS solicita permissão de rede local com tela explicativa prévia e rota de recuperação |
| RNF-PLAT-02 | Suportar Android 8.0/API 26 e iOS 14 ou superiores |
| RNF-PLAT-03 | Usar serviço mDNS/Bonjour fixo `_cantae._tcp` nas duas plataformas |
| RNF-MAINT-01 | Aplicar SOLID sem abstração especulativa |
| RNF-MAINT-02 | Alertar complexidade ciclomática acima de 10 e refatorar acima de 15 |
| RNF-MAINT-03 | Regras de domínio e protocolo com testes automatizados determinísticos |
| RNF-MAINT-04 | Erros retornam falhas tipadas e logs locais sem conteúdo sensível |

### Segurança e privacidade

| ID | Requisito |
|---|---|
| RNF-SEC-01 | Toda sala usa `sessionId` aleatório de alta entropia |
| RNF-SEC-02 | A entrada requer aprovação do mestre; o código de quatro dígitos não é autenticação |
| RNF-SEC-03 | Mensagens pós-handshake têm autenticação de integridade com HMAC-SHA-256 |
| RNF-SEC-04 | Mensagens repetidas são rejeitadas por contador monotônico e `messageId` |
| RNF-SEC-05 | Somente mestre pode emitir comandos globais |
| RNF-SEC-06 | Arquivos têm validação de tamanho, formato real, hash por chunk e hash final |
| RNF-SEC-07 | Segredos e chaves de longo prazo usam Android Keystore e iOS Keychain |
| RNF-SEC-08 | Áudios, letras, tokens, chaves e segredos nunca entram em logs |
| RNF-SEC-09 | O usuário pode apagar integralmente seus dados locais |
| RNF-SEC-10 | IDs são UUIDs gerados pelo app, sem identificador permanente do aparelho |

## 5. Arquitetura técnica

### 5.1 Stack

- Flutter/Dart
- Riverpod para estado e injeção de dependências
- `just_audio` para players por faixa
- `audio_service` para áudio em segundo plano
- SQLite para metadados locais
- mDNS/Bonjour para descoberta local
- Sockets TCP ou canal confiável equivalente para sessão e transferência

### 5.2 Camadas

```text
lib/
  presentation/     widgets, telas, view models
  domain/           entidades, regras e casos de uso puros
  data/             repositórios e fontes de dados
  infrastructure/   SQLite, rede, criptografia, filesystem e players
```

A camada `domain` não depende de Flutter, plugins ou rede. A infraestrutura implementa interfaces definidas no domínio.

### 5.3 Regras de design

- Motor de áudio, protocolo de sessão, transferência e persistência são responsabilidades separadas
- Consultas de biblioteca carregam músicas, faixas e letras em lote, evitando N+1
- Operações pesadas, como hashing e leitura de arquivos, executam fora da thread de UI
- Widgets de alta frequência são pequenos e isolados para reduzir rebuilds

## 6. Sessão e segurança de rede

### 6.1 Princípios

O Wi-Fi local não é considerado confiável. O código de quatro dígitos serve para o usuário identificar a sala, mas não prova identidade nem autoriza acesso.

A sala tem um mestre ativo, participantes aprovados e uma chave de sessão temporária. A chave existe apenas durante a sessão e deve ser descartada ao encerrá-la.

### 6.2 Fluxo de entrada

```text
Mestre cria sala
  -> gera sessionId, código visual e material de chave temporário
Participante encontra a sala via mDNS
  -> envia solicitar_entrada com código e chave pública efêmera
Mestre aprova ou rejeita na interface
  -> conclui handshake autenticado
Participante entra na sala com chave de sessão derivada
  -> todas as mensagens posteriores usam autenticação de integridade
```

O segredo de sessão não pode ser enviado em texto puro. A implementação deve usar uma biblioteca criptográfica consolidada; não é permitido implementar criptografia própria.

### 6.3 Autoridade

| Ação | Quem pode executar |
|---|---|
| Aprovar/rejeitar participante | Mestre |
| Selecionar o próprio naipe | Participante ou mestre |
| Preparar/iniciar reprodução | Mestre |
| Ativar/encerrar loop | Mestre |
| Transferir autoridade | Mestre atual |
| Encerrar a sessão | Mestre |
| Solicitar arquivo de música | Participante autenticado |

Mensagens fora da autoridade do remetente são descartadas e registradas como evento técnico sem expor segredo ou conteúdo pessoal.

### 6.4 Envelope de mensagem

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

Regras:

- `protocolVersion` incompatível bloqueia a participação
- `sessionId` desconhecido é descartado
- `authTag` inválido é descartado
- `sequenceNumber` repetido ou inferior ao último aceito é descartado
- `messageId` duplicado é descartado
- Mensagens expiram fora de uma janela curta de tolerância, exceto operações de transferência explicitamente retomáveis
- Campos numéricos e IDs são validados antes de alterar estado

### 6.5 Tipos de mensagem

| Tipo | Direção | Payload principal |
|---|---|---|
| `solicitar_entrada` | Participante -> mestre | `codigo`, `deviceName`, chave pública efêmera |
| `aprovar_entrada` | Mestre -> participante | dados de handshake autenticado |
| `rejeitar_entrada` | Mestre -> participante | motivo opcional |
| `estado_sala` | Mestre -> participantes | participantes, música atual, estado de reprodução |
| `escolher_naipe` | Participante -> mestre | `naipeId` |
| `preparar_reproducao` | Mestre -> participantes | `songId`, versão, hash de conteúdo |
| `pronto_para_tocar` | Participante -> mestre | `songId`, status de preparo |
| `tocar_agora` | Mestre -> participantes | `songId`, `startAtMs` |
| `ativar_loop` | Mestre -> participantes | `inicioMs`, `fimMs` |
| `voltar_musica_completa` | Mestre -> participantes | sem payload |
| `transferir_mestre` | Mestre -> todos | `novoMestreDeviceId` |
| `encerrar_sessao` | Mestre -> participantes | sem payload |
| `ping` / `pong` | Bidirecional | timestamps de calibração |
| `transfer_offer` | Origem -> destino | metadados e hash do arquivo |
| `transfer_chunk` | Origem -> destino | índice, bytes e hash do chunk |
| `transfer_ack` | Destino -> origem | `transferId`, índice confirmado |
| `transfer_complete` | Destino -> origem | hash final validado |
| `transfer_error` | Bidirecional | código de falha seguro |

### 6.6 Máquina de estados

```text
disconnected
  -> discovering
  -> awaitingApproval
  -> negotiating
  -> joined
  -> preparing
  -> ready
  -> playing
  -> disconnected
```

Uma mensagem só é processada se for válida para o estado atual. Por exemplo, `ativar_loop` só é válido com música preparada ou em reprodução.

## 7. Sincronização de áudio

### 7.1 Preparação e disparo

O sistema não deve simplesmente tocar ao receber a mensagem, porque a latência de rede e o agendamento de cada aparelho variam.

Fluxo:

1. Mestre envia `preparar_reproducao`
2. Participantes verificam versão e hash da música, baixam arquivos se necessário
3. Cada dispositivo carrega faixas, aplica alinhamento e responde `pronto_para_tocar`
4. Mestre mostra quem está pronto e só habilita iniciar quando houver condição suficiente
5. Mestre envia `tocar_agora` com `startAtMs` futuro
6. Cada dispositivo agenda a reprodução local para o instante combinado

O mestre também dispara o próprio áudio diretamente, sem depender de receber a própria mensagem de volta pela rede.

### 7.2 Calibração de relógio

O MVP usa ping/pong para estimar RTT e diferença aproximada de relógio. O instante `startAtMs` deve ter margem de ao menos dois segundos após o envio para permitir agendamento local.

Caso a medição real não atinja a meta de 100 ms, revisar o mecanismo antes de expandir o escopo do produto.

### 7.3 Loop

- `inicioMs >= 0`
- `fimMs > inicioMs`
- `fimMs <= duração da timeline compartilhada`
- Loop só pode ser ativado para a música atualmente preparada
- O reinício do loop ocorre localmente em cada dispositivo
- Ao encerrar loop, a regra do MVP é continuar da posição atual; não reiniciar a música

## 8. Alinhamento de faixas

### 8.1 Modelo de tempo

A música possui uma **timeline compartilhada**, usada por reprodução, loop e letra. A posição zero da timeline representa o mesmo instante musical para todas as faixas.

`startDelayMs` é o atraso de entrada de uma faixa na timeline. O MVP não corta automaticamente o começo de um arquivo. Caso seja necessário remover silêncio real do arquivo no futuro, isso será um campo separado (`sourceTrimStartMs`) e não uma reinterpretação de `startDelayMs`.

### 8.2 Tela de alinhamento

Para cada faixa:

- Mudo local de teste
- Solo exclusivo de teste
- Forma de onda com deslocamento visual por `startDelayMs`
- Ajuste por arrasto e por campo `mm:ss.s`
- Teste de todas as faixas
- Teste de loop
- Persistência do valor ao salvar

A letra só pode ser sincronizada depois de salvar ou confirmar o alinhamento das faixas.

## 9. Transferência de arquivos

### 9.1 Regras

- Arquivos abaixo de 5 MB podem usar transferência única
- Arquivos iguais ou acima de 5 MB usam chunks de 512 KB
- Apenas uma transferência ativa por participante no MVP
- Arquivos são gravados primeiro em diretório temporário privado
- Arquivo final só é disponibilizado após validação completa

### 9.2 Metadados de transferência

```json
{
  "transferId": "uuid",
  "songId": "uuid",
  "songVersion": 1,
  "trackId": "uuid",
  "fileName": "soprano.m4a",
  "mimeType": "audio/mp4",
  "fileSize": 10485760,
  "chunkSize": 524288,
  "totalChunks": 20,
  "fileSha256": "hex"
}
```

Cada chunk inclui `transferId`, `chunkIndex`, `chunkSha256` e bytes. O destinatário valida ordem, tamanho e hash antes de gravar, confirma por ACK e valida o hash final antes de mover o arquivo temporário para o destino definitivo.

### 9.3 Falhas e limpeza

- Chunks inválidos são descartados
- Transferência interrompida pode ser retomada por `transferId` dentro de uma janela definida
- Transferências temporárias expiram e são removidas automaticamente
- Um erro final não deixa arquivo parcial na biblioteca
- Nome e extensão não são considerados prova de tipo válido

## 10. Modelo de dados

### Person

| Campo | Tipo |
|---|---|
| `id` | UUID |
| `nome` | string |
| `createdAt` | datetime |

### Device

| Campo | Tipo |
|---|---|
| `id` | UUID |
| `deviceName` | string |
| `appVersion` | string |
| `protocolVersion` | int |
| `personId` | UUID opcional |
| `createdAt` | datetime |

### SessionParticipant

| Campo | Tipo |
|---|---|
| `sessionId` | UUID |
| `deviceId` | UUID |
| `personId` | UUID opcional |
| `role` | `mestre` ou `cantor` |
| `status` | `pending`, `active`, `left` |
| `joinedAt` | datetime |

### Song

| Campo | Tipo |
|---|---|
| `id` | UUID |
| `nome` | string |
| `authorId` | UUID |
| `version` | int, padrão 1 |
| `contentHash` | string |
| `createdAt` | datetime |

### SongTrack

| Campo | Tipo |
|---|---|
| `id` | UUID |
| `songId` | UUID |
| `naipeId` | UUID ou `playback` |
| `arquivoAudioPath` | string privada do app |
| `startDelayMs` | int, padrão 0 |
| `fileSize` | int |
| `fileSha256` | string |

### LyricLine

| Campo | Tipo |
|---|---|
| `songId` | UUID |
| `ordem` | int |
| `tempoInicioMs` | int na timeline compartilhada |
| `texto` | string |
| `naipeTag` | string |
| `dinamicaTipo` | string opcional |
| `dinamicaDescricao` | string opcional |
| `blocoId` | UUID opcional |

### MusicLibraryEntry

| Campo | Tipo |
|---|---|
| `songId` | UUID |
| `origem` | `created`, `received`, `participated` |
| `receivedAt` | datetime opcional |
| `lastPlayedAt` | datetime opcional |

## 11. Segurança e privacidade

### 11.1 Ameaças e mitigação

| Ameaça | Mitigação |
|---|---|
| Pessoa na mesma Wi-Fi tenta entrar | Aprovação explícita do mestre e handshake autenticado |
| Código de sala adivinhado | Código não concede autenticação |
| Comando forjado | HMAC, chave de sessão e validação de autoridade |
| Replay de comando | Sequência monotônica, `messageId` e expiração |
| Arquivo corrompido | Hash por chunk e hash final |
| Arquivo indevido | Validação de MIME real, tamanho e parser seguro |
| Dispositivo perdido | Dados no sandbox privado; chaves no Keystore/Keychain |
| Vazamento por logs | Redação de dados e retenção limitada |
| Dependência vulnerável | Auditoria automatizada no CI |
| Sala abandonada | TTL, encerramento explícito e descarte de chaves |

### 11.2 Dados locais

- Banco e arquivos ficam no armazenamento privado do aplicativo
- Não usar diretório público de mídia para as faixas gerenciadas pelo Cantaê
- Chaves e segredos são descartados ao encerrar a sessão
- Logs não incluem letras completas, áudio, tokens, material criptográfico ou IPs completos
- Retenção padrão de logs técnicos: até 90 dias, com opção de limpeza imediata
- Ação “Apagar todos os dados locais” remove banco, biblioteca, temporários, mestres conhecidos e logs

### 11.3 Segurança de desenvolvimento

- `.gitignore` desde o primeiro commit
- Varredura de segredos no CI
- Dependências verificadas e atualizadas com processo controlado
- Consultas SQLite parametrizadas
- Entradas validadas antes de persistir, transmitir ou renderizar
- Letras e nomes são renderizados como texto simples, não HTML/markup executável
- Não implementar primitivas criptográficas próprias

## 12. Plataforma e conectividade

### iOS

- Declarar `NSLocalNetworkUsageDescription` e `NSBonjourServices`
- Explicar a permissão antes do prompt do sistema
- Oferecer atalho para Ajustes se a permissão for negada
- Usar sessão de áudio `.playback`
- Aceitar que ações de rede em background podem ficar indisponíveis; áudio carregado continua

### Android

- Declarar permissões de Wi-Fi necessárias
- Adquirir multicast lock apenas durante descoberta/conexão e liberá-lo quando não for necessário
- Usar foreground service com notificação persistente durante áudio em segundo plano

### Diagnóstico de rede

A UI deve diferenciar:

- Permissão de rede local negada
- Nenhuma sala encontrada
- Código inválido
- Solicitação aguardando aprovação
- Sala cheia
- Mestre desconectado
- Protocolo incompatível
- Rede bloqueando comunicação entre dispositivos
- Transferência interrompida

mDNS/Bonjour é o mecanismo principal. QR Code pode ser avaliado como fallback futuro, mas nunca substitui autenticação de sessão.

## 13. Trade-offs consolidados

| Tema | Decisão MVP | Reavaliar quando |
|---|---|---|
| Código de 4 dígitos | Descoberta visual; não é autenticação | Nunca como mecanismo único de acesso |
| Sessão segura | Aprovação do mestre + handshake + HMAC | Se canal criptografado completo for necessário |
| Host único | Aceito, com transferência manual de mestre | Se falha do host for recorrente |
| Descoberta | mDNS/Bonjour | Se ambientes bloquearem multicast com frequência |
| Fallback de conectividade | Diagnóstico claro; hotspot recomendado | Se QR resolver problemas recorrentes |
| Sincronização | Preparação + disparo agendado + ping/pong | Se não atingir 100 ms |
| Chunks | 512 KB para arquivos >= 5 MB | Após benchmark em aparelhos reais |
| Limite de sala | 8 participantes | Após teste de carga real |
| Criptografia em disco | Sandbox privado; segredos no Keystore/Keychain | Se avaliação de risco exigir criptografia de mídia |
| Reconexão automática | Fora do MVP | Se reentrada manual virar fricção importante |
| Leitor de tela | Semântica mínima no MVP | Auditoria dedicada pós-MVP |

## 14. Plano de construção

### Fase 0 — Setup

- [x] Estrutura por camadas
- [x] Dependências principais
- [x] Métrica de complexidade
- [x] Entidades iniciais de domínio
- [x] `AudioMixCalculator` com testes

### Fase 1 — Domínio de áudio

- [ ] `SelecionarNaipe`
- [ ] `AjustarMixPessoal`
- [ ] `LoopController`
- [ ] `EncerrarLoop`
- [ ] Testes TDD de regras de timeline, loop e alinhamento

### Fase 2 — Persistência local

- [ ] Schema SQLite com migrações aditivas
- [ ] Repositório de biblioteca sem N+1
- [ ] CRUD de música, faixa, letra e naipe
- [ ] Persistência de `startDelayMs`, hashes e versões
- [ ] Biblioteca por origem (`created`, `received`, `participated`)
- [ ] Exclusão transacional de música e arquivos
- [ ] Testes de integração contra SQLite real

### Fase 3 — Sessão e rede local

- [ ] Descoberta mDNS/Bonjour
- [ ] Permissões e multicast lock por plataforma
- [ ] Máquina de estados de sessão
- [ ] Entrada com aprovação do mestre
- [ ] Handshake seguro com biblioteca consolidada
- [ ] Envelope autenticado com HMAC, sequência e replay protection
- [ ] Validação de autoridade por mensagem
- [ ] `estado_sala`, ping/pong e TTL de sessão
- [ ] Transferência manual de mestre
- [ ] Diagnóstico de conectividade
- [ ] Testes de múltiplos dispositivos e perda de conexão

### Fase 4 — Transferência e áudio real

- [ ] Transferência única e em chunks
- [ ] Hash por chunk e hash final
- [ ] Retomada, limpeza de temporários e limites de concorrência
- [ ] Integração de players multipista
- [ ] Aplicação de mix por naipe
- [ ] Preparação e disparo agendado
- [ ] Loop local com timeline compartilhada
- [ ] Áudio em segundo plano Android/iOS
- [ ] Benchmark de sincronização em aparelhos físicos

### Fase 5 — Telas

- [ ] Biblioteca e uso de armazenamento
- [ ] Cadastro de música e validação de arquivos
- [ ] Tela de alinhamento
- [ ] Sala do mestre: aprovação, participantes, reprodução, loop e transferência
- [ ] Tela do cantor: naipe, player e mix
- [ ] Letra sincronizada e dinâmica
- [ ] Tema claro/escuro
- [ ] Acessibilidade mínima e escalabilidade de fonte
- [ ] Layout para tablet

### Fase 6 — Qualidade e release

- [ ] CI com testes, análise estática, auditoria de dependências e varredura de segredos
- [ ] Golden tests de tema e naipes
- [ ] Checklist de segurança por pull request
- [ ] Build/testes em Android e iOS
- [ ] Testes físicos em Android e iOS antes de release
- [ ] Tela de privacidade e exclusão completa de dados

## 15. Critérios de aceite do MVP

- [ ] Até 8 dispositivos aprovados participam da mesma sala
- [ ] Apenas mestre autenticado consegue iniciar áudio, configurar loop, transferir mestre ou encerrar a sala
- [ ] Mensagem alterada, sem HMAC válido ou repetida não altera o estado da sessão
- [ ] Participante não aprovado não recebe acesso à sessão nem a arquivos
- [ ] Início de áudio fica dentro de 100 ms entre dispositivos em cenário de rede definido
- [ ] Áudio carregado continua mesmo se a rede cair
- [ ] Loop mantém alinhamento das faixas e continua localmente
- [ ] Arquivo transferido só aparece na biblioteca após hash final válido
- [ ] Falhas de transferência não deixam arquivos parciais acessíveis
- [ ] Exclusão remove metadados, arquivos e temporários relacionados
- [ ] App toca com tela bloqueada em Android e iOS
- [ ] Interface funciona com fontes ampliadas e não depende somente de cor
- [ ] CI executa testes e verificações de qualidade nas duas plataformas
