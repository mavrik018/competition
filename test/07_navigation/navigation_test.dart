import 'dart:async';

import 'package:competition_toolkit/07_navigation/deep_link_queue.dart';
import 'package:competition_toolkit/07_navigation/page_transitions.dart';
import 'package:competition_toolkit/07_navigation/router_guard.dart';
import 'package:competition_toolkit/07_navigation/session_gate.dart';
import 'package:competition_toolkit/07_navigation/tab_shell.dart';
import 'package:competition_toolkit/07_navigation/user_provider_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.name);
  final String name;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('${widget.name} $count'),
  );
}

void main() {
  group('TabShell', () {
    testWidgets('builds tabs lazily and keeps their state', (tester) async {
      var profileBuilds = 0;
      final reselected = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: TabShell(
            onReselect: reselected.add,
            destinations: [
              TabDestination(
                label: 'Home',
                icon: Icons.home,
                builder: (_) => const _Counter('home'),
              ),
              TabDestination(
                label: 'Profile',
                icon: Icons.person,
                builder: (_) {
                  profileBuilds++;
                  return const _Counter('profile');
                },
              ),
            ],
          ),
        ),
      );
      expect(profileBuilds, 0);
      await tester.tap(find.text('home 0'));
      await tester.pump();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(profileBuilds, 1);
      expect(find.text('profile 0'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('home 1'), findsOneWidget); // state kept

      await tester.tap(find.text('Home'));
      expect(reselected, [0]);
    });
  });

  group('SessionController', () {
    late StreamController<String?> auth;
    String? current;
    late Map<String, Object> setup; // userId → true/false or an error

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          sessionSourceProvider.overrideWithValue(
            SessionSource(
              userIds: auth.stream,
              currentUserId: () => current,
              isSetupComplete: (uid) async {
                final answer = setup[uid];
                if (answer is Exception) throw answer;
                return answer == true;
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() {
      auth = StreamController<String?>.broadcast();
      current = null;
      setup = {};
    });
    tearDown(() => auth.close());

    test('signed out when there is no restored user', () {
      final c = container();
      expect(c.read(sessionProvider), isA<SessionSignedOut>());
    });

    test('restored user goes loading → ready', () async {
      current = 'u1';
      setup['u1'] = true;
      final c = container();
      expect(c.read(sessionProvider), isA<SessionLoading>());
      await settle();
      expect(c.read(sessionProvider), isA<SessionReady>());
    });

    test('incomplete setup, then refresh after finishing it', () async {
      current = 'u1';
      setup['u1'] = false;
      final c = container();
      c.read(sessionProvider);
      await settle();
      expect(c.read(sessionProvider), isA<SessionNeedsSetup>());
      setup['u1'] = true;
      await c.read(sessionProvider.notifier).refresh();
      expect((c.read(sessionProvider) as SessionReady).userId, 'u1');
    });

    test('auth events drive sign-in and sign-out', () async {
      setup['u2'] = true;
      final c = container();
      c.listen(sessionProvider, (_, _) {});
      auth.add('u2');
      await settle();
      await settle();
      expect(c.read(sessionProvider), isA<SessionReady>());
      auth.add(null);
      await settle();
      expect(c.read(sessionProvider), isA<SessionSignedOut>());
    });

    test(
      'a failed first check is retryable instead of an endless splash',
      () async {
        current = 'u1';
        setup['u1'] = Exception('offline');
        final c = container();
        c.read(sessionProvider);
        await settle();
        expect(c.read(sessionProvider), isA<SessionCheckFailed>());
        setup['u1'] = true;
        await c.read(sessionProvider.notifier).refresh();
        expect(c.read(sessionProvider), isA<SessionReady>());
      },
    );

    test('a failed refresh keeps a signed-in user where they are', () async {
      current = 'u1';
      setup['u1'] = true;
      final c = container();
      c.read(sessionProvider);
      await settle();
      setup['u1'] = Exception('offline');
      await c.read(sessionProvider.notifier).refresh();
      expect(c.read(sessionProvider), isA<SessionReady>());
    });

    test('works without a setup step', () async {
      final c = ProviderContainer(
        overrides: [
          sessionSourceProvider.overrideWithValue(
            SessionSource(userIds: auth.stream, currentUserId: () => 'u9'),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.read(sessionProvider);
      await settle();
      expect(c.read(sessionProvider), isA<SessionReady>());
    });
  });

  testWidgets('SessionGate builds the screen for each state', (tester) async {
    Widget gate(SessionState state) => MaterialApp(
      home: SessionGate(
        state: state,
        loading: (_) => const Text('splash'),
        signedOut: (_) => const Text('sign in'),
        needsSetup: (_, id) => Text('setup $id'),
        ready: (_, id) => Text('home $id'),
        checkFailed: (_, error) => const Text('retry'),
      ),
    );
    await tester.pumpWidget(gate(const SessionLoading()));
    expect(find.text('splash'), findsOneWidget);
    await tester.pumpWidget(gate(const SessionNeedsSetup('a')));
    await tester.pumpAndSettle();
    expect(find.text('setup a'), findsOneWidget);
    await tester.pumpWidget(gate(const SessionReady('a')));
    await tester.pumpAndSettle();
    expect(find.text('home a'), findsOneWidget);
    await tester.pumpWidget(gate(SessionCheckFailed('a', Exception())));
    await tester.pumpAndSettle();
    expect(find.text('retry'), findsOneWidget);
  });

  group('DeepLinkQueue', () {
    test('holds the latest link until ready, then opens it once', () {
      var ready = false;
      final opened = <String>[];
      final queue = DeepLinkQueue(isReady: () => ready, open: opened.add);

      queue.handle('/note/1');
      queue.handle('/note/2');
      expect(opened, isEmpty);
      expect(queue.pending, '/note/2');

      queue.flush(); // still not ready
      expect(opened, isEmpty);

      ready = true;
      queue.flush();
      queue.flush();
      expect(opened, ['/note/2']);

      queue.handle('/note/3');
      expect(opened, ['/note/2', '/note/3']);
    });

    test('clear drops a held link', () {
      final opened = <String>[];
      final queue = DeepLinkQueue(isReady: () => false, open: opened.add)
        ..handle('/x')
        ..clear();
      expect(queue.pending, isNull);
    });
  });

  group('guardRedirect', () {
    String? go(
      String location, {
      bool loading = false,
      bool signedIn = false,
      bool onboarded = true,
    }) => guardRedirect(
      location: location,
      isLoading: loading,
      isSignedIn: signedIn,
      onboardingDone: onboarded,
      publicPaths: const {'/privacy'},
    );

    test('loading holds everything on splash', () {
      expect(go('/notes', loading: true), '/splash');
      expect(go('/splash', loading: true), isNull);
    });

    test('first run goes to onboarding before sign-in', () {
      expect(go('/notes', onboarded: false), '/onboarding');
      expect(go('/onboarding', onboarded: false), isNull);
    });

    test('signed out goes to sign-in except public pages', () {
      expect(go('/notes'), '/sign-in');
      expect(go('/sign-in'), isNull);
      expect(go('/privacy'), isNull);
    });

    test('signed in leaves entry routes for home', () {
      for (final entry in ['/splash', '/onboarding', '/sign-in']) {
        expect(go(entry, signedIn: true), '/');
      }
      expect(go('/notes', signedIn: true), isNull);
    });
  });

  test('RouterRefresh notifies when a watched provider changes', () {
    final counter = NotifierProvider<_Count, int>(_Count.new);
    late RouterRefresh refresh;
    final holder = Provider<RouterRefresh>((ref) {
      refresh = RouterRefresh(ref, [counter]);
      return refresh;
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(holder);
    var notified = 0;
    refresh.addListener(() => notified++);
    c.read(counter.notifier).increment();
    expect(notified, 1);
  });

  testWidgets('UserProviderScope gives each user a fresh container', (
    tester,
  ) async {
    final users = StreamController<String?>();
    addTearDown(users.close);
    final counter = NotifierProvider<_Count, int>(_Count.new);

    await tester.pumpWidget(
      UserProviderScope(
        initialUserId: 'a',
        userIds: users.stream,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => ref.read(counter.notifier).increment(),
              child: Text('count ${ref.watch(counter)}'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    users.add('a'); // same user (token refresh): no reset
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    users.add('b');
    await tester.pump();
    await tester.pump();
    expect(find.text('count 0'), findsOneWidget);
  });

  testWidgets('fade-through transition and unfocus observer', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: ThemeData(pageTransitionsTheme: fadeThroughTransitions),
        navigatorObservers: [UnfocusOnNavigate()],
        home: const Scaffold(body: TextField()),
      ),
    );
    FocusNode fieldFocus() => tester
        .widget<EditableText>(find.byType(EditableText, skipOffstage: false))
        .focusNode;
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(fieldFocus().hasFocus, isTrue);

    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('next')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    expect(fieldFocus().hasFocus, isFalse);
  });
}

class _Count extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}
