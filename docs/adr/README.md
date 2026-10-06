# Architecture Decision Records (ADR) — Cantaê

Este diretório contém os registros formais de decisões arquiteturais do projeto Cantaê.

## Convenção

- Um arquivo por decisão: `NNNN-titulo-curto.md` (numeração sequencial, zero-padded).
- Status possíveis: `proposta`, `aceita`, `substituída`, `obsoleta`.
- Toda ADR aceita é também resumida em `.specs/STATE.md` (seção **Decisions**, prefixo `AD-NNN`) para consulta rápida durante o desenvolvimento. O arquivo aqui é a versão completa, com contexto e alternativas consideradas; o STATE.md é o índice operacional.
- Uma ADR não é editada após aceita — mudanças de direção geram uma nova ADR que marca a anterior como `substituída`, com link cruzado.

## Índice

| ID | Título | Status |
|---|---|---|
| [0001](0001-clean-architecture-4-camadas.md) | Clean Architecture em 4 camadas com pureza de domínio | Aceita |
| [0002](0002-result-pattern-sem-throw.md) | `Result<S, F>` como padrão de erro; sem `throw` no domínio | Aceita |
| [0003](0003-pyenv-python-3-12.md) | pyenv local 3.12.3 para scripts Python | Aceita |
| [0004](0004-dependencias-pubspec-fase-0.md) | Todas as dependências do MVP declaradas no pubspec desde a Fase 0 | Aceita |
| [0005](0005-e2e-preferencial-sobre-unitarios.md) | E2E como mecanismo primário de verificação; unitários só failure-first | Aceita |
| [0006](0006-const-constructors-dominio.md) | Construtores `const` em todas as entidades de domínio | Aceita |
| [0007](0007-flutter-sdk-path.md) | Caminho fixo do SDK Flutter em `D:\flutter\bin` | Aceita |
