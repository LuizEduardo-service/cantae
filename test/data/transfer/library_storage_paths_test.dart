import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cantae/data/transfer/library_storage_paths.dart';

void main() {
  group('LibraryStoragePaths.trackFilePath (XFER-06, XFER-07)', () {
    test('returns a content-addressed path under the given root', () {
      final root = Directory.systemTemp.createTempSync('library_storage_test');
      addTearDown(() => root.deleteSync(recursive: true));

      final path = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'abc123',
        extension: 'wav',
      );

      expect(path, equals('${root.path}${Platform.pathSeparator}abc123.wav'));
    });

    test(
        'a second call with the same hash returns the identical path (dedup is "same path" by construction)',
        () {
      final root = Directory.systemTemp.createTempSync('library_storage_test');
      addTearDown(() => root.deleteSync(recursive: true));

      final first = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'deadbeef',
        extension: 'mp3',
      );
      final second = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'deadbeef',
        extension: 'mp3',
      );

      expect(first, equals(second));
    });

    test('a leading dot on the extension does not produce a double dot', () {
      final root = Directory.systemTemp.createTempSync('library_storage_test');
      addTearDown(() => root.deleteSync(recursive: true));

      final path = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'cafef00d',
        extension: '.wav',
      );

      expect(path, equals('${root.path}${Platform.pathSeparator}cafef00d.wav'));
    });

    test('a different hash produces a different path', () {
      final root = Directory.systemTemp.createTempSync('library_storage_test');
      addTearDown(() => root.deleteSync(recursive: true));

      final a = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'hash-a',
        extension: 'wav',
      );
      final b = LibraryStoragePaths.trackFilePath(
        root: root,
        sha256: 'hash-b',
        extension: 'wav',
      );

      expect(a, isNot(equals(b)));
    });
  });
}
