# Cantaê — Componentes

> Componentes reutilizáveis da camada de apresentação. Tokens em `DESIGN_SYSTEM.md`.
> Nomes sugeridos em inglês para o código (`lib/presentation/widgets/`); rótulos de UI em português.
> Todo componente funciona nos temas claro e escuro sem parâmetros extras.

---

## Navegação e estrutura

### `CantaeScaffold`
Estrutura base de tela: topo, conteúdo rolável, rodapé fixo opcional.
- Props: `top` (widgets à esquerda/direita), `title`, `subtitle`, `body`, `footer`.
- Margem lateral 20; topo com área segura; rodapé `12/28`.

### `NavPill`
Pílula de navegação no topo.
- Variantes: `back` ("‹ Biblioteca", "‹ Voltar"), `exit` ("Sair"), `cancel` ("Cancelar"), `action` ("Exportar", "Importar").
- Altura 44, fundo `fillMuted`, texto `label` 15/500.
- `exit` em sala abre `ConfirmSheet` antes de sair.
- Sem `onTap`, fica desabilitada: texto `textDisabled` e semântica "não habilitado". Usar junto de uma frase que explique o motivo (ex.: banner "Sem faixas para ouvir" no Editor de letra).

### `StatusPill`
Status à direita do topo.
- Variantes: `synced` (accentSoft, ponto accent, "Sincronizado"), `weak` (warningBg, "Conexão fraca"), `offline` (dangerBg, "× Sem rede"), `neutral` ("Visitante", "Sala 4827").
- Altura 44, região viva para leitor de tela.
- Implementado até agora: só `neutral` (fundo `fillMuted`, texto `text2`), usado no Modo solo ("Funciona offline"). As demais variantes chegam com as telas de sala.

### `SectionLabel`
Rótulo de seção ("Naipes", "Seus dados"). `caption` 13/600 `text2`. Pode ter texto auxiliar à direita ("3 de 4 com faixa").

---

## Ações

### `PrimaryButton`
- Fundo `accent`, texto `onAccent`, altura 54 (56–60 no rodapé de sala), pílula.
- Estados: normal, pressionado (−6% luminosidade), carregando (texto + indicador), desabilitado (`fillField`/`text2`).

### `SecondaryButton`
Fundo `fillSecondary`, texto `text`. Mesmas medidas do primário.

### `TonalButton`
Dentro de cards ou ao lado do botão primário (ações de loop do Modo solo). Fundo `fillOnSurface` (neutro, texto `text`) ou `accentSoft` (positivo, texto `onAccentSoft`). Altura 44, pílula, ocupa a largura disponível.
- Desabilitado (sem `onPressed`): fundo `fillField`, texto `textDisabled`, semântica "não habilitado".
- Props: `label`, `onPressed`, `positive`.

### `DestructiveButton`
- `tonal`: `dangerBg` + `onDanger` — inicia o fluxo ("Apagar desta música", "Encerrar").
- `solid`: `dangerSolid` + branco — confirma o fluxo ("Sair da sala", "Apagar definitivamente").

---

## Seleção e entrada

### `SegmentedControl`
- Trilho `fillField`, raio 12, padding 3. Segmento ativo `segmentSelected` + sombra leve; inativo transparente `text2`.
- Altura do segmento 38–42. Expõe semântica de tab ou radio.
- Usos: filtros da Biblioteca, tema, naipe do Cantor (com ponto de cor + nome).
- Opção com rótulo curto visível (ex.: letra do naipe "S") pode ter um `semanticLabel` com o nome completo ("Soprano"): o leitor de tela anuncia o nome completo, não a letra.

### `SearchField`
Fundo `fillField`, raio 12, altura 44, ícone de lupa `text2`, placeholder "Buscar música ou autor".

### `TextInput`
Fundo `surface` (ou `bg` dentro de card), borda 2 px `accent` quando focado, `dangerSolid` em erro, raio 14, altura 52.

### `CodeInput`
Campo de 4 dígitos. Geist Mono 28/+8, teclado numérico, `maxLength 4`. Borda de erro quando o código não existe.

### `ChoiceTile` (rádio em card)
Card `surface`, altura ≥ 56, borda 2 px `accent` quando selecionado. Usado no naipe padrão do Onboarding e nas opções de conflito de importação (opção destrutiva em `dangerSolid`).

### `CantaeSwitch`
52×32, trilho `accent` (ligado) / `switchOff` (desligado), polegar branco. Mudança dispara toast quando afeta outras pessoas ("Meu nome visível nas salas").

### `MixSlider`
Slider nativo, cor `accent`. Rótulos "Minha voz" ↔ "Coro" e valor textual ao centro ("mais você", "meio a meio", "mais coro"). Altura de toque 32+.

---

## Listas e dados

### `GroupedList` + `ListRow`
- Grupo `surface` raio 18, padding horizontal 14; linhas min 50–64 com `divider` entre elas (não após a última).
- `ListRow`: leading (selo/ícone), título, subtítulo, trailing (valor mono, chevron `›`, botão tonal).

### `SongRow`
Linha da Biblioteca.
- Título `listTitle`, subtítulo "Autor · status". Status de atenção em `warningInline` 600.
- Trailing: 4 `VoicePartBadge` (S C T B), faltantes tracejados.
- Item em destaque (último ensaio) com fundo `surface`.

### `VoicePartBadge`
- Tamanhos: 18, 22, 26. Raio 6–8. Letra Geist Mono.
- Variantes: `filled` (cor do naipe), `missing` (tracejado), `visitor` (contorno sólido, "V"), `all` (tinta, "Todos").
- `custom`: naipe extra ("Solista"), cores neutras de `all` com a inicial do nome. O nome sempre aparece ao lado do selo.
- `NaipeBadge` (`naipe_labels.dart`) escolhe a variante a partir do naipe da faixa. `naipe_labels.dart` é o único lugar que converte naipe em nome ("Baixo", "Playback", o nome do naipe extra).

### `ParticipantRow`
Sala do Mestre. Selo de naipe, nome, "papel · estado" (pronto em `accent`, carregando em `text2`), latência em mono à direita (`warningInline` 600 quando fraca).

### `RoomTile`
Sala encontrada na rede: código em mono, nome do Mestre, "música · N pessoas", chevron. Borda 2 px `accent` quando é a sala do pedido em andamento.

### `StatTile`
Número grande em mono (`monoStat`, 26) + legenda (`caption`, `text2`), em cartão `surface` de raio `radiusMd`. Usado no Histórico, três lado a lado. Leitor de tela: um só item "legenda: valor". O número encolhe para caber numa linha.

### `StorageBar`
Barra segmentada por categoria (tons de `accent`) com legenda e valores em MB.

### `TrackAlignRow`
Alinhamento de faixas: selo, nome, campo de atraso (`0:00.4`, mono), botões M (mudo) e S (solo) via `MuteSoloToggle`, forma de onda deslocada. Mudo esmaece a onda (25%); solo destaca o card com borda `accent`.

### `MuteSoloToggle`
Botão quadrado 44×44 de mudo ("M") ou solo ("S") de uma faixa. Usado em `TrackAlignRow` e `MixTrackRow`.
- Desligado: fundo `fillField`, texto `text2`. Ligado: fundo `accentSoft`, texto `onAccentSoft`.
- Leitor de tela: nome completo ("Mudo", "Solo") e estado ligado/desligado (toggled), nunca só pela cor.
- Props: `label`, `semanticLabel`, `active`, `onTap`.

---

## Reprodução e letra

### `LyricView`
Componente compartilhado por Cantor, Mestre, Visitante e Modo solo.
- `LyricLine.past` — `lyricPast`, `text3`.
- `LyricLine.active` — card `surface` com selo do naipe + "Naipe · dinâmica" e texto `lyricActive`.
- `LyricLine.next` — rótulo "Próxima" ou "Próxima é sua" (cor do naipe do usuário) + texto `lyricNext`.
- Sem dinâmica, o card mostra selo + nome do naipe; sem naipe, só a dinâmica. A linha atual é região viva com rótulo "Linha atual".
- Antes da primeira linha, só "Próxima" + a primeira linha; na última linha, não há "Próxima".
- Props: `lines` (só linhas com tempo, na ordem da letra), `cursor` (de `LyricCursor.at`, no domínio), `userVoicePart` (opcional; sem ele, não há "Próxima é sua").

### `LyricLineRow`
Editor de letra: uma linha da letra, com edição inline.
- **Recolhida:** tempo em mono (`0:05.3`, ou "—" se não marcada), texto (`text3` "Linha sem texto" quando vazio), selo do naipe + "Naipe · dinâmica" (só o selo, sem dinâmica; só a dinâmica, sem naipe), botão "Editar" (≥ 44 dp).
- **Expandida:** campo "Texto da linha" (1–200 caracteres), `SegmentedControl` de naipe S · C · T · B · — (leitor de tela: Soprano, Contralto, Tenor, Baixo, Nenhum), campo "Dinâmica (opcional)" (até 40; vazio = sem dinâmica). Botão vira "Concluir". Valor inválido volta ao último válido ao sair do campo, sem erro modal.
- **Linha atual:** borda 2 px `accent`, texto em `listTitle` (mais forte) e rótulo semântico "Linha atual" — nunca só cor.
- Props: `line` (`LyricDraftLine`), `isCurrent`, `expanded`, `onToggleExpanded`, `onTextChanged`, `onNaipeChanged`, `onDynamicsChanged`.

### `MixTrackRow`
Modo solo, "Mix por naipe": uma faixa por linha.
- Selo do naipe + nome (`listTitle`); a faixa de Playback mostra "Playback", sem selo.
- `MuteSoloToggle` M e S à direita; abaixo, slider de volume `accent` (0–100 %).
- Leitor de tela: "Volume do Tenor", valor "30 %"; M e S anunciam ligado/desligado.
- Props: `naipe` (nulo = Playback ou Metrônomo), `label`, `volume`, `muted`, `solo`, `onVolumeChanged`, `onMuteToggled`, `onSoloToggled`, `showSolo` (padrão verdadeiro; falso esconde o S, como na linha "Metrônomo").

### `PlaybackProgress`
Tempo atual e total em mono, trilho `divider/fillSecondary`, preenchido `accent`, região de loop `accentTrack`. Abaixo, texto opcional "Repetindo trecho 0:41–1:12 · Mestre: Marina".
- Arrastar a barra mostra o tempo do dedo e só busca (`onSeek`) ao soltar, uma vez.
- Leitor de tela: "Posição da música", valor em `m:ss.s`.
- Props: `positionMs`, `durationMs`, `onSeek`, `loopStartMs`, `loopEndMs` (região só com os dois), `caption`.

### `RoomCodeDisplay`
Card `surface` raio `radiusXl`: rótulo "Código da sala", código em `monoLarge` (encolhe para caber em fonte grande), botão "Copiar" (`TonalButton`, toast "Código copiado"), frase de instrução. Leitor de tela: um só item "Código da sala 4 8 2 7", dígito por dígito.

---

## Avisos e sobreposições

### `InlineBanner`
Card com raio 16, padding 14–16.
- Variantes: `info` (surface), `success` (accentSoft), `warning` (warningBg), `error` (dangerBg).
- Estrutura: título 17/700 · texto 15 · ação opcional (botão tonal na cor do texto).

### `Toast`
Fundo `toastBg`, texto `onToast`, raio 14, check à esquerda. Posição: abaixo do topo nas telas de sala; acima do rodapé nas demais. Some sozinho em ~2,5 s.

### `ConfirmSheet`
Folha inferior com scrim.
- Props: `title`, `message`, `safeLabel`, `destructiveLabel`, `steps` (1 ou 2), `typedConfirmation` (ex.: `"APAGAR"`).
- Na etapa 2, botão final desabilitado até a confirmação digitada coincidir (sem diferenciar maiúsculas).

### `TempoSheet`
Folha inferior "Andamento" do metrônomo (RF50), com o mesmo scrim e raio da `ConfirmSheet`.
- Campos numéricos em mono: "BPM" (30–300) e "Tempos por compasso" (2–16), com o limite em `dangerSolid` abaixo do campo quando inválido ("Entre 30 e 300", "Entre 2 e 16").
- `SegmentedControl` "Com acento" / "Sem acento".
- [P] "Salvar andamento", desabilitado enquanto algum campo é inválido; com carregamento enquanto salva.
- Erro ao salvar: banner de erro na folha, que continua aberta com os valores digitados.
- API: `TempoSheet.show(context, initial:, onSave:)`; `onSave` devolve nulo (fecha) ou a mensagem de erro.

### `EmptyState`
Ícone 72×72 em `accentSoft`, título 28/700, frase, ação primária + secundária opcional.

---

## Convenções de código

- Um widget por arquivo; nome do arquivo em `snake_case`.
- Nenhum `Color(0x...)` fora de `theme/`. Leia de `Theme.of(context).extension<CantaeColors>()`.
- Toda string visível vem do arquivo de localização (pt-BR).
- Cada componente tem um teste de widget cobrindo: estados, tema escuro e semântica de acessibilidade.
