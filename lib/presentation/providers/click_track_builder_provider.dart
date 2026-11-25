import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/click_track_builder.dart';
import '../../infrastructure/audio/file_click_track_builder.dart';

/// The metronome's click-track builder. Tests override it with a fake.
final clickTrackBuilderProvider = Provider<ClickTrackBuilder>(
  (ref) => FileClickTrackBuilder(),
);
