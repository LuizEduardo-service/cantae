import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/song.dart';
import '../../domain/entities/song_origin.dart';
import 'song_repository_provider.dart';

/// The two sort options confirmed in `spec.md`'s Assumptions table.
enum LibrarySortOrder { name, lastRehearsed }

/// Loads the full, unfiltered song list once from [songRepositoryProvider].
/// A `Failure` from the repository surfaces as a thrown exception, which
/// Riverpod's `FutureProvider` turns into `AsyncError` — read via
/// `.when(data:, loading:, error:)`.
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  final result = await repository.getAll();
  return result.when(
    success: (songs) => songs,
    failure: (failure) => throw StateError(failure.code),
  );
});

/// Current search text (`SearchField`). Empty string = no filtering.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Current "Todas"/"Criadas"/"Recebidas" selection. `null` = "Todas".
final originFilterProvider = StateProvider<SongOrigin?>((ref) => null);

/// Current sort selection.
final sortOrderProvider = StateProvider<LibrarySortOrder>(
  (ref) => LibrarySortOrder.name,
);

bool _matchesSearch(Song song, String query) {
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  return song.name.toLowerCase().contains(needle) ||
      song.author.toLowerCase().contains(needle);
}

int _compareByName(Song a, Song b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

/// `lastRehearsedAt` descending; never-rehearsed (`null`) songs sort after
/// every rehearsed song.
int _compareByLastRehearsed(Song a, Song b) {
  final aAt = a.lastRehearsedAt;
  final bAt = b.lastRehearsedAt;
  if (aAt == null && bAt == null) return 0;
  if (aAt == null) return 1;
  if (bAt == null) return -1;
  return bAt.compareTo(aAt);
}

/// The list [LibraryScreen] actually renders: [songsProvider]'s raw list,
/// narrowed by [searchQueryProvider] and [originFilterProvider], then
/// ordered by [sortOrderProvider]. Recomputes whenever any input changes.
final visibleSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final songsAsync = ref.watch(songsProvider);
  final query = ref.watch(searchQueryProvider);
  final origin = ref.watch(originFilterProvider);
  final sortOrder = ref.watch(sortOrderProvider);

  return songsAsync.whenData((songs) {
    final visible = songs
        .where((song) => origin == null || song.origin == origin)
        .where((song) => _matchesSearch(song, query))
        .toList();

    visible.sort(
      sortOrder == LibrarySortOrder.name
          ? _compareByName
          : _compareByLastRehearsed,
    );

    return visible;
  });
});

/// The id of the one song with the latest non-null `lastRehearsedAt` across
/// the full (unfiltered, unsorted) list from [songsProvider] — independent
/// of search/filter/sort, per spec AC LIB-08. Ties go to whichever song
/// appears first in the repository's own returned order. `null` when no
/// song has ever been rehearsed, or while the list is loading/erroring.
final highlightedSongIdProvider = Provider<String?>((ref) {
  final songs = ref.watch(songsProvider).asData?.value;
  if (songs == null) return null;

  String? highlightedId;
  DateTime? latest;
  for (final song in songs) {
    final at = song.lastRehearsedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) {
      latest = at;
      highlightedId = song.id;
    }
  }
  return highlightedId;
});
