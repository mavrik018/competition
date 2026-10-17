// Showcase gallery for competition_toolkit.
//
// Every demo runs on fakes and in-memory data: no Supabase project, API key,
// camera, microphone or GPS is needed. Device-backed pieces (QR scanning,
// OCR, location, speech) are shown through their labelled test doubles —
// see each folder's README for the real setup.

import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demos/ai_demos.dart';
import 'demos/mini_app_demos.dart';
import 'demos/screen_demos.dart';
import 'demos/smart_demos.dart';
import 'demos/ui_demos.dart';

void main() => runApp(const ProviderScope(child: ShowcaseApp()));

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Competition Toolkit',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(AppPalette.studyBlue, Brightness.light),
    darkTheme: AppTheme.build(AppPalette.studyBlue, Brightness.dark),
    home: const GalleryHome(),
  );
}

/// One gallery entry. [fullScreen] demos build their own Scaffold (the
/// screen templates); the rest are shown inside a standard page.
class Demo {
  const Demo(
    this.section,
    this.title,
    this.builder, {
    this.subtitle,
    this.fullScreen = false,
  });

  final String section;
  final String title;
  final String? subtitle;
  final WidgetBuilder builder;
  final bool fullScreen;
}

final List<Demo> allDemos = [
  ...miniAppDemos,
  ...uiDemos,
  ...screenDemos,
  ...smartDemos,
  ...aiDemos,
];

class GalleryHome extends StatelessWidget {
  const GalleryHome({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<Demo>>{};
    for (final demo in allDemos) {
      (sections[demo.section] ??= []).add(demo);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Competition Toolkit')),
      body: ListView(
        children: [
          for (final MapEntry(key: section, value: demos)
              in sections.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                section,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            for (final demo in demos)
              ListTile(
                title: Text(demo.title),
                subtitle: demo.subtitle == null ? null : Text(demo.subtitle!),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => DemoPage(demo))),
              ),
          ],
        ],
      ),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage(this.demo, {super.key});

  final Demo demo;

  @override
  Widget build(BuildContext context) {
    if (demo.fullScreen) return demo.builder(context);
    return Scaffold(
      appBar: AppBar(title: Text(demo.title)),
      body: SafeArea(child: demo.builder(context)),
    );
  }
}

/// A titled block inside a demo page.
class DemoBlock extends StatelessWidget {
  const DemoBlock(this.title, {super.key, required this.child, this.note});

  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
