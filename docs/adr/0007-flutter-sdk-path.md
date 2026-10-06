# 0007 — Caminho fixo do SDK Flutter em `D:\flutter\bin`

**Status:** Aceita
**Data:** Fase 1

## Contexto

O Flutter está instalado em um local de nível de usuário (`D:\flutter\bin`), não em um local de sistema. Shells de automação (CI local, scripts) herdam o PATH do sistema, não necessariamente o PATH de usuário, o que causa falha ao invocar `flutter` nesses contextos.

## Decisão

O SDK Flutter vive em `D:\flutter\bin` (PATH de nível de usuário, não PATH de sistema). Shells de automação devem prepender esse caminho ao PATH antes de invocar `flutter`.

## Consequências

- Positivas: documenta explicitamente onde está o SDK, evitando que cada novo script/agente precise redescobrir o caminho por tentativa e erro.
- Negativas: é uma decisão amarrada à máquina de desenvolvimento atual — qualquer novo ambiente (outra máquina, CI remoto) precisa repetir ou adaptar essa configuração de PATH.

## Alternativas consideradas

- **Assumir que `flutter` já está no PATH do shell:** rejeitada porque é falso no ambiente de desenvolvimento atual (instalação de usuário), causando falhas silenciosas de "comando não encontrado" em automações.
