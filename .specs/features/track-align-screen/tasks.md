# Tela Alinhamento de faixas Tasks

## Execution Protocol (MANDATORY -- do not skip)

Implement these tasks with the `tlc-spec-driven` skill: **activate it by name and follow its Execute flow and Critical Rules.** Do not search for skill files by filesystem path. The skill is the source of truth for the full flow (per-task cycle, sub-agent delegation, adequacy review, Verifier, discrimination sensor).

**If the skill cannot be activated, STOP and tell the user - do not proceed without it.**

---

**Design**: `.specs/features/track-align-screen/design.md`
**Status**: Draft

---

## Test Coverage Matrix

> Generated from codebase sampling (`library-screen`/`song-detail-screen` features) — no project-specific coverage-threshold tool exists. `AGENTS.md` §7 and `docs/design/COMPONENTS.md` ("Cada componente tem um teste de widget cobrindo: estados, tema escuro e semântica de acessibilidade") set the qualitative bar. One new consideration this feature introduces: `lib/infrastructure/audio/multi_track_audio_engine.dart` has **zero existing tests** — this feature's own test-double investment (T1) is what makes testing it possible at all without a real device/platform channel.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Test double (`FakeJustAudioPlatform`) | unit (self-test) | Proves the fake answers `load`/`play`/`pause`/`setVolume`/`seek`/`dispose` and records calls correctly — a floor so it can't silently misreport what `MultiTrackAudioEngine` did | `test/infrastructure/audio/fakes/*_test.dart` | `flutter test test/infrastructure/audio/` |
| Infrastructure (`MultiTrackAudioEngine`, new members) | unit (via the fake platform) | Every new branch: mute on/off per track, solo exclusivity (activating a second solo clears the first), `setTrackStartDelayMs` changes the next `seekAllTo`'s computed local offset, `durationMs` reflects loaded tracks, `positionMs` timeline-converts the reference track's reported position | `test/infrastructure/audio/*_test.dart` | `flutter test test/infrastructure/audio/` |
| Presentation providers (`audioPlaybackEngineProvider`, `TrackAlignNotifier`) | unit (`ProviderContainer`, fake `AudioPlaybackEngine` — the **domain interface**, not `MultiTrackAudioEngine`) | Every spec AC the notifier owns: offset edit + validation, mute/solo + exclusivity at the state level, loop region validation, play/stop calling the engine correctly, save success/failure, unsaved-changes flag | `test/presentation/providers/*_test.dart` | `flutter test test/presentation/providers/` |
| Presentation shared widgets (`TrackAlignRow`, `Toast`) | widget | Per `COMPONENTS.md`: every state/variant, dark theme, accessibility semantics | `test/presentation/widgets/*_test.dart` | `flutter test test/presentation/widgets/` |
| Presentation screens (`TrackAlignScreen`) | widget | All spec states (carregando / sem faixas / erro / carregado / testando) + edição de atraso + mudo/solo + loop + salvar/descartar + confirmação ao voltar | `test/presentation/screens/**/*_test.dart` | `flutter test test/presentation/screens/` |
| Routing (`AppRouter`, `SongDetailScreen`'s "Alinhar entradas") | widget | `track-align` resolves with the route `id`; `SongDetailScreen`'s existing navigation test is updated to assert the `id` is actually passed | `test/presentation/routing/*_test.dart`, `test/presentation/screens/song_detail/*_test.dart` | `flutter test test/presentation/routing/ test/presentation/screens/` |

## Gate Check Commands

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | After a task with only unit tests | `flutter test test/infrastructure/audio/ test/presentation/providers/` |
| Full | After a task with widget tests | `flutter test test/presentation/widgets/ test/presentation/screens/ test/presentation/routing/` |
| Build | After the last task of the feature | `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/` |

---

## Execution Plan

### Phase 1: Fundação (sem dependências entre si)

```
T1
T5
T6
```

### Phase 2: Motor de áudio

```
T1 --> T2
```

### Phase 3: Fiação de apresentação

```
T2 --> T3 --> T4
```

### Phase 4: Tela

```
T4 --> T7
T5 --> T7
T6 --> T7
```

### Phase 5: Roteamento

```
T7 --> T8
```

---

## Task Breakdown

### T1: `FakeJustAudioPlatform` / `FakeAudioPlayerPlatform`

**What**: Test double implementing `just_audio_platform_interface`'s `JustAudioPlatform`/`AudioPlayerPlatform` so `AudioPlayer` (and therefore `MultiTrackAudioEngine`) can run under plain `flutter test` with no real platform channel. Overrides only what the engine actually calls: `init`, `load` (returns a configurable `LoadResponse.duration`), `play`, `pause`, `setVolume`, `seek`, `dispose`; exposes a per-instance `playbackEventMessageStream` the test can push `PlaybackEventMessage`s into, and records every call it receives (for assertions in T2's tests).
**Where**: `test/infrastructure/audio/fakes/fake_just_audio_platform.dart` (new file)
**Depends on**: None
**Reuses**: nothing — first test double of its kind in the project
**Requirement**: enables ALIGN-10 through ALIGN-16 (the real mudo/solo/loop behavior none of them can be tested without this)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `FakeJustAudioPlatform.init(InitRequest)` returns a fresh `FakeAudioPlayerPlatform` per call, tracked in creation order (`created` list) so a test can correlate the Nth created instance to the Nth track `MultiTrackAudioEngine` loads
- [x] `FakeAudioPlayerPlatform.load` records the `LoadRequest` and returns `LoadResponse(duration: ...)` from a per-instance configurable `Duration?`
- [x] `play`/`pause`/`setVolume`/`seek`/`dispose` each record their request object in an instance-level list (`List<PlayRequest> playCalls`, etc.) for assertions
- [x] `playbackEventMessageStream` is a `StreamController<PlaybackEventMessage>.broadcast()` the test can `.add(...)` to directly, simulating position/duration updates without any real timer or decode
- [x] Self-test: constructing a real `AudioPlayer()` under `JustAudioPlatform.instance = FakeJustAudioPlatform()`, calling `setFilePath`, `play`, `setVolume`, `seek`, `dispose` completes without throwing, and the fake recorded each call
- [x] Gate check passes: `flutter test test/infrastructure/audio/`
- [x] Test count: 3+ new tests (3)

**Status: Done.** `load()` must also emit a synthetic "ready" `PlaybackEventMessage` — `AudioPlayer._load` blocks on the first non-"loading" processing-state event, which only a real decoder would otherwise emit; documented in the fake's own doc comment.

**Tests**: unit
**Gate**: quick

---

### T2: `AudioPlaybackEngine` + `MultiTrackAudioEngine` — mudo, solo, atraso ao vivo, posição, duração

**What**: Adds 5 members to the `AudioPlaybackEngine` interface (`setTrackMuted`, `setTrackSolo`, `setTrackStartDelayMs`, `durationMs` getter, `positionMs` stream) and implements them in `MultiTrackAudioEngine`, per design.md's Components section (solo exclusive; mute/solo recompute effective volume from a stored base gain; `setTrackStartDelayMs` only updates the internal map, never reloads; `durationMs`/`positionMs` derive from the first-loaded track as the timeline reference, via `TimelineConverter`).
**Where**: `lib/domain/audio/audio_playback_engine.dart`, `lib/infrastructure/audio/multi_track_audio_engine.dart`
**Depends on**: T1
**Reuses**: `TimelineConverter`, `AudioMixCalculator`, `FakeJustAudioPlatform` (T1, test-only)
**Requirement**: ALIGN-10, ALIGN-11, ALIGN-12, ALIGN-14, ALIGN-15 (the engine capabilities those ACs need), ALIGN-07 (offset-affects-test wiring)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `setTrackMuted(trackId, true)` sets that track's volume to 0 (via `setVolume`), leaves other tracks' volume unchanged; `setTrackMuted(trackId, false)` restores its base gain
- [x] `setTrackSolo(trackId, true)` sets every *other* loaded track's volume to 0 and restores the soloed track's base gain, regardless of its own mute state; activating solo on a second track clears the first track's solo and restores its volume per its own mute state
- [x] `setTrackStartDelayMs(trackId, newDelay)` changes only the internal map — a subsequent `seekAllTo(timelineMs)` computes that track's local seek target using the new delay, without calling `load`/`setFilePath` again
- [x] `durationMs` is `null` before `loadSong` resolves; after, equals the maximum of `startDelayMs + file duration` across all loaded tracks (timeline-space, not file-space)
- [x] `positionMs` emits the first-loaded track's reported position, converted from track-local to timeline time via `TimelineConverter.toTimeline`
- [x] No existing member's signature changed; `PlaybackCommandHandler`/`BackgroundAudioHandler` compile unchanged
- [x] Unit tests for every bullet above, using `FakeJustAudioPlatform` (T1)
- [x] Gate check passes: `flutter test test/infrastructure/audio/`
- [x] Test count: 8+ new tests (11)

**Status: Done.** `positionMs` is driven by `AudioPlayer.playbackEventStream` (fed directly by platform events), not `positionStream` — the latter is a timer-polled animation stream unsuitable for deterministic tests and not needed for this engine's purpose.

**Tests**: unit
**Gate**: quick

---

### T3: `audioPlaybackEngineProvider`

**What**: First Riverpod provider for the audio engine — `Provider<AudioPlaybackEngine>` returning `MultiTrackAudioEngine()`, disposed via `ref.onDispose`.
**Where**: `lib/presentation/providers/audio_playback_engine_provider.dart` (new file)
**Depends on**: T2
**Reuses**: `MultiTrackAudioEngine` (T2)
**Requirement**: supports all of P1 "Testar com mudo, solo e loop" (infrastructure plumbing, no AC of its own)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] `ProviderContainer().read(audioPlaybackEngineProvider)` returns a `MultiTrackAudioEngine` instance
- [x] Disposing the container calls the engine's `dispose()` without throwing
- [x] Gate check passes: `flutter test test/presentation/providers/`
- [x] Test count: 2+ new tests (2)

**Status: Done.**

**Tests**: unit
**Gate**: quick

---

### T4: `TrackAlignNotifier` + `TrackAlignState`

**What**: `StateNotifierProvider.family<TrackAlignNotifier, TrackAlignState, String>` owning draft offsets, mute/solo, the marked loop region, play/stop, unsaved-changes, and save/discard — per design.md. Loads the song via `songByIdProvider`, loads the engine once when it resolves, subscribes to `engine.positionMs` to drive `LoopController`-based repositioning while testing, and calls `SongRepository.save` on save.
**Where**: `lib/presentation/providers/track_align_notifier.dart` (new file)
**Depends on**: T2, T3
**Reuses**: `songByIdProvider`, `songRepositoryProvider`, `songsProvider` (invalidated on save success), `audioPlaybackEngineProvider`, `LoopController`
**Requirement**: ALIGN-01 through ALIGN-21 (all of P1 — this is the behavioral core)

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [x] Carregando / não encontrada / sem faixas / erro ao carregar o motor / carregado — all 5 states represented in `TrackAlignState` (ALIGN-01 to 06)
- [x] Editar um atraso válido atualiza o draft e marca "não salvo"; um valor inválido (negativo ou fora do formato) é rejeitado, mantendo o último valor válido (ALIGN-07, 08, 09)
- [x] Mudo/solo chamam `engine.setTrackMuted`/`setTrackSolo` e atualizam o estado visual; solo é exclusivo na própria store, não só no motor (ALIGN-10, 11, 12)
- [x] Definir início/fim do trecho valida fim > início e fim ≤ `engine.durationMs` (quando conhecida); "Ouvir em loop" chama `seekAllTo(início)` + `playAt(agora)` e assina `positionMs` para reposicionar ao alcançar o fim; "Parar" chama `stop()` e cancela a assinatura (ALIGN-13, 14, 15, 16)
- [x] Salvar chama `SongRepository.save` com a música reconstruída (tracks com os novos `startDelayMs`); sucesso invalida `songsProvider` e limpa "não salvo"; falha mantém o estado e expõe um erro (ALIGN-17, 18)
- [x] Expõe o suficiente para a tela decidir a confirmação de saída (uma flag de "não salvo") sem a tela precisar duplicar essa lógica (ALIGN-19, 20, 21)
- [x] Unit tests (`ProviderContainer`, fake `AudioPlaybackEngine` — a plain Dart double of the domain interface, not `MultiTrackAudioEngine`): um por critério acima
- [x] Gate check passes: `flutter test test/presentation/providers/`
- [x] Test count: 14+ new tests (15)

**Status: Done.** `discard()` from design.md's method list wasn't implemented — nothing to discard beyond navigating away (the family provider is disposed on unmount), and the screen can call `context.goNamed('song-detail', ...)` directly; adding a no-op method would be dead code. `TrackAlignStatus.error` is one bucket covering both a repository-fetch error and an engine-load error (spec.md names only the latter); `retry()` picks the right one to redo based on whether `state.song` is already set.

**Tests**: unit
**Gate**: quick

---

### T5: `TrackAlignRow`

**What**: New shared widget per `COMPONENTS.md` — selo do naipe, nome, campo de atraso `mm:ss.s` (com validação inline), botões M/S, forma de onda estilizada (barras determinísticas a partir do id da faixa) deslocada pelo atraso atual; mudo esmaece a onda (25%), solo destaca o card com borda `accent`.
**Where**: `lib/presentation/widgets/track_align_row.dart` (new file)
**Depends on**: None
**Reuses**: `VoicePartBadge`
**Requirement**: ALIGN-04, ALIGN-07, ALIGN-10, ALIGN-11 (component-level rendering of these states)

**Tools**: MCP: NONE · Skill: `flutter-ui-ux`

**Done when**:
- [ ] Renderiza selo, nome, atraso formatado `mm:ss.s`, botões M/S
- [ ] Editar o campo de atraso com um valor válido chama `onOffsetChanged` com o novo valor em ms; um valor inválido não chama o callback
- [ ] Tocar M/S chama `onMuteChanged`/`onSoloChanged` com o novo booleano
- [ ] Quando `muted: true`, a forma de onda renderiza com opacidade reduzida (25%); quando `solo: true`, o card tem borda `accent`
- [ ] Widget tests: estados (normal/mudo/solo), edição válida/invalida, tap M/S, um spot-check em tema escuro
- [ ] Gate check passes: `flutter test test/presentation/widgets/`
- [ ] Test count: 6+ new tests

**Tests**: widget
**Gate**: full

---

### T6: `Toast`

**What**: New shared widget per `COMPONENTS.md` — `Toast.show(context, message)` insere um `OverlayEntry` (fundo `toastBg`, texto `onToast`, raio 14, ícone de check) que se remove por conta própria após ~2,5 s.
**Where**: `lib/presentation/widgets/toast.dart` (new file)
**Depends on**: None
**Reuses**: nada — primeiro consumidor
**Requirement**: ALIGN-17 (feedback "Atrasos salvos")

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] `Toast.show(context, 'Atrasos salvos')` insere a mensagem na árvore (verificável via `find.text`)
- [ ] Desaparece sozinho após ~2,5 s (verificado com `tester.pump(Duration(...))`, sem precisar de interação do usuário)
- [ ] Widget tests: aparece, desaparece sozinho, um spot-check em tema escuro
- [ ] Gate check passes: `flutter test test/presentation/widgets/`
- [ ] Test count: 3+ new tests

**Tests**: widget
**Gate**: full

---

### T7: `TrackAlignScreen`

**What**: Assembles `CantaeScaffold` + estados + lista de `TrackAlignRow` + campos do trecho de loop + rodapé ("Ouvir em loop"/"Parar", "Salvar atrasos") + `ConfirmSheet` ao voltar com alterações não salvas + `Toast` ao salvar, tudo ligado a `trackAlignProvider` (T4).
**Where**: `lib/presentation/screens/track_align/track_align_screen.dart` (new file)
**Depends on**: T4, T5, T6
**Reuses**: `CantaeScaffold`, `NavPill`, `EmptyState`, `InlineBanner`, `PrimaryButton`/`SecondaryButton`, `ConfirmSheet`, `TrackAlignRow` (T5), `Toast` (T6), `trackAlignProvider` (T4)
**Requirement**: ALIGN-01 through ALIGN-21 (all of P1, assembled)

**Tools**: MCP: NONE · Skill: `flutter-ui-ux`

**Done when**:
- [ ] Carregando: esqueleto, sem `TrackAlignRow` nem rodapé (ALIGN-02)
- [ ] Sem faixas: `EmptyState` com ações para `studio`/`track-upload` (ALIGN-03)
- [ ] Erro ao carregar o motor: `InlineBanner` erro + "Tentar de novo" (ALIGN-06)
- [ ] Carregado: um `TrackAlignRow` por naipe com faixa, campos de início/fim do trecho, rodapé "Ouvir em loop"/"Salvar atrasos" (ALIGN-04, 05)
- [ ] Editar atraso, mudo, solo e trecho de loop refletem no `trackAlignProvider` e na UI (ALIGN-07 a 16)
- [ ] "Ouvir em loop" vira "Parar" enquanto testando (ALIGN-14, 15, 16)
- [ ] "Salvar atrasos" bem-sucedido mostra `Toast` "Atrasos salvos"; falha mostra erro inline (ALIGN-17, 18)
- [ ] Voltar com alterações não salvas abre `ConfirmSheet`; confirmando, navega para `song-detail`; sem alterações, navega direto (ALIGN-19, 20, 21)
- [ ] Widget tests: uma por estado/comportamento acima, usando um `GoRouter` de teste com builders stub (mesmo padrão das features anteriores)
- [ ] Gate check passes: `flutter test test/presentation/screens/`
- [ ] Test count: 12+ new tests

**Tests**: widget
**Gate**: full

---

### T8: Rota `track-align` com `:id` + navegação do Detalhe

**What**: `app_router.dart`'s rota `track-align` ganha o segmento `:id` e passa a construir `TrackAlignScreen(songId: ...)`; `song_detail_screen.dart`'s linha "Alinhar entradas" passa a enviar `pathParameters: {'id': song.id}` (hoje não envia nenhum).
**Where**: `lib/presentation/routing/app_router.dart`, `lib/presentation/screens/song_detail/song_detail_screen.dart`
**Depends on**: T7
**Reuses**: `TrackAlignScreen` (T7)
**Requirement**: ALIGN-01

**Tools**: MCP: NONE · Skill: NONE

**Done when**:
- [ ] `track-align` resolve para `TrackAlignScreen` com o `id` da rota
- [ ] `SongDetailScreen`'s "Alinhar entradas" chama `goNamed('track-align', pathParameters: {'id': song.id})`
- [ ] O teste existente de `song_detail_screen_test.dart` para essa linha é atualizado para afirmar o `id` enviado (hoje só afirma que a rota `track-align` foi alcançada, sem checar o parâmetro)
- [ ] Widget test novo em `app_router_test.dart`: `goNamed('track-align', pathParameters: {'id': 'abc'})` mostra `TrackAlignScreen` com esse id
- [ ] Gate check passes (último task da feature): `flutter analyze && flutter test && python scripts/check_layers.py --root . && dart analyze lib/domain/`
- [ ] Test count: 1+ new test (routing) + 1 updated test (song-detail); suíte total ≥ 414 (contagem no início desta feature) + todos os testes novos de T1-T8

**Tests**: widget
**Gate**: build

---

## Phase Execution Map

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5

Phase 1:  T1    T5    T6
Phase 2:  T1 ------→ T2
Phase 3:  T2 ------→ T3 ------→ T4
          T2 ------------------→ T4
Phase 4:  T4,T5,T6 ------→ T7
Phase 5:  T7 ------→ T8
```

8 tasks total — fits a single batch (≤ ~8); executed inline, no sub-agent dispatch.

---

## Task Granularity Check

| Task | Scope | Status |
| --- | --- | --- |
| T1: `FakeJustAudioPlatform` | 1 test double (cohesive, test-only) | ✅ Granular |
| T2: engine extension | 1 compilation unit (interface + its one implementation — same precedent as prior features' interface+impl pairs) | ✅ Granular |
| T3: `audioPlaybackEngineProvider` | 1 provider | ✅ Granular |
| T4: `TrackAlignNotifier` | 1 state notifier (all its states — same precedent as `LibraryScreen`/`SongDetailScreen`) | ✅ Granular |
| T5: `TrackAlignRow` | 1 component | ✅ Granular |
| T6: `Toast` | 1 component | ✅ Granular |
| T7: `TrackAlignScreen` | 1 screen component | ✅ Granular |
| T8: routing + 1-line nav change | 1 cohesive route-table change | ✅ Granular |

---

## Diagram-Definition Cross-Check

| Task | Depends On (task body) | Diagram Shows | Status |
| --- | --- | --- | --- |
| T1 | None | — | ✅ Match |
| T2 | T1 | T1→T2 | ✅ Match |
| T3 | T2 | T2→T3 | ✅ Match |
| T4 | T2, T3 | T2→T3→T4 (T3's own edge covers T2 transitively; T4 also lists T2 directly, consistent — same chain) | ✅ Match |
| T5 | None | — | ✅ Match |
| T6 | None | — | ✅ Match |
| T7 | T4, T5, T6 | T4→T7, T5→T7, T6→T7 | ✅ Match |
| T8 | T7 | T7→T8 | ✅ Match |

---

## Test Co-location Validation

| Task | Code Layer Created/Modified | Matrix Requires | Task Says | Status |
| --- | --- | --- | --- | --- |
| T1: `FakeJustAudioPlatform` | Test double | unit | unit | ✅ OK |
| T2: engine extension | Infrastructure | unit | unit | ✅ OK |
| T3: `audioPlaybackEngineProvider` | Presentation provider | unit | unit | ✅ OK |
| T4: `TrackAlignNotifier` | Presentation provider | unit | unit | ✅ OK |
| T5: `TrackAlignRow` | Presentation shared widget | widget | widget | ✅ OK |
| T6: `Toast` | Presentation shared widget | widget | widget | ✅ OK |
| T7: `TrackAlignScreen` | Presentation screen | widget | widget | ✅ OK |
| T8: routing + nav change | Routing | widget | widget | ✅ OK |

---
