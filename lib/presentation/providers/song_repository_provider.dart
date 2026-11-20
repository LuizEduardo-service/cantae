import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/drift_song_repository.dart';
import '../../domain/repositories/song_repository.dart';
import '../../infrastructure/database/app_database.dart';

/// Opens the real on-device database file under the app's documents
/// directory, lazily (the file isn't touched until the first query).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'cantae.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// The app-wide [AppDatabase] instance. Overridden in tests with an
/// in-memory database (`NativeDatabase.memory()`).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(_openConnection());
  ref.onDispose(db.close);
  return db;
});

/// The app-wide [SongRepository], backed by [appDatabaseProvider].
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return DriftSongRepository(ref.watch(appDatabaseProvider));
});
