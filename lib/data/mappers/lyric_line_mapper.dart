import 'package:drift/drift.dart';
import 'package:cantae/domain/entities/lyric_line.dart';
import 'package:cantae/domain/entities/naipe.dart';
import 'package:cantae/infrastructure/database/app_database.dart';

class LyricLineMapper {
  LyricLineMapper._();

  static LyricLinesTableCompanion toCompanion(
    LyricLine line, {
    required String songId,
  }) {
    return LyricLinesTableCompanion.insert(
      songId: songId,
      lyricText: line.text,
      onsetMs: line.onsetMs,
      naipe: Value(line.naipe?.name),
      dynamics: Value(line.dynamics),
    );
  }

  static LyricLine fromRow(LyricLinesTableData row) {
    return LyricLine(
      text: row.lyricText,
      onsetMs: row.onsetMs,
      naipe: row.naipe == null ? null : Naipe.values.byName(row.naipe!),
      dynamics: row.dynamics,
    );
  }
}
