// Mini-app 2 — Volunteer match.
//
// Puzzle pieces: AuthFormScreen + ActionController (06, 08) · a session
// Notifier switching between sign-in and the app (the SessionGate idea, 07)
// · ListDetailScaffold (06) · SmartMatcher with explanations (13) ·
// XP, levels and badges (13) · ProfileTemplate (06) · snackbars (03).
//
// FakeVolunteerAuth is a labelled test double: it accepts one demo account
// and never contacts a server. Swap in AuthService (10) for real sign-in.

import 'package:competition_toolkit/02_ui_elements/app_buttons.dart';
import 'package:competition_toolkit/03_feedback/app_snackbars.dart';
import 'package:competition_toolkit/06_screen_templates/auth_form_screen.dart';
import 'package:competition_toolkit/06_screen_templates/list_detail_scaffold.dart';
import 'package:competition_toolkit/06_screen_templates/profile_template.dart';
import 'package:competition_toolkit/07_navigation/tab_shell.dart';
import 'package:competition_toolkit/08_state_management/action_controller.dart';
import 'package:competition_toolkit/10_backend/app_exception.dart';
import 'package:competition_toolkit/13_smart_features/gamification.dart';
import 'package:competition_toolkit/13_smart_features/smart_matching.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Data ────────────────────────────────────────────────────────────────────

typedef Volunteer = ({Set<String> skills, double km, Set<int> freeDays});
typedef Opportunity = ({
  String id,
  String title,
  String org,
  Set<String> skills,
  double km,
  int day, // 1 = Monday … 7 = Sunday
});

const opportunities = <Opportunity>[
  (
    id: 'o1',
    title: 'Food bank sorting',
    org: 'City Pantry',
    skills: {'lifting', 'teamwork'},
    km: 2,
    day: 6,
  ),
  (
    id: 'o2',
    title: 'Homework club tutor',
    org: 'Northside Library',
    skills: {'maths', 'teaching'},
    km: 4,
    day: 3,
  ),
  (
    id: 'o3',
    title: 'Park clean-up',
    org: 'Green Streets',
    skills: {'teamwork'},
    km: 8,
    day: 7,
  ),
  (
    id: 'o4',
    title: 'Website refresh',
    org: 'Animal Rescue',
    skills: {'coding', 'design'},
    km: 15,
    day: 2,
  ),
  (
    id: 'o5',
    title: 'Senior tech help',
    org: 'Silver Club',
    skills: {'teaching', 'coding'},
    km: 1,
    day: 6,
  ),
];

const me = (
  skills: {'teaching', 'coding', 'teamwork'},
  km: 0.0,
  freeDays: {6, 7},
);

final matcher = SmartMatcher<Volunteer, Opportunity>([
  MatchCriterion(
    'Skills',
    weight: 3,
    required: true,
    score: (v, o) => coverage(o.skills, v.skills),
  ),
  MatchCriterion(
    'Distance',
    weight: 2,
    score: (v, o) => proximityScore(o.km, maxKm: 10),
  ),
  MatchCriterion(
    'Availability',
    score: (v, o) => v.freeDays.contains(o.day) ? 1 : 0,
  ),
]);

const xpRules = XpRules({'signed_up': 40});
final badges = [
  AchievementBadge.fromJson({
    'id': 'first',
    'title': 'First shift',
    'icon': 'heart',
    'when': {'field': 'shifts', 'op': '>=', 'value': 1},
  }),
  AchievementBadge.fromJson({
    'id': 'three',
    'title': 'Regular',
    'icon': 'star',
    'when': {'field': 'shifts', 'op': '>=', 'value': 3},
  }),
];

// ── Auth (fake) and state ──────────────────────────────────────────────────

/// **Test double**, not authentication: accepts demo@example.com /
/// volunteer1 after a short delay so the loading state is visible.
class FakeVolunteerAuth {
  static const demoEmail = 'demo@example.com';
  static const demoPassword = 'volunteer1';

  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (email.toLowerCase() != demoEmail || password != demoPassword) {
      throw const AppException('Wrong email or password.');
    }
  }
}

final volunteerAuthProvider = Provider((ref) => FakeVolunteerAuth());

/// Signed-in email, or null.
class VolunteerSession extends Notifier<String?> {
  @override
  String? build() => null;
  void signedIn(String email) => state = email;
  void signOut() => state = null;
}

final volunteerSessionProvider = NotifierProvider<VolunteerSession, String?>(
  VolunteerSession.new,
);

/// Ids of opportunities the user signed up for.
class SignedUp extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void add(String id) => state = {...state, id};
}

final signedUpProvider = NotifierProvider<SignedUp, Set<String>>(SignedUp.new);

final signInAction =
    NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(
      ActionController.new,
    );

// ── App ─────────────────────────────────────────────────────────────────────

/// Reads its providers from the app's single ProviderScope (above
/// MaterialApp). A ProviderScope placed *here* would be invisible to the
/// detail page that ListDetailScaffold pushes on phones — pushed routes live
/// under the Navigator, not under this widget.
class VolunteerMatchApp extends ConsumerWidget {
  const VolunteerMatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(volunteerSessionProvider) == null
      ? const _SignIn()
      : TabShell(
          destinations: [
            TabDestination(
              label: 'Matches',
              icon: Icons.volunteer_activism_outlined,
              builder: (_) => const _Matches(),
            ),
            TabDestination(
              label: 'Profile',
              icon: Icons.person_outline,
              builder: (_) => const _Profile(),
            ),
          ],
        );
}

class _SignIn extends ConsumerWidget {
  const _SignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(signInAction);
    return AuthFormScreen(
      mode: AuthMode.signIn,
      title: 'Volunteer match',
      subtitle:
          'Demo account: ${FakeVolunteerAuth.demoEmail} / '
          '${FakeVolunteerAuth.demoPassword}',
      isLoading: action.isLoading,
      errorText: action.hasError
          ? AppException.from(action.error!).message
          : null,
      onSubmit: (data) async {
        final ok = await ref
            .read(signInAction.notifier)
            .run(
              () => ref
                  .read(volunteerAuthProvider)
                  .signIn(data.email, data.password),
            );
        if (ok) {
          ref.read(volunteerSessionProvider.notifier).signedIn(data.email);
        }
      },
    );
  }
}

class _Matches extends ConsumerWidget {
  const _Matches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = matcher.rank(me, opportunities);
    final joined = ref.watch(signedUpProvider);
    return ListDetailScaffold<MatchResult<Opportunity>>(
      title: 'Best matches',
      items: ranked,
      idOf: (r) => r.candidate.id,
      detailTitleOf: (r) => r.candidate.title,
      tileBuilder: (context, r, selected, open) => ListTile(
        selected: selected,
        leading: CircleAvatar(child: Text('${r.percent}')),
        title: Text(r.candidate.title),
        subtitle: Text(r.candidate.org),
        trailing: joined.contains(r.candidate.id)
            ? const Icon(Icons.check_circle, semanticLabel: 'Signed up')
            : null,
        onTap: open,
      ),
      detailBuilder: (context, r) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(r.candidate.org, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Match ${r.percent}% — ${r.explanation}'),
          const SizedBox(height: 4),
          Text('Why: ${r.strengths().join(', ')}'),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final done = ref.watch(signedUpProvider).contains(r.candidate.id);
              return AppButton(
                label: done ? 'Signed up' : 'Sign up (+40 XP)',
                icon: done ? Icons.check : Icons.how_to_reg,
                expand: true,
                onPressed: done
                    ? null
                    : () {
                        final before = ref.read(signedUpProvider).length;
                        ref.read(signedUpProvider.notifier).add(r.candidate.id);
                        final earned = newlyUnlocked(
                          badges,
                          stats: {'shifts': before + 1},
                          alreadyEarned: _earnedIds(before),
                        );
                        context.showSuccess(
                          earned.isEmpty
                              ? 'Signed up for ${r.candidate.title}'
                              : 'Badge unlocked: ${earned.first.title}',
                        );
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}

Set<String> _earnedIds(int shifts) => {
  for (final b in badges)
    if (b.when.evaluate({'shifts': shifts})) b.id,
};

class _Profile extends ConsumerWidget {
  const _Profile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(signedUpProvider).length;
    final xp = shifts * xpRules.pointsFor('signed_up');
    return ProfileTemplate(
      name: ref.watch(volunteerSessionProvider) ?? '',
      subtitle: 'Volunteer',
      stats: [
        ProfileStat('Shifts', '$shifts'),
        ProfileStat('XP', '$xp'),
        ProfileStat('Level', '${const LevelCurve().progressFor(xp).level}'),
      ],
      sections: [
        XpProgressBar(totalXp: xp),
        BadgeGrid(badges: badges, earned: _earnedIds(shifts)),
        AppButton(
          label: 'Sign out',
          variant: ButtonVariant.outlined,
          onPressed: () =>
              ref.read(volunteerSessionProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
