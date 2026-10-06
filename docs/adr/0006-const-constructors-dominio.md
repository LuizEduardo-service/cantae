# 0006 — Construtores `const` em todas as entidades de domínio

**Status:** Aceita
**Data:** Fase 1

## Contexto

Entidades de domínio (Song, Part/Naipe, etc.) são criadas repetidamente em fixtures de teste e em código de produção. Sem `const`, cada fixture é avaliada em tempo de execução, e o lint `prefer_const_constructors` (parte do padrão de qualidade do projeto) não passa.

## Decisão

Todos os construtores de entidade de domínio são `const`. Condições de assert usam comparação inteira (`field.length > 0`) em vez de `field.isNotEmpty`, para compatibilidade com avaliação em tempo de compilação (`const`). Testes que intencionalmente disparam asserts de entrada inválida omitem `const` e adicionam `// ignore: prefer_const_constructors`.

## Consequências

- Positivas: fixtures e testes são avaliados em tempo de compilação, e o lint `prefer_const_constructors` passa sem exceções nos construtores válidos.
- Negativas: validação de invariantes via `assert` fica restrita a expressões compatíveis com `const` (ex.: comparações inteiras), o que é menos expressivo do que métodos como `isNotEmpty`.
- Negativas: testes que violam invariantes propositalmente precisam de um `// ignore` explícito, o que é um pequeno ponto de atrito a cada novo teste desse tipo.

## Alternativas consideradas

- **Construtores não-const com validação via métodos de instância (`isNotEmpty`, etc.):** rejeitada por não satisfazer `prefer_const_constructors` e por impedir fixtures compile-time, mais lentas em larga escala na suíte de testes de domínio.
