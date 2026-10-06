#!/usr/bin/env python3
"""
Layer enforcement: scans lib/domain/ for forbidden imports.
Exits 0 (clean) or 1 (violation found).
Usage: python scripts/check_layers.py [--root <project_root>]
"""
import argparse
import os
import re
import sys

FORBIDDEN_PACKAGES = [
    'package:flutter',
    'package:just_audio',
    'package:audio_service',
    'package:sqflite',
    'package:nsd',
    'package:multicast_dns',
    'package:path_provider',
    # dart:io is a smell in domain — file I/O belongs in infrastructure
    "import 'dart:io'",
    'import "dart:io"',
]

FORBIDDEN_PATTERNS = [re.compile(re.escape(p)) for p in FORBIDDEN_PACKAGES]


def check_file(filepath: str) -> list[tuple[int, str]]:
    violations = []
    with open(filepath, encoding='utf-8', errors='replace') as f:
        for lineno, line in enumerate(f, start=1):
            stripped = line.strip()
            if not stripped.startswith('import'):
                continue
            for pattern in FORBIDDEN_PATTERNS:
                if pattern.search(stripped):
                    violations.append((lineno, stripped))
                    break
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description='Check domain layer import boundaries.')
    parser.add_argument('--root', default=os.getcwd(), help='Project root directory')
    args = parser.parse_args()

    domain_dir = os.path.join(args.root, 'lib', 'domain')

    if not os.path.isdir(domain_dir):
        print(f'ERROR: domain directory not found: {domain_dir}', file=sys.stderr)
        return 1

    total_violations = 0

    for dirpath, _dirnames, filenames in os.walk(domain_dir):
        for filename in filenames:
            if not filename.endswith('.dart'):
                continue
            filepath = os.path.join(dirpath, filename)
            violations = check_file(filepath)
            for lineno, line in violations:
                rel_path = os.path.relpath(filepath, args.root)
                print(f'VIOLATION  {rel_path}:{lineno}  {line}')
                total_violations += 1

    if total_violations == 0:
        print(f'check_layers: OK — no forbidden imports in lib/domain/ ({domain_dir})')
        return 0

    print(f'\ncheck_layers: {total_violations} violation(s) found — fix before proceeding')
    return 1


if __name__ == '__main__':
    sys.exit(main())
