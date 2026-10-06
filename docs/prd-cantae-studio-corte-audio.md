# Adendo ao PRD — Studio de Corte e Extração de Faixas

Este documento complementa o PRD consolidado do Cantaê. A funcionalidade de Studio permite que o maestro transforme um único áudio, no qual os naipes aparecem sequencialmente, em faixas independentes vinculadas à mesma música.

## Objetivo

Permitir importar um áudio-fonte único — MP3, M4A/AAC, WAV ou formato explicitamente suportado — selecionar os intervalos correspondentes aos naipes e gerar faixas locais prontas para alinhamento, reprodução, transferência, exportação e backup.

Exemplo: se um arquivo contém Soprano de 0:00 a 5:00, Contralto de 5:00 a 10:00, Tenor de 10:00 a 15:00 e Baixo de 15:00 a 20:00, o maestro cria quatro segmentos, associa cada segmento a seu naipe e o Studio produz quatro arquivos de faixa.

## Requisitos funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF63 | Importar um arquivo-fonte único com trechos sequenciais de vários naipes | Must |
| RF64 | Exibir forma de onda e duração do arquivo-fonte no Studio | Must |
| RF65 | Criar, editar e excluir segmentos com início, fim e naipe de destino | Must |
| RF66 | Ajustar início/fim de segmento por alças na waveform e por campos `mm:ss.s` | Must |
| RF67 | Reproduzir prévia de um segmento antes da extração | Must |
| RF68 | Extrair cada segmento aprovado como nova faixa privada da música | Must |
| RF69 | Permitir associar um segmento a Playback ou a qualquer naipe padrão/customizado | Should |
| RF70 | Impedir segmentos inválidos, sobrepostos para o mesmo destino ou sem naipe | Must |
| RF71 | Permitir substituir uma faixa existente somente após confirmação explícita | Must |
| RF72 | Manter o arquivo-fonte temporariamente para reedição, com opção de remoção manual | Should |
| RF73 | Sugerir limites de corte por detecção de silêncio, sem aplicar mudanças automaticamente | Could |
| RF74 | Exibir progresso, cancelamento e erro acionável durante extração | Must |
| RF75 | Gerar hash, duração e metadados da faixa extraída antes de disponibilizá-la na biblioteca | Must |

## Requisitos não funcionais

| ID | Requisito | Meta |
|---|---|---|
| RNF-STUDIO-01 | Parsing, waveform, hashing e exportação de áudio não bloqueiam a thread de UI | Operações pesadas em isolate/processo nativo |
| RNF-STUDIO-02 | Segmentos usam precisão interna em milissegundos | Persistência em `int` de ms |
| RNF-STUDIO-03 | Nenhuma extração deixa arquivo parcial disponível na biblioteca | Escrita temporária + movimento atômico |
| RNF-STUDIO-04 | O app valida tamanho, MIME real e decodificação do áudio importado | Rejeitar extensão enganosa ou arquivo inválido |
| RNF-STUDIO-05 | Arquivo-fonte e faixas geradas ficam no sandbox privado do app | Sem pasta pública de mídia |
| RNF-STUDIO-06 | Cancelamento remove temporários ou mantém rascunho explicitamente recuperável | Sem vazamento de arquivos |

## Conceitos e regras

### Arquivo-fonte e faixa gerada

- **Arquivo-fonte:** áudio importado que contém um ou vários naipes em sequência.
- **Segmento:** intervalo `[inicioMs, fimMs)` selecionado sobre o arquivo-fonte.
- **Faixa gerada:** arquivo local produzido a partir de um segmento e associado a um naipe.
- **Alinhamento:** ajuste posterior entre as faixas geradas, via `startDelayMs` na timeline compartilhada.

O corte ocorre antes do alinhamento. O corte remove conteúdo fora do intervalo escolhido; `startDelayMs` posiciona a faixa resultante na timeline musical e não deve ser usado para substituir a operação de edição.

### Segmentos e sobreposição

O Studio pode ter segmentos adjacentes ou sobrepostos no arquivo-fonte, pois o maestro pode querer extrair trechos alternativos. Entretanto:

- Não permitir dois segmentos ativos destinados ao mesmo `naipeId` sem que o usuário escolha explicitamente manter versões alternativas.
- Exibir sobreposição visual e exigir confirmação antes de extrair segmentos sobrepostos.
- Exigir `fimMs > inicioMs`.
- Exigir início maior ou igual a zero e fim menor ou igual à duração do arquivo-fonte.
- Exigir duração mínima configurável, inicialmente 500 ms.
- Rejeitar segmento sem naipe de destino.

### Substituição de faixa

Quando existir uma faixa para o mesmo naipe, o Studio oferece:

1. **Substituir faixa existente:** requer confirmação; move a anterior para rascunho recuperável até salvar a música.
2. **Manter como alternativa:** cria variante identificada, fora da reprodução padrão até o maestro escolhê-la.
3. **Cancelar:** não altera a música.

Não sobrescrever arquivo ou metadados em silêncio.

## Fluxo do Studio

```text
Criar/editar música
  -> Abrir Studio
  -> Importar arquivo-fonte
  -> Validar tipo, tamanho, duração e decodificação
  -> Gerar waveform
  -> Criar segmentos e associar naipes
  -> Ajustar limites por alça ou campos de tempo
  -> Ouvir prévia do segmento
  -> Confirmar extração
  -> Gerar arquivos temporários, validar e calcular hashes
  -> Resolver conflitos de faixas existentes
  -> Mover arquivos para biblioteca privada
  -> Abrir tela de alinhamento fino
  -> Salvar música
```

O maestro pode sair do Studio antes de salvar. Nesse caso, o app deve perguntar se deseja descartar ou guardar o rascunho de edição local. Rascunhos não participam de salas, exportações nem backup automático até serem salvos como música válida.

## Interface proposta

### Tela principal

```text
Studio — Extrair naipes

Arquivo-fonte: arranjo-completo.mp3
Duração: 24:35.2

[ waveform com régua de tempo e playhead ]
|---- Soprano ----| |--- Contralto ---| |--- Tenor ---| |-- Baixo --|

Segmentos
Soprano      00:00.0 -> 05:23.5   [Prévia] [Editar] [Remover]
Contralto    05:23.5 -> 11:45.2   [Prévia] [Editar] [Remover]
Tenor        11:45.2 -> 18:10.0   [Prévia] [Editar] [Remover]
Baixo        18:10.0 -> 24:35.2   [Prévia] [Editar] [Remover]

[Adicionar segmento] [Sugerir silêncios] [Extrair faixas] [Salvar rascunho]
```

### Interações obrigatórias

- Arrastar alças de início/fim do segmento com feedback visual e snapping opcional ao playhead.
- Digitar valores em `mm:ss.s`; a edição textual e a waveform alteram a mesma fonte de verdade em milissegundos.
- Tocar prévia do intervalo selecionado, com playhead limitado ao segmento.
- Exibir duração de cada segmento e duração total do arquivo-fonte.
- Exibir alerta antes de segmento sobreposto, curto demais ou associado a faixa já existente.
- Exibir progresso por faixa durante extração e permitir cancelar antes da finalização atômica.

## Implementação técnica

### Estratégia de extração

A extração deve ser local e offline. Usar um componente nativo de processamento consolidado, como FFmpeg integrado por uma dependência Flutter mantida e compatível com Android/iOS, ou implementação nativa equivalente.

Há dois modos técnicos possíveis:

| Modo | Uso | Vantagem | Risco/limite |
|---|---|---|---|
| Stream copy | Trechos em formatos compatíveis e cortes aproximados | Muito rápido, não reencoda | Corte pode cair no keyframe mais próximo; precisão limitada em alguns codecs |
| Reencodificação | Quando o corte precisa ser preciso em milissegundos | Precisão e compatibilidade previsíveis | Mais CPU, bateria, tempo e possível perda de qualidade |

**Decisão do MVP:** tentar stream copy apenas se o codec e a precisão tolerada permitirem; caso contrário, usar reencodificação para um formato interno padronizado. Para evitar faixas que começam ou terminam fora do ponto escolhido, a prioridade é a precisão musical, não a velocidade.

### Formato interno

Definir um formato de saída padronizado após teste em aparelhos reais, preferencialmente AAC/M4A para equilíbrio entre compatibilidade, tamanho e reprodução móvel. WAV só deve ser aceito como origem; não deve ser formato padrão de saída no MVP por ocupar muito espaço.

### Pipeline seguro

1. Selecionar arquivo via picker do sistema.
2. Copiar para diretório temporário privado controlado pelo app.
3. Validar tamanho máximo, MIME real, duração e capacidade de decodificação.
4. Gerar waveform resumida em isolate/processo nativo.
5. Persistir apenas rascunho de segmentos até o usuário confirmar.
6. Para cada segmento: validar limites, extrair para arquivo temporário e calcular SHA-256.
7. Validar duração efetiva e arquivo decodificável.
8. Mover atomicamente a faixa para o diretório privado definitivo.
9. Persistir `SongTrack` e hash em transação SQLite.
10. Limpar temporários; em falha, desfazer persistência ou manter rascunho sem publicar faixa.

Argumentos de ferramenta/processamento não podem ser montados por concatenação insegura. Caminhos, nomes e tempos devem ser passados como parâmetros validados, e o nome do arquivo final deve ser gerado pelo app usando UUID.

### Detecção de silêncio

A detecção de silêncio é opcional e apenas sugestiva. Pode usar análise local para marcar regiões candidatas; o maestro precisa revisar e confirmar cada limite. Não executar corte automático, pois pausas musicais e respirações podem ser confundidas com divisões entre naipes.

## Modelo de dados

### AudioSourceDraft

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | UUID | Identificador do rascunho |
| `songDraftId` | UUID | Música em edição |
| `privatePath` | string | Caminho privado do arquivo-fonte |
| `originalFileName` | string | Nome somente para exibição |
| `mimeType` | string | Tipo validado |
| `durationMs` | int | Duração detectada |
| `fileSize` | int | Tamanho em bytes |
| `fileSha256` | string | Hash da origem |
| `status` | enum | `imported`, `processing`, `ready`, `failed`, `discarded` |

### AudioSegmentDraft

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | UUID | Identificador do segmento |
| `audioSourceDraftId` | UUID | Arquivo-fonte |
| `targetVoicePartId` | UUID ou `playback` | Destino da faixa |
| `startMs` | int | Início inclusivo |
| `endMs` | int | Fim exclusivo |
| `label` | string opcional | Nome de exibição |
| `status` | enum | `draft`, `validated`, `extracted`, `failed`, `discarded` |
| `generatedTrackId` | UUID opcional | Faixa criada após sucesso |

### Atualização de SongTrack

| Campo | Tipo | Observação |
|---|---|---|
| `id` | UUID | Identificador da faixa |
| `songId` | UUID | Música |
| `naipeId` | UUID ou `playback` | Destino |
| `arquivoAudioPath` | string | Caminho privado definitivo |
| `startDelayMs` | int | Alinhamento posterior na timeline compartilhada |
| `sourceType` | enum | `imported_full`, `extracted_segment`, `received`, `package_imported` |
| `sourceFileSha256` | string opcional | Hash da origem, se preservada |
| `segmentStartMs` | int opcional | Auditoria do corte |
| `segmentEndMs` | int opcional | Auditoria do corte |
| `fileSize` | int | Tamanho final |
| `fileSha256` | string | Hash final |
| `durationMs` | int | Duração real extraída |

`segmentStartMs` e `segmentEndMs` são rastreabilidade do Studio, não substituem `startDelayMs`.

## Segurança e privacidade

- Aceitar somente tipos de áudio definidos e efetivamente decodificáveis.
- Impor tamanho máximo por arquivo-fonte, segmento e música; valores definitivos devem ser definidos após benchmark de aparelhos alvo.
- Não usar nome/extensão como validação de segurança.
- Gerar nomes internos com UUID e nunca reutilizar caminho informado pelo usuário como caminho de destino.
- Processar e salvar arquivos apenas em áreas privadas do app.
- Não transmitir arquivo-fonte bruto em salas por padrão; somente faixas finais aprovadas podem ser compartilhadas.
- Não incluir fontes temporárias ou rascunhos não salvos no backup automático ou pacote `.cantae`.
- Permitir que o maestro apague o arquivo-fonte após salvar faixas; manter por padrão apenas enquanto houver rascunho ou até decisão explícita de retenção.
- Logs técnicos podem registrar código de erro, tamanho e tipo, mas não caminho absoluto, conteúdo, letra ou nome original completo quando desnecessário.

## Trade-offs

| Tema | Decisão MVP | Motivo |
|---|---|---|
| Corte local | Sim | Mantém operação offline e local-first |
| Reencodificação | Usar quando necessária para precisão | Corte musical preciso é mais importante que velocidade |
| Stream copy | Permitido apenas quando compatível | Reduz custo, mas não pode comprometer o corte |
| Detecção de silêncio | Sugestão opcional | Ajuda o maestro sem produzir cortes errados automaticamente |
| Arquivo-fonte | Rascunho privado com remoção manual | Permite refazer recortes; não entra em backup automático por padrão |
| Múltiplos segmentos no mesmo naipe | Exigir escolha explícita de variante | Evita ambiguidade na reprodução padrão |
| Editor de áudio avançado | Fora do MVP | Fade, normalização, equalização e efeitos aumentam muito a complexidade |

## Tasks detalhadas

### Domínio e persistência

- [ ] **TS1 — Criar entidades de rascunho.** Implementar `AudioSourceDraft` e `AudioSegmentDraft` com validações de intervalo. **Concluído quando:** segmentos com início negativo, fim menor/igual ao início, duração curta ou fim acima da fonte são rejeitados.
- [ ] **TS2 — Atualizar `SongTrack`.** Adicionar `sourceType`, rastreabilidade do segmento, duração e hashes. **Concluído quando:** migração aditiva preserva faixas existentes com valores padrão compatíveis.
- [ ] **TS3 — Criar regras de conflito de naipe.** Detectar faixa existente para o destino e retornar opções de substituir, variante ou cancelar. **Concluído quando:** nenhuma operação de extração sobrescreve faixa sem decisão explícita.
- [ ] **TS4 — Persistir rascunhos.** Salvar fonte e segmentos sem publicá-los na biblioteca. **Concluído quando:** fechar/reabrir o app recupera rascunho ou permite descartá-lo explicitamente.

### Infraestrutura de áudio

- [ ] **TS5 — Avaliar biblioteca de processamento.** Fazer spike técnico de FFmpeg/biblioteca nativa em Android e iOS. **Concluído quando:** há prova de geração de trecho preciso, cancelamento, progresso e compatibilidade com formatos alvo.
- [ ] **TS6 — Implementar validador de origem.** Validar MIME real, decodificação, duração, tamanho e espaço livre. **Concluído quando:** arquivos renomeados, corrompidos ou não-áudio são rejeitados antes de entrar no Studio.
- [ ] **TS7 — Implementar waveform.** Gerar dados resumidos da forma de onda fora da UI. **Concluído quando:** arquivos longos não travam a interface e a waveform pode ser recarregada do cache privado.
- [ ] **TS8 — Implementar preview limitado.** Reproduzir somente o intervalo selecionado. **Concluído quando:** player para automaticamente no fim do segmento e respeita alteração dos limites.
- [ ] **TS9 — Implementar extração para temporário.** Criar arquivo por segmento usando estratégia de corte precisa. **Concluído quando:** cada saída tem duração dentro da tolerância definida e é decodificável.
- [ ] **TS10 — Implementar integridade e publicação atômica.** Calcular SHA-256, validar e mover arquivo para destino final. **Concluído quando:** erro/cancelamento não deixa faixa parcial disponível.
- [ ] **TS11 — Implementar limpeza.** Remover temporários e controlar retenção da fonte. **Concluído quando:** exclusão de rascunho/falha libera espaço e não apaga faixa já publicada.
- [ ] **TS12 — Spike de desempenho.** Medir corte de fontes curtas e longas em aparelhos Android/iOS alvo. **Concluído quando:** limites de tamanho/formato e estratégia de reencodificação são documentados no PRD.

### Interface Studio

- [ ] **TS13 — Construir tela Studio.** Mostrar fonte, duração, waveform, playhead e lista de segmentos. **Concluído quando:** estado de rascunho é visível e navegável em celular e tablet.
- [ ] **TS14 — Implementar criação/edição de segmento.** Adicionar alças e campos `mm:ss.s` ligados ao mesmo estado em ms. **Concluído quando:** alterações por arrasto e digitação permanecem sincronizadas.
- [ ] **TS15 — Implementar associação de naipe.** Permitir escolher naipe padrão, customizado ou Playback. **Concluído quando:** UI impede salvar segmento sem destino.
- [ ] **TS16 — Implementar alertas de conflito/sobreposição.** Mostrar sobreposição, faixa existente, duração inválida e falta de espaço. **Concluído quando:** usuário entende a causa e tem ação segura disponível.
- [ ] **TS17 — Implementar extração em lote.** Extrair segmentos aprovados com progresso individual e cancelamento. **Concluído quando:** falha em uma faixa não corrompe as já concluídas e resultado é claramente exibido.
- [ ] **TS18 — Integrar com alinhamento.** Após extração, abrir ou oferecer tela de alinhamento de faixas. **Concluído quando:** o mestre pode testar mix, aplicar `startDelayMs` e salvar música completa.
- [ ] **TS19 — Implementar sugestão de silêncios.** Exibir sugestões revisáveis, sem alterar segmentos existentes automaticamente. **Concluído quando:** recurso pode ser desligado e todas as mudanças exigem confirmação.

### Testes e aceite

- [ ] **TS20 — Testes unitários.** Cobrir limites, conflitos, transições de estado e decisões de retenção. **Concluído quando:** casos de borda são automatizados.
- [ ] **TS21 — Testes de integração.** Cobrir importar -> segmentar -> prévia -> extrair -> alinhar -> salvar -> tocar. **Concluído quando:** fluxo passa com quatro naipes e Playback opcional.
- [ ] **TS22 — Testes de segurança.** Testar extensão falsa, arquivo corrompido, caminho malicioso, cancelamento e falta de espaço. **Concluído quando:** nenhum cenário cria arquivo fora do sandbox ou faixa parcial publicada.
- [ ] **TS23 — Teste físico em plataformas.** Validar em Android e iOS reais com MP3, M4A/AAC e WAV. **Concluído quando:** limitações reais e mensagens de erro estão documentadas.

## Critérios de aceite

- [ ] Maestro importa um áudio-fonte válido e visualiza duração e waveform.
- [ ] Maestro cria segmentos por alças ou campos de tempo, associa cada um a um naipe e ouve prévia.
- [ ] Segmentos inválidos, sem destino ou sobrepostos de modo ambíguo não podem ser extraídos sem ação explícita.
- [ ] O sistema gera arquivos independentes para os naipes com hash e duração validados.
- [ ] Arquivos resultantes podem ser alinhados, tocados no modo solo, usados em sala, exportados e incluídos em backup após a música ser salva.
- [ ] Cancelamento ou erro não deixa arquivos parciais na biblioteca.
- [ ] Uma faixa existente nunca é sobrescrita sem confirmação.
- [ ] Fonte temporária, rascunhos e logs não são compartilhados automaticamente nem entram em exportação/backup padrão.
