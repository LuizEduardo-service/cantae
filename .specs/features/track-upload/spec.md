# Cadastrar música e enviar faixas (track-upload) Specification

## Problem Statement

Hoje não existe jeito de criar uma música no app:
- **Biblioteca vazia:** "Cadastrar primeira música" abre o Detalhe com o id falso `new`, que cai em "música não encontrada".
- **"Enviar faixa":** no Detalhe, no Modo solo sem faixas e no Alinhamento, o botão abre a tela "em breve".

O RF13 (Must) pede cadastrar música com um arquivo por naipe, validando formato, tamanho e integridade. O RF16 (Must) pede Playback opcional. O RF17 (Must) pede naipes customizados reutilizáveis.

O domínio tem `Naipe.custom`, sem nome, e não há seletor de arquivos no projeto. Também não existe seção no UI_SPEC para essa tela.

## Goals

- [ ] A pessoa cria uma música com nome e autor e envia a faixa de cada naipe, do Playback e de naipes extras com nome livre.
- [ ] A pessoa envia, troca ou remove faixas de uma música que ela criou.
- [ ] Um arquivo só entra na biblioteca se for áudio de verdade, dentro do limite de tamanho, e se a cópia guardada tiver o mesmo hash do original.
- [ ] Um naipe extra criado numa música pode ser escolhido de novo em outra.

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Studio (cortar um áudio em várias faixas) | Feature própria (`prd-cantae-studio-corte-audio.md`). |
| Gravar áudio pelo microfone | Não pedido no PRD. |
| Renomear ou apagar naipes extras da lista reutilizável | O RF17 pede criar e reutilizar; gerenciar a lista fica para depois. |
| Marcar naipe extra como responsável por linha da letra | O Editor de letra só usa os 4 naipes padrão; mudar isso é outra feature. |
| Cor própria por naipe extra | O design system só tem cores para os 4 naipes; extras usam o selo neutro (ver Assumptions). |
| Apagar do disco arquivos que nenhuma faixa usa mais | Limpeza de armazenamento é da tela de Privacidade. |
| Editar nome e autor de uma música recebida | Música recebida é só leitura (UI_SPEC §6.3). |
| Converter formatos de áudio | O app guarda o arquivo como veio. |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Escopo | Cadastrar música (nome, autor) + enviar, trocar e remover faixas; a mesma tela edita as faixas de uma música existente | Decisão do usuário | y |
| Seletor de arquivo | Pacote `file_picker` (emenda a AD-004) | Decisão do usuário | y |
| Extras | Playback opcional (1 por música) e naipes extras com nome livre, reutilizáveis | Decisão do usuário | y |
| Formatos aceitos | MP3, M4A/AAC e WAV, conferidos pelo conteúdo do arquivo (assinatura), não só pela extensão | Formatos que o `just_audio` toca nos dois sistemas; RNF-SEC-06 pede "formato real" | n: assumido |
| Tamanho máximo | 100 MB por arquivo; arquivo vazio é recusado | Mesmo limite da transferência entre aparelhos (`ChunkPlanner.maxTransferableSizeBytes`), senão a faixa não poderia ser enviada para a sala | n: assumido |
| Integridade | O app calcula o SHA-256 do arquivo escolhido; ao salvar, copia para a pasta da biblioteca (`library/tracks/<sha256>.<ext>`) e só usa a cópia se o hash dela for igual | PRD: "arquivo entra na biblioteca apenas após hash final válido"; reaproveita o endereçamento por conteúdo da transferência | n: assumido |
| Trabalho pesado | Ler e calcular o hash roda fora da thread de interface | CLAUDE.md e PRD | y: segue o PRD |
| Nome da música | Obrigatório, 1 a 80 caracteres | Precisa aparecer na Biblioteca | n: assumido |
| Autor | Opcional, até 80 caracteres | O campo existe na música e aparece no Detalhe; nem toda música tem autor conhecido | n: assumido |
| Salvar sem faixas | Permitido; a música aparece como "Incompleta" | O Detalhe já trata música incompleta | n: assumido |
| Nome de naipe extra | 1 a 24 caracteres, sem repetir (ignorando maiúsculas) nem usar o nome de um naipe padrão ou "Playback" | Evita dois "Mezzo" diferentes e confusão com os padrão | n: assumido |
| Naipes extras por música | Até 4 | Limite simples para caber na tela e no mix; RF17 não fixa número | n: assumido |
| Selo do naipe extra | Selo neutro com a inicial do nome | O design system só tem cores para os 4 naipes; "naipe = cor + letra/nome" continua valendo pela letra e pelo nome | n: assumido |
| Trocar ou remover faixa já salva | Pede confirmação (`ConfirmSheet`); a faixa trocada volta a atraso 0 | PRD UX: "substituir faixa" exige confirmação; o atraso era do arquivo antigo | n: assumido |
| Sair com alterações não salvas | Pede confirmação para descartar | Mesmo padrão do Alinhamento (UI_SPEC §6.5) | n: assumido |
| Mais de uma faixa por naipe | Não: cada naipe padrão, o Playback e cada naipe extra têm no máximo uma faixa | RF13: "uma faixa de áudio por naipe" | y: segue o PRD |

**Open questions:** none; all resolved or logged above.

---

## User Stories

### P1: Cadastrar uma música com faixas ⭐ MVP

**User Story**: Como regente, quero criar uma música e enviar a faixa de cada naipe, para o grupo ensaiar com ela.

**Why P1**: Sem isso nenhuma música entra no app.

**Acceptance Criteria**:

1. WHEN a pessoa toca "Cadastrar primeira música" na Biblioteca vazia THEN o sistema SHALL abrir a tela "Nova música".
2. The system SHALL mostrar os campos "Nome" (obrigatório) e "Autor" (opcional), os 4 naipes padrão, o Playback (opcional) e "Naipes extras".
3. WHEN a pessoa toca "Escolher arquivo" num naipe THEN o sistema SHALL abrir o seletor de arquivos do sistema, filtrado para áudio.
4. WHEN o arquivo escolhido é válido THEN o sistema SHALL mostrar na linha do naipe o nome do arquivo e o tamanho em MB.
5. WHEN a pessoa toca "Salvar música" com nome válido THEN o sistema SHALL copiar cada arquivo para a pasta da biblioteca, conferir o hash da cópia, gravar a música como criada por ela e abrir o Detalhe da música.
6. IF o nome estiver vazio ou passar de 80 caracteres THEN o sistema SHALL mostrar o limite junto ao campo e manter "Salvar música" desabilitado.
7. WHILE salva, o sistema SHALL mostrar o botão em andamento e não aceitar um segundo toque.

**Independent Test**: com um seletor falso que devolve um MP3 de 2 MB, criar "Ave Verum Corpus" com a faixa de Soprano, salvar e conferir no repositório a música com uma faixa de Soprano cujo arquivo está em `library/tracks/<sha256>.mp3`.

---

### P2: Validar o arquivo

**User Story**: Como regente, quero que o app recuse arquivos que não são áudio, grandes demais ou corrompidos, para não descobrir o problema no meio do ensaio.

**Why P2**: RF13 e RNF-SEC-06. Depende do fluxo de P1.

**Acceptance Criteria**:

1. IF o arquivo não for MP3, M4A/AAC nem WAV pelo conteúdo (mesmo que a extensão diga o contrário) THEN o sistema SHALL recusar com "Este arquivo não é um áudio aceito (MP3, M4A ou WAV)." e não mudar a faixa do naipe.
2. IF o arquivo tiver mais de 100 MB THEN o sistema SHALL recusar com "Arquivo maior que 100 MB." e não mudar a faixa.
3. IF o arquivo estiver vazio ou não puder ser lido THEN o sistema SHALL recusar com "Não foi possível ler este arquivo." e não mudar a faixa.
4. WHILE o arquivo é conferido, o sistema SHALL mostrar a linha do naipe em andamento ("Conferindo arquivo…"), com a leitura e o hash fora da thread de interface.
5. IF, ao salvar, o hash da cópia for diferente do original ou a cópia falhar THEN o sistema SHALL apagar a cópia, não gravar a música e mostrar "Não foi possível salvar a música. Tente de novo.".
6. WHEN a pessoa cancela o seletor THEN o sistema SHALL NOT mudar nada.

**Independent Test**: escolher um arquivo `.mp3` que na verdade é texto e conferir a recusa; escolher um WAV de 101 MB (esparso) e conferir a recusa; simular cópia corrompida e conferir que a música não foi gravada e a cópia sumiu.

---

### P3: Playback e naipes extras

**User Story**: Como regente, quero acrescentar o Playback e naipes além dos 4 padrão (como "Solista" ou "Mezzo"), e reaproveitar esses nomes em outras músicas.

**Why P3**: RF16 e RF17 (Must). Usa o mesmo fluxo de arquivo.

**Acceptance Criteria**:

1. The system SHALL oferecer uma linha "Playback (opcional)" com o mesmo fluxo de arquivo dos naipes.
2. WHEN a pessoa toca "Adicionar naipe" THEN o sistema SHALL abrir uma folha com os naipes extras já criados no aparelho (que ainda não estão na música) e o campo "Novo naipe".
3. WHEN a pessoa escolhe um naipe extra existente ou cria um com nome válido THEN o sistema SHALL acrescentar uma linha desse naipe, sem arquivo, pronta para "Escolher arquivo".
4. IF o nome novo estiver vazio, passar de 24 caracteres, repetir um naipe extra existente (ignorando maiúsculas) ou um nome reservado (Soprano, Contralto, Tenor, Baixo, Playback) THEN o sistema SHALL mostrar o motivo e não criar.
5. WHERE a música já tem 4 naipes extras, the system SHALL desabilitar "Adicionar naipe" com a frase "Até 4 naipes extras por música.".
6. WHEN a música é salva THEN o sistema SHALL guardar os naipes extras novos na lista do aparelho, para escolher de novo em outras músicas.
7. The system SHALL mostrar o naipe extra com um selo neutro com a inicial e o nome, no Detalhe, no Modo solo, no Alinhamento e nesta tela.
8. WHEN a pessoa remove a linha de um naipe extra THEN o sistema SHALL tirar o naipe desta música, sem apagá-lo da lista do aparelho.

**Independent Test**: criar o naipe "Solista" na música A, salvar; abrir a música B, tocar "Adicionar naipe" e conferir "Solista" na lista; tentar criar "tenor" e conferir a recusa.

---

### P4: Enviar, trocar ou remover faixas de uma música existente

**User Story**: Como regente, quero completar ou corrigir as faixas de uma música que eu já criei.

**Why P4**: As telas existentes já levam a "Enviar faixa"; sem isso o botão continua morto.

**Acceptance Criteria**:

1. WHEN a pessoa toca "Enviar faixa" num naipe do Detalhe THEN o sistema SHALL abrir a tela "Faixas" daquela música e abrir em seguida o seletor de arquivos para aquele naipe.
2. WHEN a pessoa toca "Enviar faixa" no Modo solo sem faixas ou no Alinhamento sem faixas THEN o sistema SHALL abrir a tela "Faixas" daquela música.
3. The system SHALL mostrar na tela "Faixas" o nome, o autor e as faixas atuais, com "Trocar" e "Remover" em cada faixa existente.
4. WHEN a pessoa troca ou remove uma faixa já salva THEN o sistema SHALL pedir confirmação; WHEN confirma THEN a mudança SHALL valer na tela até salvar.
5. WHEN a música é salva THEN o sistema SHALL manter o atraso das faixas que não mudaram, zerar o atraso das trocadas e manter a letra, o andamento e a origem da música.
6. WHEN a pessoa sai com alterações não salvas THEN o sistema SHALL pedir confirmação para descartá-las.
7. IF a música não existir THEN o sistema SHALL mostrar "Música não encontrada" com "Voltar à Biblioteca"; IF a leitura falhar THEN o sistema SHALL mostrar o erro com "Tentar de novo".
8. IF a música foi recebida de uma sala THEN o sistema SHALL mostrar que ela é só leitura e não permitir mudar faixas.

**Independent Test**: com uma música salva com Soprano (atraso 400 ms) e Tenor, trocar o Tenor, salvar e conferir Soprano com 400 ms, Tenor novo com 0 ms e a letra intacta.

---

## Edge Cases

- WHEN o mesmo arquivo é escolhido para dois naipes THEN o sistema SHALL aceitar (mesmo hash, um só arquivo no disco).
- WHEN um arquivo já existe na biblioteca com o mesmo hash THEN o sistema SHALL reaproveitar o arquivo existente em vez de copiar de novo.
- WHEN a pessoa escolhe outro arquivo enquanto um ainda é conferido no mesmo naipe THEN o sistema SHALL ficar só com o último.
- IF o seletor falhar (permissão ou erro do sistema) THEN o sistema SHALL mostrar "Não foi possível abrir os arquivos." e manter a tela.
- WHEN a tela abre em 360 dp com fonte a 130 % THEN tudo SHALL caber sem corte, com alvos de toque de pelo menos 44 dp.

---

## Implicit-Requirement Dimensions Sweep

| Dimension | Resolution |
| --------- | ---------- |
| Input validation & bounds | Nome 1–80; autor ≤ 80; naipe extra 1–24, sem repetir nem reservado; até 4 extras; arquivo ≤ 100 MB, não vazio, formato pelo conteúdo |
| Failure / partial-failure | Arquivo recusado (P2-AC1..3); seletor falhou (Edge); cópia ou hash diferente ao salvar não grava nada e apaga a cópia (P2-AC5); leitura da música falhou (P4-AC7) |
| Idempotency / retry / duplicates | Mesmo arquivo em dois naipes e arquivo já na biblioteca reaproveitam o mesmo arquivo (Edge); salvar de novo regrava a mesma música |
| Auth boundaries & rate limits | Música recebida é só leitura (P4-AC8) |
| Concurrency / ordering | Escolher de novo durante a conferência fica com o último (Edge); toque duplo em salvar bloqueado (P1-AC7) |
| Data lifecycle / expiry | Arquivos ficam no sandbox do app; naipes extras persistem no aparelho; arquivos órfãos ficam para a Privacidade (Out of Scope) |
| Observability | N/A because o app não tem log/telemetria e o PRD proíbe envio para servidor |
| External-dependency failure | Seletor do sistema e sistema de arquivos (P2, Edge) |
| State-transition integrity | Faixa: vazia → conferindo → escolhida (ou recusada) → salva; trocar/remover salva pede confirmação (P4-AC4) |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| UPL-01 | P1-AC1: Biblioteca abre "Nova música" | Execute | In Tasks |
| UPL-02 | P1-AC2: campos e seções da tela | Execute | In Tasks |
| UPL-03 | P1-AC3/AC4: escolher arquivo e mostrar nome e tamanho | Execute | In Tasks |
| UPL-04 | P1-AC5: salvar copia, confere hash, grava e abre o Detalhe | Execute | In Tasks |
| UPL-05 | P1-AC6: limites do nome e do autor | Execute | In Tasks |
| UPL-06 | P1-AC7: salvando sem toque duplo | Execute | In Tasks |
| UPL-07 | P2-AC1: formato pelo conteúdo | Execute | In Tasks |
| UPL-08 | P2-AC2/AC3: tamanho e arquivo ilegível | Execute | In Tasks |
| UPL-09 | P2-AC4: conferência fora da thread de interface, com estado | Execute | In Tasks |
| UPL-10 | P2-AC5: hash da cópia diferente não grava nada | Execute | In Tasks |
| UPL-11 | P2-AC6 + Edge: cancelar o seletor e falha do seletor | Execute | In Tasks |
| UPL-12 | P3-AC1: Playback opcional | Execute | In Tasks |
| UPL-13 | P3-AC2/AC3: adicionar naipe extra existente ou novo | Execute | In Tasks |
| UPL-14 | P3-AC4/AC5: regras do nome e limite de 4 | Execute | In Tasks |
| UPL-15 | P3-AC6/AC8: lista reutilizável no aparelho | Execute | In Tasks |
| UPL-16 | P3-AC7: selo e nome do naipe extra nas telas | Execute | In Tasks |
| UPL-17 | P4-AC1/AC2: entradas "Enviar faixa" levam à tela da música | Execute | In Tasks |
| UPL-18 | P4-AC3/AC4: trocar e remover com confirmação | Execute | In Tasks |
| UPL-19 | P4-AC5: salvar preserva atraso, letra, andamento e origem | Execute | In Tasks |
| UPL-20 | P4-AC6: descartar alterações pede confirmação | Execute | In Tasks |
| UPL-21 | P4-AC7/AC8: não encontrada, erro, música recebida | Execute | In Tasks |
| UPL-22 | Edge: mesmo arquivo em dois naipes e arquivo já na biblioteca | Execute | In Tasks |
| UPL-23 | Edge: escolher de novo durante a conferência; 360 dp a 130 % | Execute | In Tasks |

**ID format:** `UPL-[NUMBER]`

**Status values:** Pending → In Design → In Tasks → Implementing → Verified

**Coverage:** 23 total, 0 mapped to tasks, 23 unmapped

---

## Success Criteria

- [ ] Da Biblioteca vazia até uma música com 4 naipes salva em menos de 2 minutos (com os arquivos à mão).
- [ ] Um arquivo de texto renomeado para `.mp3` nunca entra na biblioteca.
- [ ] Um naipe extra criado numa música aparece para escolher na próxima.
