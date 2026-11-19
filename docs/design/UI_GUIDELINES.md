# Cantaê — UI Guidelines

> Regras de construção de telas e de comportamento dos componentes.
> Tokens em `DESIGN_SYSTEM.md`. Componentes em `COMPONENTS.md`. Telas em `UI_SPEC.md`.

---

## 1. Princípios

### UI
- **Hierarquia visual.** Em cada tela, a ordem de leitura é: título → conteúdo principal → ação principal. Use tamanho e peso antes de cor.
- **Consistência.** O mesmo componente tem a mesma aparência e o mesmo comportamento em todas as telas. Não crie variações locais.
- **Contraste e legibilidade.** AA no mínimo. Corpo ≥ 15 px. Letra cantada ativa ≥ 30 px.
- **Feedback visual.** Toda interação responde em até 100 ms (estado visual) e, quando muda algo fora da tela, com um toast.
- **Espaço em branco.** Agrupe pelo espaço; separe grupos com 18–24 px. Evite bordas para separar o que o espaço já separa.

### UX
- **Centralidade no usuário.** Mestre conduz sob pressão; Cantor olha de relance; Visitante só acompanha. Projete para esses três momentos.
- **Menos esforço.** Ações críticas do ensaio (iniciar, pausar, mutar, trocar naipe) em **um toque**, sem navegação.
- **Padrões da plataforma.** Voltar no topo esquerdo, folhas inferiores para confirmação, controles nativos para slider e switch.
- **Controle e prevenção de erro.** Sempre há saída. Ações irreversíveis pedem confirmação explicando a consequência.
- **Acessibilidade.** Leitor de tela, contraste, fonte do sistema e área de toque ≥ 44×44 dp.

---

## 2. Estrutura de uma tela

```
┌──────────────────────────────┐
│ Topo: [Voltar/Sair]   [Status│ ← pílulas 44 px, margem 20
│ Título                        │ ← titlePage / titleHub
│ Subtítulo ou metadado         │
│                               │
│ Conteúdo (grupos em surface)  │ ← rolável
│                               │
│ Rodapé: [Secundária][Primária]│ ← fixo, 54–60 px
└──────────────────────────────┘
```

- **Topo:** à esquerda, navegação ("‹ Biblioteca", "Voltar", "Sair", "Cancelar"). À direita, status ou ação de contexto.
- **Rodapé fixo:** no máximo **uma** ação primária (verde). Secundária à esquerda, primária à direita e mais larga.
- **Conteúdo:** grupos `surface` com raio 16–18, linhas separadas por `divider`.

## 3. Botões

| Tipo | Quando | Visual |
|---|---|---|
| Primário | A ação principal da tela | `accent`, texto `onAccent`, pílula, 54–60 px |
| Secundário | Alternativa à principal | `fillSecondary`, texto `text` |
| Tonal | Ação dentro de card | `fillOnSurface` ou `accentSoft` |
| Destrutivo tonal | Iniciar algo destrutivo | `dangerBg`, texto `onDanger` |
| Destrutivo sólido | Confirmação final | `dangerSolid`, texto branco |
| Desabilitado | Pré‑condição não atendida | `fillField`, texto `text2` + **explicação visível** |

Regras:
- O rótulo é **um verbo + objeto**: "Criar sala", "Pedir entrada", "Salvar atrasos", "Iniciar para todos". Nunca "OK", "Enviar" genérico ou só ícone.
- Nunca dois botões primários na mesma tela.
- Botão bloqueado nunca fica escondido sem contexto nem clicável sem efeito: aparece desabilitado com uma frase do porquê.

## 4. Feedback

| Situação | Resposta |
|---|---|
| Seleção (segmento, rádio, naipe) | Muda o estado visual na hora |
| Ação com efeito fora da tela (trocar naipe, silenciar, mudar tema, compartilhar nome) | **Toast** com o resultado em linguagem simples |
| Operação longa (backup, carregar faixa, exportar) | Barra de progresso + texto do que está acontecendo |
| Erro recuperável | Banner na tela com o que houve + ação que resolve |
| Ação destrutiva | Folha de confirmação (seção 6) |

Toast: uma frase, sem jargão. Ex.: "Agora você ouve a faixa de Tenor." / "Seu fone está em silêncio. A música segue para o grupo."

## 5. Estados obrigatórios

Toda tela com dados implementa os estados abaixo (detalhe por tela em `UI_SPEC.md`).

| Estado | Regra |
|---|---|
| **Vazio** | Ícone discreto + título curto + uma frase + **uma** ação que resolve. Nunca tela em branco. |
| **Carregando** | Esqueleto ou texto "Carregando…" com o que está carregando. |
| **Degradado (rede)** | Banner com: o que houve, o efeito para o usuário, o que fazer. Ex.: "Pedro está com conexão fraca. O áudio dele já carregou e continua tocando. Peça para chegar perto do roteador." |
| **Erro** | Banner `dangerBg` com causa e ação ("Tentar de novo", "Abrir ajustes"). |
| **Sem permissão** | Explica a permissão em termos de benefício e leva aos ajustes. |
| **Bloqueado por papel** | Texto fixo dizendo quem pode fazer a ação ("Escolher naipe fica com os cantores"). |

## 6. Confirmações e ações destrutivas

- Use **folha inferior** com scrim.
- Título em pergunta ("Sair do ensaio?", "Apagar tudo deste aparelho?").
- Corpo explica a consequência concreta e como voltar atrás, se der.
- Botão seguro (Cancelar/Continuar) à esquerda; destrutivo à direita em `dangerSolid`.
- **Irreversível e amplo** (apagar todos os dados): duas etapas; a segunda exige digitar `APAGAR`. O botão final fica desabilitado até a palavra estar correta.
- Sobrescrever dados (importar e substituir): o destrutivo aparece como opção em vermelho e mostra um aviso do que será perdido antes de confirmar.

## 7. Naipes e papéis

- Selo de naipe: quadrado arredondado com letra em Geist Mono. Em seletores, ponto de cor + nome.
- Naipe sem faixa: contorno tracejado. Nunca cinza sólido (parece desabilitado).
- Papéis: **Mestre** controla sala; **Cantor** escolhe naipe e mix; **Visitante** só acompanha. A interface do Visitante não mostra controles que ele não pode usar, e diz por quê em uma frase fixa.

## 8. Letra sincronizada

- Três níveis: anterior (`lyricPast`, `text3`), **ativa** (`lyricActive` dentro de `surface`, com selo do naipe e dinâmica), próxima (`lyricNext`, `text2`).
- Quando a próxima linha é do naipe do usuário, o rótulo diz "Próxima é sua" na cor do naipe.
- Dinâmica por extenso: "piano", "mezzo-forte" (não só "p", "mf").
- A letra nunca é coberta por controles; o painel de mix fica abaixo.

## 9. Tema

- Claro é o padrão. Escuro é escolhido no Perfil (Claro / Escuro / Sistema).
- Todas as telas de ensaio (Cantor, Mestre, Visitante, Modo solo) e a Biblioteca já têm versão escura projetada.
- Nunca use cor fixa em widget: sempre token. Uma tela nova deve funcionar nos dois temas sem código extra.

## 10. Texto e tom

- Português do Brasil, frases curtas, segunda pessoa ("você").
- Diga o que aconteceu e o que fazer. Evite códigos técnicos na UI (mDNS, RTT, hash) — use "rede", "latência", "pacote íntegro".
- Proibido: "Potencialize", "Desbloqueie", "inteligente", "mágico", nomes de teste (Jane Doe, Acme). Use dados plausíveis do domínio.
- Números sempre em Geist Mono.

## 11. Acessibilidade — checklist por tela

- [ ] Todo elemento interativo ≥ 44×44 dp.
- [ ] Botões só com ícone têm rótulo acessível.
- [ ] Seletores expõem papel (radio, tab, switch) e estado (selecionado, ligado).
- [ ] Status dinâmico (sincronizado, aguardando, erro) anunciado como região viva.
- [ ] Contraste AA nos dois temas.
- [ ] Layout aguenta fonte do sistema em 130% sem cortar texto.
- [ ] Nenhuma informação só por cor.
- [ ] Animações respeitam "reduzir movimento".
