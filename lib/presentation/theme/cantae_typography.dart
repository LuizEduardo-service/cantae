import 'package:flutter/material.dart';

const String _geist = 'Geist';
const String _geistMono = 'Geist Mono';

/// Typography scale from `docs/design/DESIGN_SYSTEM.md` §3. One named
/// `TextStyle` per documented row — the styles with a direct `TextTheme`
/// equivalent also feed `AppTheme`'s `textTheme`; the rest (lyric lines,
/// mono numbers) are read directly from here.
abstract final class CantaeTypography {
  static const TextStyle display = TextStyle(
    fontFamily: _geist,
    fontSize: 72,
    fontWeight: FontWeight.w700,
    letterSpacing: -3,
    height: 0.95,
  );

  static const TextStyle titleHub = TextStyle(
    fontFamily: _geist,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.0,
  );

  static const TextStyle titlePage = TextStyle(
    fontFamily: _geist,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static const TextStyle titleRoom = TextStyle(
    fontFamily: _geist,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static const TextStyle titleSheet = TextStyle(
    fontFamily: _geist,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static const TextStyle lyricActive = TextStyle(
    fontFamily: _geist,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static const TextStyle lyricNext = TextStyle(
    fontFamily: _geist,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static const TextStyle lyricPast = TextStyle(
    fontFamily: _geist,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
  );

  static const TextStyle listTitle = TextStyle(
    fontFamily: _geist,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _geist,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _geist,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _geist,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _geist,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle monoLarge = TextStyle(
    fontFamily: _geistMono,
    fontSize: 64,
    fontWeight: FontWeight.w500,
    letterSpacing: 8,
  );

  static const TextStyle monoInput = TextStyle(
    fontFamily: _geistMono,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: 8,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: _geistMono,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
}
