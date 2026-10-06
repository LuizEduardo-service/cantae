# 0004 — Todas as dependências do MVP declaradas no pubspec desde a Fase 0

**Status:** Aceita
**Data:** Fase 0

## Contexto

O roadmap do MVP (Fases 0–6) usa dependências que só serão efetivamente exercitadas em fases futuras (ex.: `just_audio`, `audio_service`, `nsd` só entram em uso pleno na Fase 4 — transferência de arquivo e áudio real). Adicionar dependências de forma incremental, fase a fase, cria risco de conflitos de versão descobertos tarde, quando já há muito código escrito em torno do lockfile existente.

## Decisão

`pubspec.yaml` declara todas as dependências de runtime e dev desde a Fase 0, incluindo as que só serão usadas na Fase 4 (`just_audio`, `audio_service`, `nsd`).

## Consequências

- Positivas: conflitos de versão entre dependências são descobertos e resolvidos no início do projeto, quando o custo de ajuste é baixo.
- Positivas: o lockfile (`pubspec.lock`) fica estável desde o início, evitando que features futuras quebrem build por incompatibilidade de versão transitiva.
- Negativas: dependências não usadas ficam "mortas" no pubspec por várias fases, o que pode confundir quem lê o arquivo sem conhecer o roadmap (mitigado por este ADR e pelo mapeamento de fases em `CLAUDE.md`).

## Alternativas consideradas

- **Adicionar dependências sob demanda, fase a fase:** rejeitada pelo risco de conflitos de versão tardios, quando já existe código construído em torno de uma resolução de dependências diferente.
