# domain/

**No Flutter, plugin, or network imports allowed in this directory.**

Files here are pure Dart: no `package:flutter`, no `package:just_audio`, no `package:audio_service`,
no `package:sqflite`, no `package:nsd`, no `dart:io` file I/O.

Violations are caught by `python scripts/check_layers.py --root .` (exits 1 with the offending file:line).
