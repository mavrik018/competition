// Copies more toolkit parts into an app made with create_app.dart (useful
// after `--minimal`, or to restore a file you deleted).
//
//   dart run tool/add_component.dart --app ../my_app 13_smart_features/insights.dart
//   dart run tool/add_component.dart --app ../my_app smart_matching qr_code
//   dart run tool/add_component.dart --app ../my_app 12_common_features
//
// Each argument is a folder, a lib-relative path or a unique file name.
// Copies the files plus every toolkit file they import, their folder
// READMEs, the toolkit tests that now have all their imports, and the pub
// packages they need; then runs `flutter pub get`. Files already in the app
// are left alone (they are yours and may be edited).
//
// No packages needed: dart:io only.

import 'dart:io';

import 'src/vendor.dart';

Future<void> main(List<String> args) async {
  final appIndex = args.indexOf('--app');
  final specs = [
    for (var i = 0; i < args.length; i++)
      if (i != appIndex && i != appIndex + 1) args[i],
  ];
  if (appIndex < 0 || appIndex + 1 >= args.length || specs.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/add_component.dart --app <app folder> '
      '<folder | file> [...]',
    );
    exit(64);
  }
  final appDir = Directory(args[appIndex + 1]).absolute;
  final pubspec = File('${appDir.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('${appDir.path} has no pubspec.yaml.');
    exit(1);
  }
  final appName = RegExp(
    r'^name:\s*([a-z0-9_]+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())!.group(1)!;
  final toolkitRoot = File.fromUri(Platform.script).parent.parent.absolute;
  final vendor = Vendor(toolkitRoot, appDir, appName);

  final Set<String> files;
  try {
    files = vendor.closure([for (final s in specs) ...vendor.resolve(s)]);
  } on ArgumentError catch (e) {
    stderr.writeln(e.message);
    exit(64);
  }

  final written = vendor.copyLib(files);
  final kept = files.length - written.length;
  stdout.writeln(
    'Copied ${written.length} file(s) into lib/toolkit/'
    '${kept > 0 ? ' ($kept already there, kept as is)' : ''}',
  );
  for (final f in written) {
    stdout.writeln('  + $f');
  }
  final tests = vendor.copyTests();
  if (tests.isNotEmpty) {
    stdout.writeln('Copied ${tests.length} test file(s) into test/toolkit/');
  }
  final added = vendor.syncPubspec();
  if (added.isNotEmpty) stdout.writeln('Added packages: ${added.join(', ')}');
  if (added.contains('flutter_local_notifications') &&
      enableDesugaring(File('${appDir.path}/android/app/build.gradle.kts'))) {
    stdout.writeln('Android: core library desugaring enabled');
  }
  if (copyAiFunction(toolkitRoot, appDir)) {
    stdout.writeln('Copied supabase/functions/ai-complete');
  }
  if (added.isNotEmpty) {
    await run('flutter', ['pub', 'get'], workingDirectory: appDir.path);
  }
  stdout.writeln(
    'Import as package:$appName/toolkit/<folder>/<file>.dart '
    '(per-folder notes: lib/toolkit/<folder>/README.md).',
  );
}
