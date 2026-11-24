#!/usr/bin/env dart
//
// LOUTE version sync script — reads version.json and writes version
// strings into all downstream files.  Run in check mode (`--check`) to
// fail with exit code 1 when any file is out of sync (CI gate).
//
// Usage:
//   dart scripts/sync_version.dart            # write
//   dart scripts/sync_version.dart --check     # verify only
//

import 'dart:convert';
import 'dart:io';

const String louteVersion = '1.5.5';

typedef FilePatch = ({String path, String oldPattern, String newPattern});

final List<FilePatch> patches = [
  // pubspec.yaml
  (
    path: 'loute/pubspec.yaml',
    oldPattern: RegExp(r'^version: .+$', multiLine: true).pattern,
    newPattern: 'version: ${louteVersion}+1',
  ),
  // Cargo.toml
  (
    path: 'rust/Cargo.toml',
    oldPattern: RegExp(r'^version = "[^"]*"', multiLine: true).pattern,
    newPattern: 'version = "$louteVersion"',
  ),
  // navigation_state.dart
  (
    path: 'loute/lib/providers/navigation_state.dart',
    oldPattern: "this.systemVersion = '",
    newPattern: "this.systemVersion = '$louteVersion'",
  ),
];

void main(List<String> args) {
  final checkOnly = args.contains('--check');

  // Read version.json
  final versionFile = File('version.json');
  if (!versionFile.existsSync()) {
    stderr.writeln('ERROR: version.json not found');
    exit(1);
  }

  final versionJson =
      jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
  final version = versionJson['version'] as String;
  stdout.writeln('LOUTE version: $version (build ${versionJson['build']})');

  var drift = false;

  // Check / write each patch
  for (final patch in patches) {
    final file = File(patch.path);
    if (!file.existsSync()) {
      stderr.writeln('WARN: ${patch.path} not found, skipping');
      continue;
    }
    final content = file.readAsStringSync();

    // For regex-based patches we do a simple replacement
    String updated;
    if (patch.path.endsWith('pubspec.yaml')) {
      updated = content.replaceAll(
          RegExp(r'^version: .+$', multiLine: true), 'version: $version+1');
    } else if (patch.path.endsWith('Cargo.toml')) {
      updated = content.replaceAll(
          RegExp(r'^version = "[^"]*"', multiLine: true), 'version = "$version"');
    } else if (patch.path.endsWith('navigation_state.dart')) {
      updated = content.replaceAll(
          RegExp(r"this\.systemVersion = '[^']*'"),
          "this.systemVersion = '$version'");
    } else {
      updated = content;
    }

    if (updated != content) {
      if (checkOnly) {
        stderr.writeln('DRIFT: ${patch.path} is out of sync');
        drift = true;
      } else {
        file.writeAsStringSync(updated);
        stdout.writeln('SYNCED: ${patch.path}');
      }
    } else {
      stdout.writeln('OK: ${patch.path}');
    }
  }

  // Check packaging scripts for version string
  final packagingFiles = [
    'packaging/build_linux_deb.sh',
    'packaging/build_windows_exe.sh',
    'packaging/build_arch.sh',
    'packaging/PKGBUILD',
    'packaging/build_android_apk.sh',
    'packaging/packaging.md',
    'README.md',
  ];

  for (final p in packagingFiles) {
    final file = File(p);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    if (content.contains('1.5.0') && !content.contains('1.5.5')) {
      if (checkOnly) {
        stderr.writeln('DRIFT: $p still references 1.5.0');
        drift = true;
      } else {
        final updated = content.replaceAll('1.5.0', '1.5.5');
        file.writeAsStringSync(updated);
        stdout.writeln('SYNCED: $p');
      }
    } else {
      stdout.writeln('OK: $p');
    }
  }

  if (drift) {
    stderr.writeln('VERSION DRIFT DETECTED — run `dart scripts/sync_version.dart` to fix');
    exit(1);
  }

  stdout.writeln('All version references in sync.');
}
