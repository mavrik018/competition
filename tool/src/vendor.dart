// Copies toolkit source files into an app (lib/toolkit/), so the app owns
// the code instead of depending on the toolkit package. Used by
// tool/create_app.dart and tool/add_component.dart.
//
// What "copy a file" means here:
//   * the file plus every toolkit file it imports (relative imports are
//     followed transitively, so the copy always compiles);
//   * the folder README of every folder touched (reference docs);
//   * every toolkit test whose toolkit imports were all copied, into
//     test/toolkit/, with `package:competition_toolkit/` rewritten to
//     `package:<app>/toolkit/`;
//   * the pub packages those files import, with the toolkit's version
//     constraints.
// Files that already exist in the app are never overwritten: once copied,
// the code is the app's own and may have been edited.
//
// No packages needed: dart:io only.

import 'dart:io';

const toolkitPackage = 'competition_toolkit';

/// Packages that come with Flutter or the app itself: never added to pubspec.
const _sdkPackages = {'flutter', 'flutter_test', toolkitPackage};

/// `import 'x.dart'` / `export '../y/z.dart'` (no `package:` or `dart:`).
final _relativeImport = RegExp(
  r'''^\s*(?:import|export)\s+'([^':]+)'(?=[\s;])''',
  multiLine: true,
);
final _packageImport = RegExp(
  r'''^\s*(?:import|export)\s+'package:([a-z0-9_]+)/''',
  multiLine: true,
);

class Vendor {
  Vendor(this.toolkitRoot, this.appDir, this.appName);

  final Directory toolkitRoot;
  final Directory appDir;
  final String appName;

  String get _lib => '${toolkitRoot.path}/lib';
  String get _test => '${toolkitRoot.path}/test';

  /// Every library file in the toolkit, as paths relative to lib/
  /// (e.g. `09_persistence/repository.dart`).
  List<String> allLibFiles() => _dartFilesUnder(_lib);

  /// Resolves user input (`13_smart_features`, `13_smart_features/trends`,
  /// `lib/12_common_features/qr_code.dart`) to lib-relative file paths.
  List<String> resolve(String spec) {
    var s = spec.replaceAll(r'\', '/');
    if (s.startsWith('lib/')) s = s.substring(4);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (Directory('$_lib/$s').existsSync()) {
      return allLibFiles().where((f) => f.startsWith('$s/')).toList();
    }
    if (!s.endsWith('.dart')) s = '$s.dart';
    if (File('$_lib/$s').existsSync()) return [s];
    final byName = allLibFiles().where((f) => f.endsWith('/$s')).toList();
    if (byName.length == 1) return byName;
    throw ArgumentError(
      byName.isEmpty
          ? 'No toolkit file or folder "$spec" (see CATALOG.md).'
          : '"$spec" is ambiguous: ${byName.join(', ')}',
    );
  }

  /// [seeds] plus every toolkit file they import, transitively.
  Set<String> closure(Iterable<String> seeds) {
    final done = <String>{};
    final todo = [...seeds];
    while (todo.isNotEmpty) {
      final file = todo.removeLast();
      if (!done.add(file)) continue;
      final text = File('$_lib/$file').readAsStringSync();
      for (final m in _relativeImport.allMatches(text)) {
        final target = _normalize('${_dirOf(file)}/${m.group(1)}');
        if (File('$_lib/$target').existsSync()) todo.add(target);
      }
    }
    return done;
  }

  /// Toolkit files imported by app code (`package:<app>/toolkit/...`) or by
  /// template code (`package:competition_toolkit/...`).
  Set<String> toolkitImportsIn(String text) => {
    for (final m in RegExp(
      "package:(?:$toolkitPackage|$appName/toolkit)/([^']+)'",
    ).allMatches(text))
      m.group(1)!,
  };

  /// Copies [files] (lib-relative) into lib/toolkit/ plus folder READMEs.
  /// Returns the files actually written (existing ones are kept).
  List<String> copyLib(Iterable<String> files) {
    final written = <String>[];
    for (final file in files.toList()..sort()) {
      final target = File('${appDir.path}/lib/toolkit/$file');
      if (target.existsSync()) continue;
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(File('$_lib/$file').readAsStringSync());
      written.add(file);
    }
    for (final folder in {for (final f in files) _dirOf(f)}) {
      final readme = File('$_lib/$folder/README.md');
      final target = File('${appDir.path}/lib/toolkit/$folder/README.md');
      if (readme.existsSync() && !target.existsSync()) {
        target.writeAsStringSync(rewrite(readme.readAsStringSync()));
      }
    }
    _writeIndex();
    return written;
  }

  /// Copies every toolkit test whose toolkit imports are all present in the
  /// app's lib/toolkit/. Returns the test files written.
  List<String> copyTests() {
    final present = _dartFilesUnder('${appDir.path}/lib/toolkit').toSet();
    final helpers = File('$_test/helpers.dart');
    final helperNeeds = toolkitImportsIn(helpers.readAsStringSync());
    final written = <String>[];
    for (final file in _dartFilesUnder(_test)) {
      if (file == 'helpers.dart') continue;
      final text = File('$_test/$file').readAsStringSync();
      final needs = toolkitImportsIn(text);
      if (text.contains("'../helpers.dart'")) needs.addAll(helperNeeds);
      if (!present.containsAll(needs)) continue;
      final target = File('${appDir.path}/test/toolkit/$file');
      if (target.existsSync()) continue;
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(rewrite(text));
      written.add(file);
      final helperTarget = File('${appDir.path}/test/toolkit/helpers.dart');
      if (text.contains("'../helpers.dart'") && !helperTarget.existsSync()) {
        helperTarget.writeAsStringSync(rewrite(helpers.readAsStringSync()));
      }
    }
    return written;
  }

  /// `package:competition_toolkit/x` → `package:<app>/toolkit/x`.
  String rewrite(String text) =>
      text.replaceAll('package:$toolkitPackage/', 'package:$appName/toolkit/');

  /// Adds the pub packages imported under lib/ (dependencies) and test/
  /// (dev_dependencies) that pubspec.yaml does not list yet, using the
  /// toolkit's version constraints. Returns the packages added.
  List<String> syncPubspec({Set<String> alwaysAdd = const {}}) {
    final versions = _toolkitVersions();
    final pubspec = File('${appDir.path}/pubspec.yaml');
    var yaml = pubspec.readAsStringSync();
    bool listed(String p) => RegExp('^  $p:', multiLine: true).hasMatch(yaml);

    final deps = {
      ..._packagesUnder('${appDir.path}/lib'),
      ...alwaysAdd,
    }.where((p) => !listed(p)).toList()..sort();
    final devDeps = _packagesUnder(
      '${appDir.path}/test',
    ).where((p) => !listed(p) && !deps.contains(p)).toList()..sort();

    String lines(List<String> pkgs) => [
      for (final p in pkgs)
        if (versions[p] != null) '  $p: ${versions[p]}\n',
    ].join();
    final missing = [
      ...deps,
      ...devDeps,
    ].where((p) => versions[p] == null).toList();
    if (missing.isNotEmpty) {
      stderr.writeln(
        'Warning: no version for ${missing.join(', ')} in the toolkit '
        'pubspec.yaml; add them to ${pubspec.path} by hand.',
      );
    }

    yaml = _insertAfter(
      yaml,
      RegExp(
        r'^dependencies:\r?\n(  flutter:\r?\n    sdk: flutter\r?\n)?',
        multiLine: true,
      ),
      lines(deps),
    );
    yaml = _insertAfter(
      yaml,
      RegExp(
        r'^dev_dependencies:\r?\n(  flutter_test:\r?\n    sdk: flutter\r?\n)?',
        multiLine: true,
      ),
      lines(devDeps),
    );
    pubspec.writeAsStringSync(yaml);
    return [...deps, ...devDeps].where((p) => versions[p] != null).toList();
  }

  /// lib/toolkit/README.md: where the code came from and what is there.
  void _writeIndex() {
    final files = _dartFilesUnder('${appDir.path}/lib/toolkit')..sort();
    final byFolder = <String, List<String>>{};
    for (final f in files) {
      (byFolder[_dirOf(f)] ??= []).add(f.substring(f.lastIndexOf('/') + 1));
    }
    final b = StringBuffer()
      ..writeln('# toolkit/ — reusable building blocks (copied, now ours)')
      ..writeln()
      ..writeln(
        'These files were copied from the competition toolkit '
        '(`${toolkitRoot.path.replaceAll(r'\', '/')}`). They are plain source '
        'code of this app: read them, change them, delete what is unused. '
        'Nothing is imported from the toolkit package.',
      )
      ..writeln()
      ..writeln('* `lib/features/` is this app (screens, data, providers).')
      ..writeln('* `lib/toolkit/` is the generic parts those screens use.')
      ..writeln(
        '* `test/toolkit/` holds the toolkit tests for the copied files.',
      )
      ..writeln()
      ..writeln(
        'Copy more parts later (from the toolkit folder): '
        '`dart run tool/add_component.dart --app <this app> <folder or file>`. '
        'Per-folder notes: the README.md in each folder. All components: '
        "the toolkit's CATALOG.md (its `package:$toolkitPackage/` imports "
        'are `package:$appName/toolkit/` here).',
      )
      ..writeln()
      ..writeln('| Folder | Files |')
      ..writeln('|---|---|');
    for (final e in byFolder.entries) {
      b.writeln('| `${e.key}` | ${e.value.join(', ')} |');
    }
    File('${appDir.path}/lib/toolkit/README.md').writeAsStringSync('$b');
  }

  Map<String, String> _toolkitVersions() {
    final text = File('${toolkitRoot.path}/pubspec.yaml').readAsStringSync();
    return {
      for (final m in RegExp(
        r'^  ([a-z0-9_]+): (\^?[0-9][^\s#]*)',
        multiLine: true,
      ).allMatches(text))
        m.group(1)!: m.group(2)!,
    };
  }

  Set<String> _packagesUnder(String dir) => {
    for (final f in _dartFilesUnder(dir))
      for (final m in _packageImport.allMatches(
        File('$dir/$f').readAsStringSync(),
      ))
        if (!_sdkPackages.contains(m.group(1)) && m.group(1) != appName)
          m.group(1)!,
  };
}

List<String> _dartFilesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return [];
  final prefix = root.absolute.path.length + 1;
  return [
    for (final e in root.absolute.listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart'))
        e.path.substring(prefix).replaceAll(r'\', '/'),
  ];
}

String _dirOf(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '.' : path.substring(0, i);
}

String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

String _insertAfter(String text, RegExp anchor, String insert) {
  if (insert.isEmpty) return text;
  final m = anchor.firstMatch(text);
  if (m == null) {
    throw StateError('pubspec.yaml has no "${anchor.pattern}" section');
  }
  return text.replaceRange(m.end, m.end, insert);
}

/// Sets the app's Dart SDK constraint to the toolkit's. The copied code is
/// written and tested for that language version; a newer one (from
/// `flutter create`) turns on lints for features the toolkit cannot use yet.
void useToolkitSdk(Directory toolkitRoot, Directory appDir) {
  final sdk = RegExp(r'^  sdk: (\S+)', multiLine: true);
  final toolkit = sdk
      .firstMatch(File('${toolkitRoot.path}/pubspec.yaml').readAsStringSync())
      ?.group(1);
  final pubspec = File('${appDir.path}/pubspec.yaml');
  if (toolkit == null) return;
  pubspec.writeAsStringSync(
    pubspec.readAsStringSync().replaceFirst(sdk, '  sdk: $toolkit'),
  );
}

/// flutter_local_notifications (toolkit 12 reminders) requires core library
/// desugaring; without it `flutter build apk` fails at checkAarMetadata.
/// Returns true if the file was changed.
bool enableDesugaring(File gradle) {
  if (!gradle.existsSync()) return false;
  var text = gradle.readAsStringSync();
  if (text.contains('isCoreLibraryDesugaringEnabled')) return false;
  final options = RegExp(r'compileOptions \{\r?\n');
  if (!options.hasMatch(text)) {
    stderr.writeln(
      'Warning: enable core library desugaring in ${gradle.path} by hand '
      '(see the flutter_local_notifications README).',
    );
    return false;
  }
  text = text.replaceFirst(
    options,
    'compileOptions {\n'
    '        // Required by flutter_local_notifications (toolkit reminders).\n'
    '        isCoreLibraryDesugaringEnabled = true\n',
  );
  text =
      '${text.trimRight()}\n\n'
      'dependencies {\n'
      '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
      '}\n';
  gradle.writeAsStringSync(text);
  return true;
}

/// Copies the AI edge function (supabase/functions/ai-complete) when the
/// AI client is part of the app. Returns true if copied.
bool copyAiFunction(Directory toolkitRoot, Directory appDir) {
  if (!File(
    '${appDir.path}/lib/toolkit/14_ai/ai_text_client.dart',
  ).existsSync()) {
    return false;
  }
  final source = Directory(
    '${toolkitRoot.path}/supabase/functions/ai-complete',
  );
  final target = '${appDir.path}/supabase/functions/ai-complete';
  if (Directory(target).existsSync()) return false;
  for (final e in source.listSync()) {
    if (e is! File) continue;
    final name = e.path.split(RegExp(r'[\\/]')).last;
    File('$target/$name')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(e.readAsStringSync());
  }
  return true;
}

Future<void> run(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
  if (result.exitCode != 0) {
    stderr
      ..writeln('$executable ${arguments.join(' ')} failed:')
      ..writeln(result.stdout)
      ..writeln(result.stderr);
    exit(result.exitCode);
  }
}
