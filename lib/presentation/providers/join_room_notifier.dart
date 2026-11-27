import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/core/failures.dart';
import '../../domain/session/ids.dart';
import '../../domain/session/room_discovery.dart';
import '../../domain/session/room_entry_rules.dart';
import '../../domain/session/system_settings.dart';
import 'active_room_notifier.dart';
import 'room_providers.dart';

enum JoinPhase {
  /// Looking; the list shows what was found so far.
  searching,

  /// Nothing found in [joinSearchTimeoutProvider] (ROOM-24).
  noneFound,

  /// Waiting for the master (ROOM-29).
  awaiting,

  /// The request ended; see [JoinRoomState.outcome].
  outcome,

  /// No room took the code (ROOM-26).
  codeNotFound,

  /// The system refused local network access (ROOM-37).
  permissionDenied,
}

/// A found room as the list shows it: never the code (NET-01).
class RoomTileView {
  final RoomId id;
  final String masterName;
  final String? songName;

  const RoomTileView({
    required this.id,
    required this.masterName,
    this.songName,
  });
}

class JoinRoomState {
  final JoinPhase phase;
  final List<RoomTileView> rooms;
  final RoomId? selected;

  /// The room the request went to, while awaiting or after it ended.
  final RoomTileView? target;
  final JoinOutcome? outcome;
  final String code;

  const JoinRoomState({
    this.phase = JoinPhase.searching,
    this.rooms = const [],
    this.selected,
    this.target,
    this.outcome,
    this.code = '',
  });

  RoomTileView? get selectedRoom {
    for (final room in rooms) {
      if (room.id == selected) return room;
    }
    return null;
  }

  bool get canSubmit => code.length == 4 && phase != JoinPhase.awaiting;

  JoinRoomState copyWith({
    JoinPhase? phase,
    List<RoomTileView>? rooms,
    RoomId? selected,
    bool clearSelected = false,
    RoomTileView? target,
    bool clearTarget = false,
    JoinOutcome? outcome,
    bool clearOutcome = false,
    String? code,
  }) =>
      JoinRoomState(
        phase: phase ?? this.phase,
        rooms: rooms ?? this.rooms,
        selected: clearSelected ? null : (selected ?? this.selected),
        target: clearTarget ? null : (target ?? this.target),
        outcome: clearOutcome ? null : (outcome ?? this.outcome),
        code: code ?? this.code,
      );
}

/// How long to look before "Nenhuma sala neste Wi‑Fi" (ROOM-24).
final joinSearchTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 10));

/// Entrar em sala (ROOM-22..38, ROOM-55, ROOM-56, ROOM-58).
class JoinRoomNotifier extends StateNotifier<JoinRoomState> {
  JoinRoomNotifier(Ref ref)
      : _rooms = ref.read(activeRoomProvider.notifier),
        _settings = ref.read(systemSettingsProvider),
        _searchTimeout = ref.read(joinSearchTimeoutProvider),
        super(const JoinRoomState());

  final ActiveRoomNotifier _rooms;
  final SystemSettings _settings;
  final Duration _searchTimeout;
  final Map<RoomId, DiscoveredRoom> _found = {};
  StreamSubscription<DiscoveredRoom>? _search;
  Timer? _noneTimer;
  String _displayName = '';
  bool _joined = false;

  /// Starts looking for rooms; requests go out as [displayName].
  Future<void> start({required String displayName}) async {
    _displayName = displayName;
    await _restartSearch();
  }

  /// "Procurar de novo" (ROOM-24).
  Future<void> searchAgain() => _restartSearch();

  /// Tapping a tile picks the room for the code (ROOM-28).
  void selectRoom(RoomId id) {
    if (state.phase == JoinPhase.awaiting) return;
    state = state.copyWith(selected: id);
  }

  /// Keeps digits only, at most 4 (ROOM-27).
  void setCode(String raw) {
    if (state.phase == JoinPhase.awaiting) return;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(
      code: digits.length > 4 ? digits.substring(0, 4) : digits,
    );
  }

  /// "Entrar": asks the chosen room, or each found room in order until one
  /// takes the code (ROOM-25, ROOM-26, ROOM-58).
  Future<void> submitCode() async {
    if (!state.canSubmit) return;
    final chosen = state.selected == null ? null : _found[state.selected];
    final targets = chosen != null ? [chosen] : _found.values.toList();
    final code = state.code;
    for (final room in targets) {
      if (!mounted) return;
      state = state.copyWith(
        phase: JoinPhase.awaiting,
        target: _tileOf(room),
        clearOutcome: true,
      );
      final outcome = await _rooms.join(room, code, displayName: _displayName);
      if (!mounted) return;
      if (outcome == JoinOutcome.invalidCode) continue;
      _finish(outcome);
      return;
    }
    state = state.copyWith(phase: JoinPhase.codeNotFound, clearTarget: true);
  }

  /// "Cancelar pedido" (ROOM-30).
  Future<void> cancelRequest() async {
    if (state.phase != JoinPhase.awaiting) return;
    await _rooms.cancelJoin();
  }

  /// "Escolher outra sala" / "Digitar de novo": back to the list. The code
  /// is cleared after "Código não encontrado" (ROOM-26).
  void dismissOutcome() {
    final clearCode = state.phase == JoinPhase.codeNotFound;
    state = state.copyWith(
      phase: _listPhase(),
      clearOutcome: true,
      clearTarget: true,
      code: clearCode ? '' : state.code,
    );
  }

  /// "Tentar de novo" after no answer or a lost connection (ROOM-35, 36).
  Future<void> retry() async {
    final target = state.target;
    if (target == null) return;
    state = state.copyWith(selected: target.id);
    await submitCode();
  }

  /// "Abrir ajustes" (ROOM-37, ROOM-57).
  Future<void> openSettings() async => _settings.openAppSettings();

  void _finish(JoinOutcome outcome) {
    if (outcome == JoinOutcome.cancelled) {
      state = state.copyWith(
        phase: _listPhase(),
        clearTarget: true,
        clearOutcome: true,
      );
      return;
    }
    if (outcome == JoinOutcome.joined) {
      _joined = true;
      _stopSearch();
    }
    state = state.copyWith(phase: JoinPhase.outcome, outcome: outcome);
  }

  Future<void> _restartSearch() async {
    _stopSearch();
    _found.clear();
    state = JoinRoomState(code: state.code);
    final search = await _rooms.search();
    if (!mounted) return;
    search.when(
      success: (rooms) {
        _search = rooms.listen(_onRoom, onError: _onSearchError);
        _noneTimer = Timer(_searchTimeout, () {
          if (mounted && _found.isEmpty && state.phase == JoinPhase.searching) {
            state = state.copyWith(phase: JoinPhase.noneFound);
          }
        });
      },
      failure: (_) => state = state.copyWith(phase: JoinPhase.noneFound),
    );
  }

  void _onRoom(DiscoveredRoom room) {
    if (!mounted) return;
    if (room.available) {
      _found[room.id] = room;
    } else {
      _found.remove(room.id);
    }
    final selectedGone =
        state.selected != null && !_found.containsKey(state.selected);
    state = state.copyWith(
      rooms: [for (final r in _found.values) _tileOf(r)],
      clearSelected: selectedGone,
      phase: state.phase == JoinPhase.noneFound && _found.isNotEmpty
          ? JoinPhase.searching
          : null,
    );
  }

  void _onSearchError(Object error) {
    if (!mounted) return;
    final denied =
        error is Failure && error.code == 'discovery.permission-denied';
    state = state.copyWith(
      phase: denied ? JoinPhase.permissionDenied : JoinPhase.noneFound,
    );
  }

  JoinPhase _listPhase() =>
      _found.isEmpty ? JoinPhase.noneFound : JoinPhase.searching;

  RoomTileView _tileOf(DiscoveredRoom room) => RoomTileView(
        id: room.id,
        masterName: room.masterName,
        songName: room.songName,
      );

  void _stopSearch() {
    _noneTimer?.cancel();
    _noneTimer = null;
    _search?.cancel();
    _search = null;
  }

  @override
  void dispose() {
    _stopSearch();
    if (!_joined) unawaited(_rooms.close());
    super.dispose();
  }
}

final joinRoomProvider =
    StateNotifierProvider.autoDispose<JoinRoomNotifier, JoinRoomState>(
  JoinRoomNotifier.new,
);
