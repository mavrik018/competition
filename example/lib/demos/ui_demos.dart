import 'package:competition_toolkit/02_ui_elements/activity_heatmap.dart';
import 'package:competition_toolkit/02_ui_elements/animations.dart';
import 'package:competition_toolkit/02_ui_elements/app_buttons.dart';
import 'package:competition_toolkit/02_ui_elements/cards.dart';
import 'package:competition_toolkit/02_ui_elements/donut_chart.dart';
import 'package:competition_toolkit/02_ui_elements/line_chart.dart';
import 'package:competition_toolkit/02_ui_elements/radial_gauge.dart';
import 'package:competition_toolkit/02_ui_elements/text_inputs.dart';
import 'package:competition_toolkit/03_feedback/loading_overlay.dart';
import 'package:competition_toolkit/03_feedback/state_views.dart';
import 'package:competition_toolkit/04_dialogs_and_sheets/bottom_sheets.dart';
import 'package:competition_toolkit/05_forms/dynamic_form.dart';
import 'package:competition_toolkit/12_common_features/data_export.dart';
import 'package:competition_toolkit/12_common_features/qr_code.dart';
import 'package:flutter/material.dart';

import '../main.dart';

final uiDemos = <Demo>[
  Demo(
    'UI elements',
    'Buttons & inputs',
    (_) => const _ButtonsAndInputs(),
    subtitle: 'Variants, loading, PIN, tags',
  ),
  Demo('UI elements', 'Cards & charts', (_) => const _CardsAndCharts()),
  Demo('UI elements', 'Animations', (_) => const _Animations()),
  Demo(
    'Feedback & sheets',
    'Banners, overlays, sheets',
    (_) => const _Feedback(),
  ),
  Demo(
    'Forms',
    'Dynamic form',
    (_) => const _DynamicFormDemo(),
    subtitle: 'Built from a field list (or JSON)',
  ),
  Demo(
    'Device features',
    'QR codes & export',
    (_) => const _QrAndExport(),
    subtitle: 'Generate QR, CSV preview (scanning needs a device)',
  ),
];

class _ButtonsAndInputs extends StatefulWidget {
  const _ButtonsAndInputs();

  @override
  State<_ButtonsAndInputs> createState() => _ButtonsAndInputsState();
}

class _ButtonsAndInputsState extends State<_ButtonsAndInputs> {
  bool _loading = false;
  List<String> _tags = ['flutter'];
  String _pin = '';

  Future<void> _fakeSave() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      DemoBlock(
        'AppButton',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final variant in ButtonVariant.values)
              AppButton(
                label: variant.name,
                variant: variant,
                onPressed: () {},
              ),
            AppButton(
              label: 'Save',
              icon: Icons.save_outlined,
              isLoading: _loading,
              onPressed: _fakeSave,
            ),
          ],
        ),
      ),
      DemoBlock(
        'Social sign-in',
        child: Column(
          children: [
            for (final provider in SocialProvider.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SocialSignInButton(provider: provider, onPressed: () {}),
              ),
          ],
        ),
      ),
      const DemoBlock(
        'Text fields',
        child: Column(
          children: [
            AppTextField(label: 'Name', isRequired: true, clearable: true),
            SizedBox(height: 12),
            PasswordField(label: 'Password'),
          ],
        ),
      ),
      DemoBlock(
        'PinCodeField',
        note: _pin.isEmpty ? 'Type 6 digits' : 'Entered: $_pin',
        child: PinCodeField(onCompleted: (code) => setState(() => _pin = code)),
      ),
      DemoBlock(
        'TagInputField',
        child: TagInputField(
          tags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
          suggestions: const ['dart', 'riverpod', 'supabase'],
        ),
      ),
    ],
  );
}

class _CardsAndCharts extends StatelessWidget {
  const _CardsAndCharts();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return ListView(
      children: [
        const DemoBlock(
          'StatCard & ActionCard',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Study time',
                      value: '6h 20m',
                      icon: Icons.timer_outlined,
                      delta: 0.12,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Spending',
                      value: '€184',
                      icon: Icons.euro,
                      delta: 0.08,
                      higherIsBetter: false,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ActionCard(
                title: 'Start a focus session',
                subtitle: '25 minutes, no notifications',
                icon: Icons.play_circle_outline,
              ),
            ],
          ),
        ),
        const DemoBlock(
          'SimpleLineChart (with last week dashed)',
          child: SimpleLineChart(
            values: [30, 45, 28, 60, 52, 70, 64],
            comparison: [20, 35, 30, 40, 38, 45, 50],
            labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
        const DemoBlock(
          'DonutChart',
          child: DonutChart(
            segments: [
              ChartSegment('Rent', 700),
              ChartSegment('Food', 260),
              ChartSegment('Transport', 90),
              ChartSegment('Fun', 120),
            ],
            centerLabel: '€1,170',
            centerCaption: 'this month',
          ),
        ),
        DemoBlock(
          'Sparkline, RadialGauge, ActivityHeatmap',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Sparkline(values: [3, 5, 4, 8, 6, 9, 12]),
                  SizedBox(width: 24),
                  RadialGauge(value: 0.68, size: 72, child: Text('68%')),
                ],
              ),
              const SizedBox(height: 16),
              ActivityHeatmap(
                values: {
                  for (var i = 0; i < 70; i++)
                    DateTime(today.year, today.month, today.day - i):
                        (i * 7) % 5,
                },
                weeks: 10,
                today: today,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Animations extends StatefulWidget {
  const _Animations();

  @override
  State<_Animations> createState() => _AnimationsState();
}

class _AnimationsState extends State<_Animations> {
  final _shake = ShakeController();
  int _count = 120;
  int _checkKey = 0;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      DemoBlock(
        'AnimatedCounter',
        child: Row(
          children: [
            AnimatedCounter(
              value: _count,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Spacer(),
            AppButton(
              label: '+50',
              variant: ButtonVariant.tonal,
              onPressed: () => setState(() => _count += 50),
            ),
          ],
        ),
      ),
      DemoBlock(
        'SuccessCheckmark',
        child: Row(
          children: [
            SuccessCheckmark(key: ValueKey(_checkKey), size: 64),
            const Spacer(),
            AppButton(
              label: 'Replay',
              variant: ButtonVariant.tonal,
              onPressed: () => setState(() => _checkKey++),
            ),
          ],
        ),
      ),
      DemoBlock(
        'Shake (wrong answer)',
        child: Row(
          children: [
            Shake(
              controller: _shake,
              child: const Chip(label: Text('Wrong PIN')),
            ),
            const Spacer(),
            AppButton(
              label: 'Shake',
              variant: ButtonVariant.destructive,
              onPressed: _shake.shake,
            ),
          ],
        ),
      ),
    ],
  );
}

class _Feedback extends StatefulWidget {
  const _Feedback();

  @override
  State<_Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<_Feedback> {
  bool _overlay = false;

  @override
  Widget build(BuildContext context) => LoadingOverlay(
    isLoading: _overlay,
    message: 'Saving…',
    child: ListView(
      children: [
        DemoBlock(
          'StatusBanner',
          child: Column(
            children: [
              for (final kind in StatusKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StatusBanner(
                    kind: kind,
                    title: kind.name,
                    message: 'An inline ${kind.name} message.',
                  ),
                ),
            ],
          ),
        ),
        DemoBlock(
          'Loading',
          child: Wrap(
            spacing: 8,
            children: [
              AppButton(
                label: 'runWithLoading (1s)',
                variant: ButtonVariant.tonal,
                onPressed: () => runWithLoading(
                  context,
                  () => Future<void>.delayed(const Duration(seconds: 1)),
                  message: 'Working…',
                ),
              ),
              AppButton(
                label: 'Overlay (1s)',
                variant: ButtonVariant.outlined,
                onPressed: () async {
                  setState(() => _overlay = true);
                  await Future<void>.delayed(const Duration(seconds: 1));
                  if (mounted) setState(() => _overlay = false);
                },
              ),
            ],
          ),
        ),
        DemoBlock(
          'showAppBottomSheet',
          child: AppButton(
            label: 'Open sheet',
            variant: ButtonVariant.outlined,
            onPressed: () => showAppBottomSheet<void>(
              context,
              title: 'Filters',
              builder: (_) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Any content goes here.'),
              ),
              actions: (sheet) => [
                AppButton(
                  label: 'Apply',
                  expand: true,
                  onPressed: () => Navigator.pop(sheet),
                ),
              ],
            ),
          ),
        ),
        const DemoBlock(
          'Empty & error states',
          child: Column(
            children: [
              EmptyView(
                icon: Icons.inbox_outlined,
                title: 'No notes yet',
                message: 'Tap + to add your first note.',
                compact: true,
              ),
              ErrorView(message: "Couldn't load notes.", compact: true),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DynamicFormDemo extends StatefulWidget {
  const _DynamicFormDemo();

  @override
  State<_DynamicFormDemo> createState() => _DynamicFormDemoState();
}

class _DynamicFormDemoState extends State<_DynamicFormDemo> {
  Map<String, Object?>? _submitted;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      DynamicForm(
        fields: [
          const TextFieldSpec(key: 'name', label: 'Name', required: true),
          const TextFieldSpec(
            key: 'email',
            label: 'Email',
            kind: TextKind.email,
          ),
          const NumberFieldSpec(key: 'age', label: 'Age', min: 13, max: 120),
          const ChoiceFieldSpec(
            key: 'track',
            label: 'Track',
            options: [
              FieldOption('mobile', 'Mobile'),
              FieldOption('web', 'Web'),
              FieldOption('ai', 'AI'),
            ],
          ),
          const SwitchFieldSpec(key: 'newsletter', label: 'Send me updates'),
          const SliderFieldSpec(
            key: 'confidence',
            label: 'Confidence',
            min: 1,
            max: 5,
            divisions: 4,
          ),
          DateFieldSpec(
            key: 'start',
            label: 'Start date',
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          ),
        ],
        onSubmit: (values) => setState(() => _submitted = values),
      ),
      if (_submitted != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Submitted: $_submitted'),
        ),
    ],
  );
}

class _QrAndExport extends StatelessWidget {
  const _QrAndExport();

  @override
  Widget build(BuildContext context) {
    const wifi = QrWifi(ssid: 'Hackathon', password: 'letmein');
    final parsed = parseQr('WIFI:T:WPA;S:Hackathon;P:letmein;;');
    final csv = toCsv([
      ['Date', 'Item', 'Amount'],
      ['2026-03-01', 'Coffee, large', 3.2],
      ['2026-03-02', 'Bus "day" pass', 4.5],
    ]);
    return ListView(
      children: [
        DemoBlock(
          'QrCodeView',
          note: 'Encodes: ${wifi.encode()}',
          child: Center(child: QrCodeView(data: wifi.encode(), size: 180)),
        ),
        DemoBlock(
          'parseQr',
          note:
              'Scanning uses QrScannerView on a device; parsing works anywhere.',
          child: Text('${parsed.runtimeType}: ${parsed.encode()}'),
        ),
        DemoBlock(
          'toCsv (RFC 4180 quoting)',
          child: SelectableText(
            csv,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
