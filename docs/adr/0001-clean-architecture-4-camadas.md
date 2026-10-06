# 0001 — Clean Architecture em 4 camadas com pureza de domínio

**Status:** Aceita
**Data:** Fase 0

## Contexto

Cantaê é um app Flutter local-first com regras de negócio de áudio (mixagem por naipe, loop, timeline) que precisam ser testáveis de forma independente da UI, do SQLite e da camada de rede/P2P. Sem uma separação explícita, é comum lógica de negócio vazar para dentro de widgets ou de código de infraestrutura (plugins, sockets), tornando-a difícil de testar isoladamente e acoplada a detalhes de plataforma.

## Decisão

O projeto é estruturado em quatro camadas estritas:

```
presentation/     → widgets Flutter, providers Riverpod, navegação
domain/           → lógica de negócio pura. ZERO dependências de Flutter, plugins ou rede
data/             → implementações de repositório, DTOs, mappers
infrastructure/   → SQLite, TCP, mDNS, filesystem, crypto, engine de áudio
```

Regra dura: `domain/` deve compilar com `dart compile` (sem o Flutter SDK). Qualquer import de `package:flutter`, de um plugin ou de uma lib de rede dentro de `domain/` é uma violação bloqueante de CI.

**Enforcement:** `scripts/check_layers.py --root .` — sai com código 1 em qualquer violação, integrado ao CI.

## Consequências

- Positivas: regras de negócio de áudio (mix calculator, loop controller, timeline) são testáveis sem o Flutter SDK, o que acelera a suíte de testes de domínio e garante portabilidade.
- Positivas: força o uso do padrão `Result<S, F>` (ver [0002](0002-result-pattern-sem-throw.md)) já que `domain/` não pode depender de exceptions de infraestrutura.
- Negativas: exige disciplina extra ao adicionar features — é preciso decidir explicitamente em qual camada cada trecho de código pertence antes de escrever (ver skill `flutter-clean-architecture`).
- Trade-off aceito: mais arquivos/indireção do que uma estrutura "tudo junto", mas necessário para o requisito de portabilidade e testabilidade do domínio de áudio.

## Alternativas consideradas

- **MVC/MVVM simples sem camada de domínio isolada:** rejeitada porque não impede lógica de mixagem de áudio de acabar acoplada a `just_audio` ou a widgets, dificultando testes determinísticos de sincronização.
