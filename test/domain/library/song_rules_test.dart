import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/entities/custom_naipe.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/domain/entities/song_track.dart';
import 'package:cantae/domain/library/song_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (UPL-05, UPL-14):
// - a blank name (only spaces) passes as non-empty;
// - the 80-char limit is off by one, or counts surrounding spaces;
// - an empty author is refused (it is optional);
// - values are returned untrimmed, so "  Ave " is stored with spaces;
// - a custom naipe name equal to a standard one in another case passes
//   ("tenor", "PLAYBACK");
// - a duplicate custom naipe passes when case or spaces differ;
// - the 24-char limit is off by one;
// - a custom naipe is attached to a standard-naipe track.
String? code<S>(Result<S, dynamic> r) =>
    r.when(success: (_) => null, failure: (f) => f.code);

S value<S>(Result<S, dynamic> r) =>
    r.when(success: (v) => v, failure: (f) => throw StateError(f.code));

void main() {
  group('validateSongFields', () {
    test('an empty or blank name is refused', () {
      expect(code(validateSongFields(name: '', author: '')), 'song_name_empty');
      expect(
        code(validateSongFields(name: '   ', author: '')),
        'song_name_empty',
      );
    });

    test('a 1-char and an 80-char name are accepted', () {
      expect(code(validateSongFields(name: 'A', author: '')), isNull);
      expect(
        code(validateSongFields(name: 'a' * maxSongNameLength, author: '')),
        isNull,
      );
    });

    test('an 81-char name is refused', () {
      expect(
        code(validateSongFields(name: 'a' * 81, author: '')),
        'song_name_too_long',
      );
    });

    test('the limit ignores surrounding spaces', () {
      expect(
        code(validateSongFields(name: '  ${'a' * 80}  ', author: '')),
        isNull,
      );
    });

    test('the author is optional and limited to 80 chars', () {
      expect(code(validateSongFields(name: 'Ave', author: '')), isNull);
      expect(
        code(validateSongFields(name: 'Ave', author: 'a' * maxAuthorLength)),
        isNull,
      );
      expect(
        code(validateSongFields(name: 'Ave', author: 'a' * 81)),
        'song_author_too_long',
      );
    });

    test('both values come back trimmed', () {
      final fields = value(
        validateSongFields(name: '  Ave Verum Corpus ', author: ' Mozart  '),
      );
      expect(fields.name, 'Ave Verum Corpus');
      expect(fields.author, 'Mozart');
    });
  });

  group('validateCustomNaipeName', () {
    const solista = CustomNaipe(id: 'n1', name: 'Solista');

    test('an empty or blank name is refused', () {
      expect(
        code(validateCustomNaipeName('', existing: const [])),
        'naipe_name_empty',
      );
      expect(
        code(validateCustomNaipeName('  ', existing: const [])),
        'naipe_name_empty',
      );
    });

    test('24 chars are accepted and 25 are refused', () {
      expect(
        code(validateCustomNaipeName(
          'a' * maxCustomNaipeNameLength,
          existing: const [],
        )),
        isNull,
      );
      expect(
        code(validateCustomNaipeName('a' * 25, existing: const [])),
        'naipe_name_too_long',
      );
    });

    test('standard names and Playback are reserved in any case', () {
      for (final name in [
        'Soprano',
        'contralto',
        'TENOR',
        'Baixo',
        'Playback',
        ' playback ',
      ]) {
        expect(
          code(validateCustomNaipeName(name, existing: const [])),
          'naipe_name_reserved',
          reason: name,
        );
      }
    });

    test('a name already in the list is refused ignoring case and spaces', () {
      expect(
        code(validateCustomNaipeName(' solista ', existing: const [solista])),
        'naipe_name_duplicate',
      );
    });

    test('a valid name comes back trimmed', () {
      expect(
        value(validateCustomNaipeName('  Mezzo ', existing: const [solista])),
        'Mezzo',
      );
    });
  });

  group('SongTrack with a custom naipe', () {
    test('keeps the custom naipe and the file facts', () {
      const track = SongTrack(
        id: 't1',
        filePath: '/lib/abc.mp3',
        naipe: Naipe.custom,
        customNaipe: CustomNaipe(id: 'n1', name: 'Solista'),
        fileName: 'solista.mp3',
        fileSizeBytes: 2048,
      );
      expect(track.customNaipe!.name, 'Solista');
      expect(track.fileName, 'solista.mp3');
      expect(track.fileSizeBytes, 2048);
    });

    test('a standard naipe cannot carry a custom naipe', () {
      expect(
        () => SongTrack(
          id: 't1',
          filePath: '/lib/abc.mp3',
          naipe: Naipe.tenor,
          customNaipe: const CustomNaipe(id: 'n1', name: 'Solista'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('custom naipes are equal by id', () {
      expect(
        const CustomNaipe(id: 'n1', name: 'Solista'),
        const CustomNaipe(id: 'n1', name: 'Solista'),
      );
      expect(
        const CustomNaipe(id: 'n1', name: 'Solista') ==
            const CustomNaipe(id: 'n2', name: 'Solista'),
        isFalse,
      );
    });
  });
}
