// Creates a new, self-contained Flutter app from templates/starter, with the
// toolkit's source code COPIED into it (no dependency on the toolkit).
//
//   dart run tool/create_app.dart my_app
//   dart run tool/create_app.dart my_app --dir C:/hackathon --title "Green Route" --org com.team
//   dart run tool/create_app.dart my_app --platforms android,ios,web
//   dart run tool/create_app.dart my_app --minimal
//
// What it does:
//   1. `flutter create` (empty app) for the chosen platforms.
//   2. Copies the toolkit's lib/ into the app's lib/toolkit/ — all of it by
//      default; with --minimal only the files the starter uses (plus what
//      they import). Add more later with tool/add_component.dart.
//   3. Copies templates/starter (lib/features + test/) — a three-tab app
//      with a dashboard, a persisted CRUD list with a form, priority scoring
//      and settings — replacing {{app_name}} / {{app_title}}.
//   4. Copies the toolkit tests that cover the copied files into
//      test/toolkit/ and the toolkit's analysis_options.yaml.
//   5. Adds the pub packages the copied code imports to pubspec.yaml and
//      uses the toolkit's Dart SDK constraint (the copied code's language
//      version).
//   6. Android: enables core library desugaring if the reminders plugin
//      (flutter_local_notifications) was copied, or the APK build fails.
//      Copies supabase/functions/ai-complete if the AI client was copied.
//   7. Runs `flutter pub get`.
// Then: cd into the app, `flutter test`, `flutter run`.
//
// No packages needed: dart:io only.

import 'dart:io';

import 'src/vendor.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first.startsWith('-')) {
    stderr.writeln(
      'Usage: dart run tool/create_app.dart <app_name> '
      '[--dir <parent>] [--title "<Title>"] [--org <org>] '
      '[--platforms android,ios,web,windows] [--minimal]',
    );
    exit(64);
  }
  final name = args.first;
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
    stderr.writeln('App name must be lower_snake_case (got "$name").');
    exit(64);
  }
  String option(String flag, String fallback) {
    final i = args.indexOf(flag);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final toolkitRoot = File.fromUri(Platform.script).parent.parent.absolute;
  final parent = Directory(option('--dir', Directory.current.path)).absolute;
  final title = option('--title', _titleCase(name));
  final org = option('--org', 'com.example');
  final platforms = option('--platforms', 'android,ios,web,windows');
  final minimal = args.contains('--minimal');
  final appDir = Directory('${parent.path}${Platform.pathSeparator}$name');

  if (appDir.existsSync()) {
    stderr.writeln('${appDir.path} already exists — choose another name.');
    exit(1);
  }
  parent.createSync(recursive: true);

  stdout.writeln('1/7 flutter create $name ($platforms)');
  await run('flutter', [
    'create',
    '--empty',
    '--no-pub',
    '--org',
    org,
    '--platforms',
    platforms,
    '--project-name',
    name,
    appDir.path,
  ]);

  final vendor = Vendor(toolkitRoot, appDir, name);

  stdout.writeln('2/7 copying templates/starter');
  final template = Directory('${toolkitRoot.path}/templates/starter');
  final starterNeeds = <String>{};
  for (final entity in template.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(template.path.length + 1);
    final text = entity
        .readAsStringSync()
        .replaceAll('{{app_name}}', name)
        .replaceAll('{{app_title}}', title);
    starterNeeds.addAll(vendor.toolkitImportsIn(text));
    File('${appDir.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(vendor.rewrite(text));
  }
  final defaultTest = File('${appDir.path}/test/widget_test.dart');
  if (defaultTest.existsSync()) defaultTest.deleteSync();

  final files = minimal
      ? vendor.closure(starterNeeds)
      : vendor.allLibFiles().toSet();
  stdout.writeln(
    '3/7 copying ${files.length} toolkit files into lib/toolkit/'
    '${minimal ? ' (--minimal: only what the starter uses)' : ''}',
  );
  vendor.copyLib(files);

  stdout.writeln('4/7 copying toolkit tests and lint rules');
  final tests = vendor.copyTests();
  stdout.writeln('    ${tests.length} test files into test/toolkit/');
  final lints = File(
    '${toolkitRoot.path}/analysis_options.yaml',
  ).readAsStringSync();
  File('${appDir.path}/analysis_options.yaml').writeAsStringSync(
    lints.replaceFirst(
      RegExp(
        r'analyzer:\r?\n  exclude:\r?\n(    #.*\r?\n)*    - templates/\*\*\r?\n',
      ),
      'analyzer:\n',
    ),
  );

  stdout.writeln('5/7 adding packages to pubspec.yaml');
  useToolkitSdk(toolkitRoot, appDir);
  final added = vendor.syncPubspec(alwaysAdd: {'cupertino_icons'});
  stdout.writeln('    ${added.join(', ')}');

  stdout.writeln('6/7 platform settings');
  if (added.contains('flutter_local_notifications') &&
      enableDesugaring(File('${appDir.path}/android/app/build.gradle.kts'))) {
    stdout.writeln('    Android: core library desugaring enabled');
  }
  if (copyAiFunction(toolkitRoot, appDir)) {
    stdout.writeln('    copied supabase/functions/ai-complete');
  }

  stdout.writeln('7/7 flutter pub get');
  await run('flutter', ['pub', 'get'], workingDirectory: appDir.path);

  stdout
    ..writeln('\nDone: ${appDir.path}')
    ..writeln('  lib/features/  your app (start here)')
    ..writeln('  lib/toolkit/   copied building blocks — your code now')
    ..writeln('  cd ${appDir.path}')
    ..writeln('  flutter test')
    ..writeln('  flutter run')
    ..writeln('Next steps: see QUICK_START.md in the toolkit.');
}

String _titleCase(String snake) => snake
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
