# 0005 — E2E como mecanismo primário de verificação; unitários só failure-first

**Status:** Aceita
**Data:** Fase 0

## Contexto

Testes unitários escritos depois do código de produção (descrevendo o comportamento que já existe) tendem a ser baixo-sinal: eles passam a descrever a implementação atual em vez de proteger contra regressões reais, e duplicam cobertura sem adicionar garantia. Ao mesmo tempo, features complexas (sincronização de áudio entre dispositivos, handshake de sessão) só são verdadeiramente validadas ponta a ponta.

## Decisão

- Testes E2E são o mecanismo primário de verificação, usados para confirmar que features complexas funcionam de ponta a ponta. Todo teste E2E deve produzir um artefato verificável e repetível (log, screenshot, saída de assertion) revisável sem precisar re-executar o teste.
- Testes unitários só são escritos quando é necessário testar um sistema isoladamente, e somente seguindo esta ordem: (1) listar todos os modos de falha possíveis, (2) escrever o código que trata essas falhas, (3) escrever o teste que exercita cada modo de falha.
- Nunca escrever testes unitários depois do código já pronto, apenas para descrevê-lo.

## Consequências

- Positivas: testes unitários existentes têm alto sinal — cada um corresponde a um modo de falha identificado antes do código existir, não a uma descrição pós-hoc do comportamento.
- Positivas: E2E captura integração real entre camadas (ex.: sincronização ≤100ms entre até 8 dispositivos), que testes unitários isolados não conseguem validar.
- Negativas: suíte E2E é mais lenta e mais cara de manter que testes unitários tradicionais; exige disciplina para produzir artefatos revisáveis em cada teste.
- Negativas: a ordem "failure-first" para testes de isolamento é mais lenta de aplicar do que escrever teste e código em paralelo sem esse processo.

## Alternativas consideradas

- **TDD unitário tradicional em todas as camadas:** rejeitada como regra geral porque não escala bem para validar comportamento de sincronização P2P e áudio, que é inerentemente um comportamento de sistema integrado, não de unidade isolada.
