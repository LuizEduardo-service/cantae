# 0003 — pyenv local 3.12.3 para scripts Python

**Status:** Aceita
**Data:** Fase 0

## Contexto

O projeto usa scripts Python auxiliares (ex.: verificação de camadas, validação de specs) que precisam rodar de forma idêntica em qualquer máquina de desenvolvimento ou CI. Sem uma versão fixada, variações de ambiente causam erros como `pyenv: no version set` ou comportamento divergente entre versões do Python.

## Decisão

O projeto fixa Python 3.12.3 via `.python-version` (pyenv local). Todos os scripts Python (verificação de camadas, validação de specs) são invocados como `python scripts/check_layers.py` a partir da raiz do projeto.

## Consequências

- Positivas: elimina divergência de versão de Python entre máquinas de desenvolvedores e CI.
- Negativas: exige que todo ambiente novo tenha pyenv instalado e configurado corretamente antes de rodar os scripts.

## Alternativas consideradas

- **Depender do Python global do sistema:** rejeitada pelo risco de inconsistência entre ambientes (Windows/CI) e por já ter causado erros de versão não fixada.
