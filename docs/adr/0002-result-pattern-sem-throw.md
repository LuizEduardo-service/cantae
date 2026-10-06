# 0002 — `Result<S, F>` como padrão de erro; sem `throw` no domínio

**Status:** Aceita
**Data:** Fase 0

## Contexto

Com `domain/` isolado de Flutter e infraestrutura (ver [0001](0001-clean-architecture-4-camadas.md)), ainda é possível que erros de negócio se propaguem de forma invisível via `throw`, obrigando quem chama a adivinhar quais exceptions podem ocorrer e forçando try/catch espalhados sem garantia em tempo de compilação.

## Decisão

Todas as funções de domínio retornam `Result<S, F extends Failure>` (sealed class com variantes `Success`/`Failure`). Não há `throw` em nenhum lugar sob `lib/domain/`. Toda falha carrega uma subclasse tipada de `Failure` com um `code` string não-vazio.

```dart
// Correto
Result<Song, SongFailure> loadSong(SongId id) { ... }

// Nunca no domínio
Song loadSong(SongId id) throws SongNotFoundException { ... }
```

A UI mapeia códigos de `Failure` para mensagens visíveis ao usuário; o domínio nunca conhece localização.

## Consequências

- Positivas: caminhos de erro ficam explícitos no sistema de tipos — o compilador força quem chama a tratar o caso de falha.
- Positivas: desacopla mensagens de erro (localização, apresentação) da lógica de negócio.
- Negativas: verboso comparado a exceptions — toda função de domínio precisa de um tipo de `Failure` dedicado e o chamador precisa desembrulhar o `Result` explicitamente.

## Alternativas consideradas

- **Exceptions custom + try/catch:** rejeitada porque exceptions cruzam fronteiras de camada de forma invisível (nada no tipo de retorno indica que uma função pode falhar), o que é incompatível com a regra de pureza de domínio.
