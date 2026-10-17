import 'dart:math' as math;

import 'package:competition_toolkit/02_ui_elements/flip_card.dart';
import 'package:competition_toolkit/02_ui_elements/spin_wheel.dart';
import 'package:competition_toolkit/02_ui_elements/swipe_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('FlipCard', () {
    Widget card(bool showBack) => wrap(
      Center(
        child: SizedBox(
          width: 200,
          height: 120,
          child: FlipCard(
            showBack: showBack,
            front: const Text('question'),
            back: const Text('answer'),
          ),
        ),
      ),
    );

    testWidgets('turns over when showBack changes', (tester) async {
      await tester.pumpWidget(card(false));
      expect(find.text('question'), findsOneWidget);
      expect(find.text('answer'), findsNothing);

      await tester.pumpWidget(card(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('question'), findsOneWidget); // still before halfway
      await tester.pumpAndSettle();
      expect(find.text('answer'), findsOneWidget);
      expect(find.text('question'), findsNothing);
    });

    testWidgets('starts on the back without animating when built so', (
      tester,
    ) async {
      await tester.pumpWidget(card(true));
      expect(find.text('answer'), findsOneWidget);
    });

    testWidgets('reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          FlipCard(
            showBack: false,
            onTap: () => taps++,
            front: const Text('front'),
            back: const Text('back'),
          ),
        ),
      );
      await tester.tap(find.text('front'));
      expect(taps, 1);
    });
  });

  group('SwipeActionTile', () {
    Widget tile({VoidCallback? onStart, VoidCallback? onEnd}) => wrap(
      Column(
        children: [
          SwipeActionTile(
            startAction: onStart == null
                ? null
                : SwipeAction(
                    icon: Icons.check,
                    color: Colors.green,
                    label: 'Complete',
                    onTriggered: onStart,
                  ),
            endAction: onEnd == null
                ? null
                : SwipeAction(
                    icon: Icons.delete,
                    color: Colors.red,
                    label: 'Delete',
                    dismisses: true,
                    onTriggered: onEnd,
                  ),
            child: Container(
              height: 60,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Text('row'),
            ),
          ),
        ],
      ),
    );

    testWidgets('swipe left reveals delete; tapping it collapses then fires', (
      tester,
    ) async {
      var deleted = 0;
      await tester.pumpWidget(tile(onEnd: () => deleted++));
      await tester.drag(find.text('row'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump(const Duration(milliseconds: 100));
      expect(deleted, 0); // waits for the collapse
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('a short swipe snaps back closed', (tester) async {
      await tester.pumpWidget(tile(onEnd: () {}));
      await tester.drag(find.text('row'), const Offset(-20, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('cannot swipe towards a side with no action', (tester) async {
      await tester.pumpWidget(tile(onEnd: () {}));
      await tester.drag(find.text('row'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
      expect(tester.getCenter(find.text('row')).dx, 400);
    });

    testWidgets('non-dismissing action fires then closes', (tester) async {
      var done = 0;
      await tester.pumpWidget(tile(onStart: () => done++));
      await tester.drag(find.text('row'), const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('actions are offered to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      var deleted = 0;
      await tester.pumpWidget(tile(onEnd: () => deleted++));
      final node = tester.getSemantics(find.byType(SwipeActionTile));
      final actions = node.getSemanticsData().customSemanticsActionIds!;
      expect(actions, isNotEmpty);
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        actions.single,
      );
      await tester.pumpAndSettle();
      expect(deleted, 1);
      handle.dispose();
    });
  });

  group('SpinWheel maths', () {
    test('lands on the requested slice, spin after spin', () {
      final random = math.Random(7);
      for (final count in [2, 3, 6, 8, 12]) {
        var resting = 0.0;
        for (var spin = 0; spin < 50; spin++) {
          final index = random.nextInt(count);
          final end = spinEndAngle(
            restingAngle: resting,
            index: index,
            sliceCount: count,
          );
          expect(sliceUnderPointer(end, count), index);
          // Always spins forward by at least the requested full turns.
          expect(end - resting, greaterThanOrEqualTo(4 * 2 * math.pi - 1e-9));
          expect(end - resting, lessThanOrEqualTo(5 * 2 * math.pi + 1e-9));
          resting = end;
        }
      }
    });

    test('slice 0 is under the pointer at rest', () {
      expect(sliceUnderPointer(0.01, 4), 3); // slightly clockwise → last slice
      expect(sliceUnderPointer(-0.01, 4), 0);
    });
  });

  testWidgets('SpinWheel reports the slice it settles on, twice', (
    tester,
  ) async {
    final controller = SpinWheelController();
    addTearDown(controller.dispose);
    final settled = <int>[];
    await tester.pumpWidget(
      wrap(
        Center(
          child: SpinWheel(
            controller: controller,
            onSettled: settled.add,
            slices: const [
              WheelSlice(label: 'A', color: Colors.red),
              WheelSlice(label: 'B', color: Colors.green),
              WheelSlice(label: 'C', color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    controller.spinTo(1);
    await tester.pump();
    expect(controller.isSpinning, isTrue);
    controller.spinTo(2); // ignored while spinning
    await tester.pumpAndSettle();
    controller.spinTo(0);
    await tester.pumpAndSettle();
    expect(settled, [1, 0]);
    expect(controller.isSpinning, isFalse);
  });
}
