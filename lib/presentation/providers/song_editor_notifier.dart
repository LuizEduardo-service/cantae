import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/library/song_tracks_saver.dart';
import '../../data/library/track_file_inspector.dart';
import '../../domain/core/failures.dart';
import '../../domain/core/result.dart';
import '../../domain/entities/custom_naipe.dart';
import '../../domain/entities/naipe.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/song_origin.dart';
import '../../domain/entities/song_track.dart';
import '../../domain/library/song_rules.dart';
import 'library_providers.dart';
import 'song_detail_providers.dart';
import 'track_upload_providers.dart';

enum SongEditorStatus { loading, notFound, error, readOnly, ready }

/// Where a track goes: a standard naipe, the Playback, or a custom naipe.
class TrackSlot {
  const TrackSlot.standard(this.naipe)
      : isPlayback = false,
        customNaipe = null;
  const TrackSlot.playback()
      : naipe = Naipe.custom,
        isPlayback = true,
        customNaipe = null;
  const TrackSlot.custom(CustomNaipe this.customNaipe)
      : naipe = Naipe.custom,
        isPlayback = false;

  final Naipe naipe;
  final bool isPlayback;
  final CustomNaipe? customNaipe;

  @override
  bool operator ==(Object other) =>
      other is TrackSlot &&
      other.naipe == naipe &&
      other.isPlayback == isPlayback &&
      other.customNaipe == customNaipe;

  @override
  int get hashCode => Object.hash(naipe, isPlayback, customNaipe);
}

/// One row of the editor. [current] is what saving would keep.
class TrackSlotState {
  const TrackSlotState({
    required this.slot,
    this.saved,
    this.chosen,
    this.removed = false,
    this.checking = false,
    this.error,
  });

  final TrackSlot slot;

  /// The track stored for this slot when the screen opened.
  final SongTrack? saved;

  /// A newly picked file that passed the check.
  final InspectedTrackFile? chosen;

  /// The saved track was removed (confirmed) and not replaced.
  final bool removed;
  final bool checking;

  /// Why the last picked file was refused.
  final String? error;

  /// A new file, the kept saved track, or null.
  Object? get current => chosen ?? (removed ? null : saved);

  bool get changed => chosen != null || removed;

  TrackSlotState copyWith({
    InspectedTrackFile? chosen,
    bool clearChosen = false,
    bool? removed,
    bool? checking,
    String? error,
    bool clearError = false,
  }) =>
      TrackSlotState(
        slot: slot,
        saved: saved,
        chosen: clearChosen ? null : (chosen ?? this.chosen),
        removed: removed ?? this.removed,
        checking: checking ?? this.checking,
        error: clearError ? null : (error ?? this.error),
      );
}

class SongEditorState {
  const SongEditorState({
    required this.status,
    required this.isNew,
    this.songName = '',
    this.name = '',
    this.author = '',
    this.nameError,
    this.authorError,
    this.slots = const [],
    this.deviceCustomNaipes = const [],
    this.customNaipesLoaded = false,
    this.pickerError,
    this.saving = false,
    this.saveError,
    this.isDirty = false,
  });

  final SongEditorStatus status;
  final bool isNew;

  /// The stored name (for the back pill), unaffected by edits.
  final String songName;
  final String name;
  final String author;
  final String? nameError;
  final String? authorError;
  final List<TrackSlotState> slots;
  final List<CustomNaipe> deviceCustomNaipes;
  final bool customNaipesLoaded;
  final String? pickerError;
  final bool saving;
  final String? saveError;
  final bool isDirty;

  List<TrackSlotState> get customSlots =>
      slots.where((s) => s.slot.customNaipe != null).toList();

  bool get canAddCustomNaipe => customSlots.length < maxCustomNaipesPerSong;

  /// Device custom naipes this song does not use yet.
  List<CustomNaipe> get addableCustomNaipes {
    final used = {for (final s in customSlots) s.slot.customNaipe!};
    return deviceCustomNaipes.where((n) => !used.contains(n)).toList();
  }

  bool get canSave =>
      status == SongEditorStatus.ready &&
      !saving &&
      validateSongFields(name: name, author: author).isSuccess &&
      !slots.any((s) => s.checking);

  SongEditorState copyWith({
    SongEditorStatus? status,
    String? songName,
    String? name,
    String? author,
    String? nameError,
    bool clearNameError = false,
    String? authorError,
    bool clearAuthorError = false,
    List<TrackSlotState>? slots,
    List<CustomNaipe>? deviceCustomNaipes,
    bool? customNaipesLoaded,
    String? pickerError,
    bool clearPickerError = false,
    bool? saving,
    String? saveError,
    bool clearSaveError = false,
    bool? isDirty,
  }) =>
      SongEditorState(
        status: status ?? this.status,
        isNew: isNew,
        songName: songName ?? this.songName,
        name: name ?? this.name,
        author: author ?? this.author,
        nameError: clearNameError ? null : (nameError ?? this.nameError),
        authorError:
            clearAuthorError ? null : (authorError ?? this.authorError),
        slots: slots ?? this.slots,
        deviceCustomNaipes: deviceCustomNaipes ?? this.deviceCustomNaipes,
        customNaipesLoaded: customNaipesLoaded ?? this.customNaipesLoaded,
        pickerError:
            clearPickerError ? null : (pickerError ?? this.pickerError),
        saving: saving ?? this.saving,
        saveError: clearSaveError ? null : (saveError ?? this.saveError),
        isDirty: isDirty ?? this.isDirty,
      );
}

/// pt-BR text for each failure code (the domain never knows the language).
String _message(String code) => switch (code) {
      'song_name_empty' => 'Informe o nome da música.',
      'song_name_too_long' => 'Use até 80 caracteres.',
      'song_author_too_long' => 'Use até 80 caracteres.',
      'track_file_unsupported' =>
        'Este arquivo não é um áudio aceito (MP3, M4A ou WAV).',
      'track_file_too_large' => 'Arquivo maior que 100 MB.',
      'picker_failed' => 'Não foi possível abrir os arquivos.',
      'naipe_name_empty' => 'Informe o nome do naipe.',
      'naipe_name_too_long' => 'Use até 24 caracteres.',
      'naipe_name_reserved' => 'Esse nome é de um naipe padrão.',
      'naipe_name_duplicate' => 'Já existe um naipe com esse nome.',
      _ => 'Não foi possível ler este arquivo.',
    };

const _saveFailedMessage = 'Não foi possível salvar a música. Tente de novo.';
const _customLimitMessage = 'Até 4 naipes extras por música.';

const _standardOrder = [
  Naipe.soprano,
  Naipe.contralto,
  Naipe.tenor,
  Naipe.bass
];

/// The editor for a new song (`null`) or an existing one (its id).
final songEditorProvider = StateNotifierProvider.autoDispose
    .family<SongEditorNotifier, SongEditorState, String?>(
  (ref, songId) => SongEditorNotifier(ref, songId),
);

class SongEditorNotifier extends StateNotifier<SongEditorState> {
  SongEditorNotifier(this._ref, this._songId)
      : super(SongEditorState(
          status: _songId == null
              ? SongEditorStatus.ready
              : SongEditorStatus.loading,
          isNew: _songId == null,
          slots: _songId == null ? _emptySlots() : const [],
        )) {
    final songId = _songId;
    if (songId != null) {
      _ref.listen<AsyncValue<Result<Song, Failure>>>(
        songByIdProvider(songId),
        (_, next) => _onSong(next),
        fireImmediately: true,
      );
    }
    _loadCustomNaipes();
  }

  final Ref _ref;
  final String? _songId;
  Song? _base;

  /// Saved tracks the editor has no row for (e.g. a custom track without a
  /// name); always kept as they are.
  List<SongTrack> _untouched = const [];
  final Map<TrackSlot, int> _pickTokens = {};

  static List<TrackSlotState> _emptySlots() => [
        for (final naipe in _standardOrder)
          TrackSlotState(slot: TrackSlot.standard(naipe)),
        const TrackSlotState(slot: TrackSlot.playback()),
      ];

  Future<void> _loadCustomNaipes() async {
    final result = await _ref.read(customNaipeRepositoryProvider).getAll();
    if (!mounted) return;
    state = state.copyWith(
      deviceCustomNaipes: result.when(success: (l) => l, failure: (_) => []),
      customNaipesLoaded: true,
    );
  }

  void _onSong(AsyncValue<Result<Song, Failure>> async) {
    async.when(
      loading: () => state = state.copyWith(status: SongEditorStatus.loading),
      error: (_, __) => state = state.copyWith(status: SongEditorStatus.error),
      data: (result) => result.when(
        success: _onSongLoaded,
        failure: (f) => state = state.copyWith(
          status: f is NotFoundFailure
              ? SongEditorStatus.notFound
              : SongEditorStatus.error,
        ),
      ),
    );
  }

  void _onSongLoaded(Song song) {
    _base = song;
    final slots = <TrackSlotState>[];
    final untouched = <SongTrack>[];
    for (final naipe in _standardOrder) {
      slots.add(TrackSlotState(
        slot: TrackSlot.standard(naipe),
        saved: song.tracks.where((t) => t.naipe == naipe).firstOrNull,
      ));
    }
    slots.add(TrackSlotState(
      slot: const TrackSlot.playback(),
      saved: song.playbackTrack,
    ));
    for (final track in song.tracks.where((t) => t.naipe == Naipe.custom)) {
      final custom = track.customNaipe;
      if (custom == null) {
        untouched.add(track);
      } else {
        slots.add(TrackSlotState(slot: TrackSlot.custom(custom), saved: track));
      }
    }
    _untouched = untouched;
    state = state.copyWith(
      status: song.origin == SongOrigin.received
          ? SongEditorStatus.readOnly
          : SongEditorStatus.ready,
      songName: song.name,
      name: song.name,
      author: song.author,
      slots: slots,
      isDirty: false,
    );
  }

  void retry() {
    final songId = _songId;
    if (songId != null) _ref.invalidate(songByIdProvider(songId));
  }

  void _updateSlot(TrackSlot slot, TrackSlotState Function(TrackSlotState) f,
      {bool dirty = false}) {
    state = state.copyWith(
      slots: [for (final s in state.slots) s.slot == slot ? f(s) : s],
      isDirty: dirty ? true : null,
    );
  }

  /// Opens the picker for [slot] and checks the chosen file (UPL-03, 07-09,
  /// 11). A newer pick for the same slot wins over a slower older one.
  Future<void> pickFor(TrackSlot slot) async {
    state = state.copyWith(clearPickerError: true);
    final picked = await _ref.read(trackFilePickerProvider).pick();
    if (!mounted) return;
    final failure = picked.when(success: (_) => null, failure: (f) => f);
    if (failure != null) {
      state = state.copyWith(pickerError: _message(failure.code));
      return;
    }
    final file = picked.when(success: (f) => f, failure: (_) => null);
    if (file == null) return;

    final token = (_pickTokens[slot] ?? 0) + 1;
    _pickTokens[slot] = token;
    _updateSlot(slot, (s) => s.copyWith(checking: true, clearError: true));

    final inspected = await _ref.read(trackFileInspectorProvider).inspect(file);
    if (!mounted || _pickTokens[slot] != token) return;
    inspected.when(
      success: (f) => _updateSlot(
        slot,
        (s) => s.copyWith(chosen: f, removed: false, checking: false),
        dirty: true,
      ),
      failure: (f) => _updateSlot(
        slot,
        (s) => s.copyWith(checking: false, error: _message(f.code)),
      ),
    );
  }

  /// Leaves [slot] without a track (a saved one is removed on save).
  void removeTrack(TrackSlot slot) => _updateSlot(
        slot,
        (s) => s.copyWith(
          clearChosen: true,
          removed: s.saved != null,
          clearError: true,
        ),
        dirty: true,
      );

  void addCustomNaipe(CustomNaipe naipe) {
    if (!state.canAddCustomNaipe ||
        state.customSlots.any((s) => s.slot.customNaipe == naipe)) {
      return;
    }
    state = state.copyWith(
      slots: [...state.slots, TrackSlotState(slot: TrackSlot.custom(naipe))],
      isDirty: true,
    );
  }

  /// Creates a custom naipe for this song; returns why not, or null.
  String? createCustomNaipe(String raw) {
    if (!state.canAddCustomNaipe) return _customLimitMessage;
    final known = {
      ...state.deviceCustomNaipes,
      for (final s in state.customSlots) s.slot.customNaipe!,
    };
    final result = validateCustomNaipeName(raw, existing: known);
    return result.when(
      success: (name) {
        addCustomNaipe(CustomNaipe(id: _ref.read(newIdProvider)(), name: name));
        return null;
      },
      failure: (f) => _message(f.code),
    );
  }

  /// Takes a custom naipe row out of this song; the device list keeps it.
  void removeCustomSlot(TrackSlot slot) {
    state = state.copyWith(
      slots: state.slots.where((s) => s.slot != slot).toList(),
      isDirty: true,
    );
  }

  void setName(String value) {
    final code = validateSongFields(name: value, author: '')
        .when(success: (_) => null, failure: (f) => f.code);
    state = state.copyWith(
      name: value,
      nameError: code == null ? null : _message(code),
      clearNameError: code == null,
      isDirty: true,
    );
  }

  void setAuthor(String value) {
    final tooLong = value.trim().length > maxAuthorLength;
    state = state.copyWith(
      author: value,
      authorError: tooLong ? _message('song_author_too_long') : null,
      clearAuthorError: !tooLong,
      isDirty: true,
    );
  }

  /// Saves the song; returns its id, or null when it could not be saved.
  Future<String?> save() async {
    if (!state.canSave) return null;
    final fields = validateSongFields(name: state.name, author: state.author)
        .when(success: (f) => f, failure: (_) => null)!;
    state = state.copyWith(saving: true, clearSaveError: true);

    final songId = _songId ?? _ref.read(newIdProvider)();
    final request = SongSaveRequest(
      songId: songId,
      name: fields.name,
      author: fields.author,
      base: _base,
      tracks: [
        for (final s in state.slots)
          if (_choiceFor(s) case final choice?) choice,
        for (final t in _untouched) TrackChoice.kept(t),
      ],
    );
    final result = await _ref.read(songTracksSaverProvider).save(request);
    if (!mounted) return null;
    if (result.isFailure) {
      state = state.copyWith(saving: false, saveError: _saveFailedMessage);
      return null;
    }
    _ref.invalidate(songsProvider);
    _ref.invalidate(songByIdProvider(songId));
    await _ref.read(trackFilePickerProvider).releaseTemporaryFiles();
    if (mounted) state = state.copyWith(saving: false, isDirty: false);
    return songId;
  }

  TrackChoice? _choiceFor(TrackSlotState s) {
    final chosen = s.chosen;
    if (chosen != null) {
      return TrackChoice.newFile(
        naipe: s.slot.naipe,
        isPlayback: s.slot.isPlayback,
        customNaipe: s.slot.customNaipe,
        file: chosen,
      );
    }
    final saved = s.saved;
    if (saved != null && !s.removed) return TrackChoice.kept(saved);
    return null;
  }
}
