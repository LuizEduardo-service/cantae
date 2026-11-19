# Cantaê — Design System

> Direção visual: **Quieto**. Calmo, claro e rápido de ler. A interface se apaga para a letra e o som aparecerem.
> Fonte da verdade visual: canvas "Cantaê — UX/UI" (prancha *Fundamentos visuais*).
> Complementa: `UI_GUIDELINES.md`, `COMPONENTS.md`, `UI_SPEC.md`.

---

## 1. Identidade

| Aspecto | Decisão |
|---|---|
| Personalidade | Sereno, preciso, sem ruído. Ferramenta de ensaio, não vitrine. |
| Contexto de uso | Celular na mão ou na estante, fone no ouvido, leitura de relance (1–2 s). |
| O que evitar | Gradientes, brilhos, neon, roxo/ciano "tech", ícone de estrelinha, emoji na UI, cards simétricos repetidos, sombras pesadas. |
| Assinatura | Uma única cor de ação (verde‑escuro), superfícies brancas arredondadas sobre fundo cinza‑claro, números em fonte mono. |

### Cinco regras da direção
1. **Uma ação principal por tela**, em verde. Todo o resto é neutro.
2. **Todo toque responde**: estado selecionado, aviso curto (toast) ou progresso.
3. **Naipe é cor + letra ou nome. Estado é ícone + texto.** Nunca só cor.
4. **Ação que não volta atrás pede confirmação** e explica a consequência.
5. **Padrões nativos**: campo de busca, controle segmentado, slider do sistema, folha inferior (bottom sheet).

---

## 2. Cores

Todas as cores são **tokens semânticos**. Nenhum widget usa hex diretamente.

### 2.1 Tema claro (padrão)

| Token | Hex | Uso |
|---|---|---|
| `bg` | `#F4F4F2` | Fundo de tela |
| `surface` | `#FFFFFF` | Cards, grupos de lista, folhas, item destacado |
| `fillField` | `#E8E8E4` | Campo de busca, trilho do controle segmentado |
| `fillMuted` | `#E6E6E2` | Pílulas de navegação no topo (Voltar, Sair, Exportar) |
| `fillSecondary` | `#E2E2DD` | Botão secundário de rodapé |
| `fillOnSurface` | `#F0F0EC` | Botões/chips dentro de um `surface` |
| `divider` | `#EFEFEB` | Separador entre linhas dentro de um grupo |
| `segmentSelected` | `#FFFFFF` | Segmento ativo (+ sombra `0 1 2 rgba(0,0,0,.08)`) |
| `text` | `#1B1B1B` | Texto principal |
| `textBody` | `#3E3E3A` | Parágrafos de apoio |
| `text2` | `#55554F` | Metadados, legendas, rótulos de seção |
| `text3` | `#6E6E69` | Linhas de letra já cantadas, placeholders de tempo |
| `textDisabled` | `#8A8A85` | Chevron `›`, anel de rádio inativo |
| `accent` | `#0E5E4B` | Ação principal, progresso, switch ligado |
| `onAccent` | `#FFFFFF` | Texto sobre `accent` |
| `accentSoft` | `#E3EFEA` | Status positivo, "Sincronizado", avatar, loop ativo |
| `onAccentSoft` | `#0B4A3B` | Texto sobre `accentSoft` |
| `accentTrack` | `#BFDCD1` | Região de loop na barra de progresso |
| `warningBg` | `#FBF0DC` | Fundo de banner de atenção |
| `onWarning` | `#4A2C00` | Texto sobre `warningBg` |
| `warningInline` | `#8A5200` | Status de atenção dentro de lista ("falta Tenor") |
| `dangerBg` | `#FBE9E7` | Fundo de banner de erro / botão destrutivo tonal |
| `onDanger` | `#8C1D16` | Texto sobre `dangerBg` |
| `dangerSolid` | `#B3261E` | Botão destrutivo final (confirmação), borda de erro |
| `toastBg` | `#1B1B1B` | Fundo do toast |
| `onToast` | `#FFFFFF` | Texto do toast |
| `scrim` | `rgba(20,20,18,.45)` | Fundo atrás de folhas inferiores |

### 2.2 Tema escuro

Quase preto **esverdeado** — nunca azul‑marinho ou roxo.

| Token | Hex |
|---|---|
| `bg` | `#121413` |
| `surface` | `#1E2120` |
| `fillField` / `fillOnSurface` | `#262A28` |
| `fillMuted` / `fillSecondary` | `#2A2E2C` |
| `divider` | `#2A2E2C` |
| `segmentSelected` | `#3A3F3C` |
| `text` | `#EDEDEA` |
| `textBody` | `#C9CCC8` |
| `text2` | `#A6A9A5` |
| `text3` | `#8B8E8A` |
| `accent` | `#5FC4A3` |
| `onAccent` | `#0B1F18` |
| `accentSoft` | `#173A30` |
| `onAccentSoft` | `#9FE3CB` |
| `accentTrack` | `#1F4A3D` |
| `warningBg` / `onWarning` | `#3A2E14` / `#F2CC85` |
| `dangerBg` / `onDanger` | `#3D1D1A` / `#FFB4A8` |
| `dangerSolid` | `#B3261E` (texto `#FFFFFF`) |
| `toastBg` / `onToast` | `#EDEDEA` / `#121413` |
| `switchOff` | `#4A4F4C` (claro: `#B8B8B2`) |

### 2.3 Cores de naipe

Sempre acompanhadas da **letra** (S, C, T, B) ou do **nome**.

| Naipe | Claro (texto `#FFFFFF`) | Escuro (texto `#121413`) |
|---|---|---|
| Soprano — S | `#B4512A` | `#E59B78` |
| Contralto — C | `#8E3B66` | `#D98BB8` |
| Tenor — T | `#2F5F92` | `#8DB6E6` |
| Baixo — B | `#3C6B47` | `#8FC79C` |
| Todos | `#1B1B1B` | `#EDEDEA` |
| Naipe sem faixa | contorno tracejado 1,5 px `text2`, letra `text2`, fundo transparente | idem |
| Visitante — V | contorno sólido 1,5 px `text2` | idem |

### 2.4 Contraste

Meta mínima **WCAG AA**: 4,5:1 para texto até 18 px, 3:1 para texto ≥ 24 px ou 18,66 px bold. Todos os pares acima foram escolhidos para passar no tema em que são usados. Ao criar um par novo, valide antes de usar.

---

## 3. Tipografia

| Família | Uso | Pesos |
|---|---|---|
| **Geist** | Toda a interface, títulos e letra cantada | 400, 500, 600, 700 |
| **Geist Mono** | Todo número que importa: tempo (`0:52`), código de sala (`4827`), atraso (`0:00.4`), latência (`18 ms`), tamanho (`436 MB`), contagens | 400, 500 |

Fontes empacotadas no app (não depender de rede). Toda medida escala com a fonte do sistema (RNF‑UX‑03).

### Escala

| Token | Tamanho / peso / tracking / altura | Onde |
|---|---|---|
| `display` | 72 / 700 / −3 / 0.95 | Só material de marca |
| `titleHub` | 34 / 700 / −1.2 / 1.0 | Título da Biblioteca |
| `titlePage` | 30–32 / 700 / −1.0 / 1.1 | Títulos de telas secundárias |
| `titleRoom` | 26 / 700 / −0.8 / 1.1 | Nome da música dentro de sala |
| `titleSheet` | 22–26 / 700 / −0.6 / 1.15 | Título de folha de confirmação |
| `lyricActive` | 30 / 600 / −0.8 / 1.15 | Linha que está sendo cantada |
| `lyricNext` | 20 / 500 / −0.2 | Próxima linha (`text2`) |
| `lyricPast` | 20 / 400 / −0.2 | Linha anterior (`text3`) |
| `listTitle` | 17 / 600 / −0.3 | Título em linha de lista |
| `body` | 16 / 400 / 0 / 1.5 | Texto corrido |
| `bodySmall` | 15 / 400 / 0 / 1.5 | Texto em banners |
| `label` | 14 / 500–600 | Botões pequenos, pílulas |
| `caption` | 13 / 400–600 | Metadados, rótulos de seção (`text2`, 600) |
| `monoLarge` | 64 / 500 / +8 | Código da sala |
| `monoInput` | 28 / 500 / +8 | Campo de código |
| `mono` | 13–15 / 400–500 | Tempos, latência, MB |

Rótulos de seção usam **frase normal** ("Naipes", "Seus dados"), não CAIXA ALTA.

---

## 4. Espaçamento e layout

Base de **4 pt**.

| Token | Valor | Uso |
|---|---|---|
| `space1` | 4 | Gap entre segmentos, letras de naipe |
| `space2` | 8 | Gap entre botões lado a lado, entre cards de lista |
| `space3` | 12 | Gap entre ícone e texto em linha |
| `space4` | 16 | Padding interno de card/banner |
| `space5` | 20 | **Margem lateral da tela** |
| `space6` | 24 | Separação entre seções |
| `safeTop` | 52–56 | Topo (inclui área segura) |
| `safeBottom` | 28–32 | Rodapé (inclui área segura) |

- Layout de referência: **390 × 844** (celular). Tablet é melhoria futura.
- Rodapé de ação fixo: padding `12–16` em cima, `28–32` embaixo.
- Grupos de lista têm margem lateral 20 e padding interno 14.

## 5. Raios

| Token | Valor | Uso |
|---|---|---|
| `radiusXs` | 6–8 | Selo de naipe (18–26 px) |
| `radiusSegment` | 9 | Segmento interno |
| `radiusSm` | 12 | Trilho segmentado, campo de busca |
| `radiusMd` | 14 | Input, toast |
| `radiusLg` | 16–18 | Card, grupo de lista, banner |
| `radiusXl` | 20–24 | Card de destaque (código da sala, mix) |
| `radiusSheet` | 28 (só topo) | Folha inferior |
| `radiusPill` | altura ÷ 2 | Todos os botões |

## 6. Elevação

Plana. Profundidade vem de **contraste de superfície** (`surface` sobre `bg`), não de sombra.
Exceções: segmento selecionado (`0 1px 2px rgba(0,0,0,.08)`), polegar de switch/slider (`0 1px 3px rgba(0,0,0,.2)`), scrim de folha.

## 7. Iconografia

- Traço 2 px, pontas arredondadas, 18–24 px, cor herdada do texto.
- Ícone **acompanha** texto; não substitui o verbo. Ícone sozinho só em: voltar (com rótulo), busca, avatar.
- Proibido: estrelinha/sparkles, emoji, ícones coloridos decorativos.

## 8. Movimento (diretriz)

- Troca de estado de seleção: 120–150 ms, ease‑out.
- Toast: entra 180 ms, permanece ~2,5 s, sai 150 ms.
- Folha inferior: 220 ms, curva padrão da plataforma.
- Linha ativa da letra: transição de 200 ms; respeitar "reduzir movimento" do sistema (troca sem animação).

## 9. Implementação sugerida (Flutter)

- `lib/presentation/theme/cantae_colors.dart` — `ThemeExtension<CantaeColors>` com todos os tokens da seção 2 (claro e escuro).
- `lib/presentation/theme/cantae_typography.dart` — `ThemeExtension` com a escala da seção 3.
- `lib/presentation/theme/cantae_spacing.dart` — constantes de espaço e raio.
- `lib/presentation/theme/voice_part_colors.dart` — mapa naipe → cor por tema.
- `ThemeMode` controlado pela preferência do Perfil (Claro / Escuro / Sistema).

> Estrutura proposta; ajuste aos padrões já existentes no repositório.
