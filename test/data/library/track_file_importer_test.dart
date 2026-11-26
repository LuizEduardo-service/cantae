import 'dart:io';

import 'package:cantae/data/library/track_file_importer.dart';
import 'package:cantae/data/library/track_file_inspector.dart';
import 'package:cantae/domain/core/result.dart';
import 'package:cantae/domain/library/audio_file_check.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Failure modes (UPL-04, UPL-10, UPL-22):
// - the copy is kept although its hash differs from the original;
// - a failed copy leaves a `.part` or a final file behind;
// - a half-written file sits at the final path while copying;
// - the same file picked twice is copied twice, or the reused file is
//   reported as created (and later deleted by a rollback);
// - a corrupt file already at the final path is trusted and reused;
// - a missing source throws instead of a failure;
// - discard deletes a reused file that other tracks still use.
void main() {
  late Directory dir;
  late Directory root;
  final bytes = [
    ...'ID3'.codeUnits,
    ...List<int>.generate(2000, (i) => i % 251)
  ];
  final sha = sha256.convert(bytes).toString();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cantae_import');
    root = Directory(p.join(dir.path, 'library', 'tracks'))
      ..createSync(recursive: true);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  InspectedTrackFile picked({String name = 'soprano.mp3'}) {
    final source = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return InspectedTrackFile(
      sourcePath: source.path,
      name: name,
      sizeBytes: bytes.length,
      sha256: sha,
      format: AudioFormat.mp3,
    );
  }

  TrackFileImporter importer({Future<String> Function(String)? hashFile}) =>
      TrackFileImporter(
        resolveRoot: () async => root,
        hashFile: hashFile ?? sha256OfFile,
      );

  ImportedTrackFile ok(Result<ImportedTrackFile, dynamic> r) =>
      r.when(success: (f) => f, failure: (f) => fail(f.code));

  String? codeOf(Result<ImportedTrackFile, dynamic> r) =>
      r.when(success: (_) => null, failure: (f) => f.code);

  List<String> libraryFiles() =>
      root.listSync().map((e) => p.basename(e.path)).toList()..sort();

  test('the copy lands at <sha>.mp3 with the same bytes', () async {
    final imported = ok(await importer().import(picked()));

    expect(imported.path, p.join(root.path, '$sha.mp3'));
    expect(imported.created, isTrue);
    expect(File(imported.path).readAsBytesSync(), bytes);
    expect(libraryFiles(), ['$sha.mp3']);
  });

  test('the same file imported twice is reused, not created', () async {
    final first = ok(await importer().import(picked()));
    final second = ok(await importer().import(picked(name: 'outra-copia.mp3')));

    expect(second.path, first.path);
    expect(second.created, isFalse);
    expect(libraryFiles(), ['$sha.mp3']);
  });

  test('a corrupt file at the final path is replaced', () async {
    File(p.join(root.path, '$sha.mp3')).writeAsBytesSync([1, 2, 3]);

    final imported = ok(await importer().import(picked()));

    expect(imported.created, isTrue);
    expect(File(imported.path).readAsBytesSync(), bytes);
    expect(libraryFiles(), ['$sha.mp3']);
  });

  test('a copy whose hash differs is deleted and nothing is kept', () async {
    final result =
        await importer(hashFile: (_) async => 'corrompido').import(picked());

    expect(codeOf(result), 'track_hash_mismatch');
    expect(libraryFiles(), isEmpty);
  });

  test('a missing source is a copy failure with nothing left behind', () async {
    final file = picked();
    File(file.sourcePath).deleteSync();

    final result = await importer().import(file);

    expect(codeOf(result), 'track_copy_failed');
    expect(libraryFiles(), isEmpty);
  });

  test('discard deletes a created file and keeps a reused one', () async {
    final created = ok(await importer().import(picked()));
    final reused = ok(await importer().import(picked()));

    await importer().discard(reused);
    expect(libraryFiles(), ['$sha.mp3']);

    await importer().discard(created);
    expect(libraryFiles(), isEmpty);
  });
}
