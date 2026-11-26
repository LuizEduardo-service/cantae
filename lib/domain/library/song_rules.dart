import 'package:cantae/domain/core/failures.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';

const int maxSongNameLength = 80;
const int maxAuthorLength = 80;
const int maxCustomNaipeNameLength = 24;
const int maxCustomNaipesPerSong = 4;

/// Names a custom naipe may not take, compared trimmed and lowercased.
const Set<String> _reservedNaipeNames = {
  'soprano',
  'contralto',
  'tenor',
  'baixo',
  'playback',
};

/// Checks the song form (UPL-05). Both values come back trimmed.
Result<({String name, String author}), ValidationFailure> validateSongFields({
  required String name,
  required String author,
}) {
  final trimmedName = name.trim();
  final trimmedAuthor = author.trim();
  if (trimmedName.isEmpty) {
    return Result.failure(ValidationFailure(code: 'song_name_empty'));
  }
  if (trimmedName.length > maxSongNameLength) {
    return Result.failure(ValidationFailure(code: 'song_name_too_long'));
  }
  if (trimmedAuthor.length > maxAuthorLength) {
    return Result.failure(ValidationFailure(code: 'song_author_too_long'));
  }
  return Result.success((name: trimmedName, author: trimmedAuthor));
}

/// Checks a new custom naipe name against the device list (UPL-14).
/// Returns the trimmed name.
Result<String, ValidationFailure> validateCustomNaipeName(
  String raw, {
  required Iterable<CustomNaipe> existing,
}) {
  final name = raw.trim();
  final key = name.toLowerCase();
  if (name.isEmpty) {
    return Result.failure(ValidationFailure(code: 'naipe_name_empty'));
  }
  if (name.length > maxCustomNaipeNameLength) {
    return Result.failure(ValidationFailure(code: 'naipe_name_too_long'));
  }
  if (_reservedNaipeNames.contains(key)) {
    return Result.failure(ValidationFailure(code: 'naipe_name_reserved'));
  }
  if (existing.any((n) => n.name.trim().toLowerCase() == key)) {
    return Result.failure(ValidationFailure(code: 'naipe_name_duplicate'));
  }
  return Result.success(name);
}
