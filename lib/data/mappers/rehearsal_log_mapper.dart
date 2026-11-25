import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/infrastructure/database/app_database.dart';
import 'package:drift/drift.dart';

abstract final class RehearsalLogMapper {
  static RehearsalLogsTableCompanion toCompanion(RehearsalLog log) =>
      RehearsalLogsTableCompanion.insert(
        id: log.id,
        songId: log.songId,
        startedAt: log.startedAt,
        endedAt: log.endedAt,
        durationMs: log.durationMs,
        mode: log.mode.name,
        localRole: Value(log.localRole?.name),
        maxParticipants: log.maxParticipants,
        loopCount: log.loopCount,
      );

  static RehearsalLog fromRow(RehearsalLogsTableData row) => RehearsalLog(
        id: row.id,
        songId: row.songId,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        durationMs: row.durationMs,
        mode: RehearsalMode.values.byName(row.mode),
        localRole: row.localRole == null
            ? null
            : RehearsalRole.values.byName(row.localRole!),
        maxParticipants: row.maxParticipants,
        loopCount: row.loopCount,
      );
}
