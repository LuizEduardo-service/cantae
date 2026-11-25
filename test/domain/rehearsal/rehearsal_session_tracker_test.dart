import 'package:cantae/domain/entities/rehearsal_log.dart';
import 'package:cantae/domain/rehearsal/rehearsal_session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

// Failure modes (HIST-01..04, HIST-06, HIST-19):
// - paused time is counted (screen open ≠ rehearsing);
// - only the last playing span counts (end + replay, or pause + play, loses
//   earlier time);
// - a span still open when the screen closes is lost;
// - a repeated "playing" signal restarts or double counts a span;
// - loops are counted while paused, or not at all;
// - startedAt is the screen opening, not the first play;
// - the 60 s threshold is off by one (59.999 s kept, or 60 s dropped);
// - a session that never played produces a log;
// - the log carries a room role or the wrong mode / participant count.
final t0 = DateTime(2026, 11, 25, 19, 40);
DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

void main() {
  late RehearsalSessionTracker tracker;

  setUp(() => tracker = RehearsalSessionTracker());

  RehearsalLog? finish(int seconds) =>
      tracker.finish(id: 'log-1', songId: 'ave', now: at(seconds));

  test('only playing time counts; pauses are excluded', () {
    tracker.setPlaying(true, at(0));
    tracker.setPlaying(false, at(40));
    tracker.setPlaying(true, at(100));
    tracker.setPlaying(false, at(130));

    expect(finish(200)!.durationMs, 70000);
  });

  test('a span still open at finish is closed at finish', () {
    tracker.setPlaying(true, at(10));

    expect(finish(85)!.durationMs, 75000);
  });

  test('repeated playing signals do not restart or double count', () {
    tracker.setPlaying(true, at(0));
    tracker.setPlaying(true, at(30));
    tracker.setPlaying(false, at(70));
    tracker.setPlaying(false, at(90));

    expect(finish(120)!.durationMs, 70000);
  });

  test('loops count only while playing', () {
    tracker.loopJumped();
    tracker.setPlaying(true, at(0));
    tracker.loopJumped();
    tracker.loopJumped();
    tracker.setPlaying(false, at(70));
    tracker.loopJumped();

    expect(finish(80)!.loopCount, 2);
  });

  test('startedAt is the first play and endedAt is the finish time', () {
    tracker.setPlaying(true, at(5));
    tracker.setPlaying(false, at(50));
    tracker.setPlaying(true, at(60));

    final log = finish(90)!;
    expect(log.startedAt, at(5));
    expect(log.endedAt, at(90));
  });

  test('just under 60 s of playing is not a rehearsal', () {
    tracker.setPlaying(true, t0);

    final log = tracker.finish(
      id: 'log-1',
      songId: 'ave',
      now: t0.add(const Duration(milliseconds: 59999)),
    );

    expect(log, isNull);
  });

  test('exactly 60 s of playing is a rehearsal', () {
    tracker.setPlaying(true, at(0));

    expect(finish(60)!.durationMs, 60000);
  });

  test('a session that never played is not a rehearsal', () {
    tracker.loopJumped();

    expect(finish(600), isNull);
  });

  test('the log is a solo rehearsal: no role, one participant, ids kept', () {
    tracker.setPlaying(true, at(0));

    final log = finish(61)!;
    expect(log.id, 'log-1');
    expect(log.songId, 'ave');
    expect(log.mode, RehearsalMode.solo);
    expect(log.localRole, isNull);
    expect(log.maxParticipants, 1);
  });
}
