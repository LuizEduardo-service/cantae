import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the app-sandbox location for a content-addressed received track
/// file: `<app docs>/library/tracks/<sha256>.<extension>` (design.md's
/// "Content addressing" Tech Decision). Same hash always resolves to the
/// same path, which is the dedup mechanism by construction.
abstract final class LibraryStoragePaths {
  /// Wraps `path_provider.getApplicationDocumentsDirectory()` and appends
  /// `library/tracks/`, creating the directory if it doesn't already exist.
  static Future<Directory> resolveLibraryRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'library', 'tracks'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Content-addressed final path for a track identified by [sha256], under
  /// the given [root] directory. A second call with the same [sha256] (and
  /// [extension]) always returns the identical path.
  static String trackFilePath({
    required Directory root,
    required String sha256,
    required String extension,
  }) {
    assert(sha256.isNotEmpty, 'sha256 must not be empty');
    final normalizedExtension =
        extension.startsWith('.') ? extension.substring(1) : extension;
    return p.join(root.path, '$sha256.$normalizedExtension');
  }
}
