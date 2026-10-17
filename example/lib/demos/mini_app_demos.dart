import '../main.dart';
import '../mini_apps/expense_tracker.dart';
import '../mini_apps/shared_list.dart';
import '../mini_apps/volunteer_match.dart';

const _section = 'Mini-apps (components combined)';

final miniAppDemos = <Demo>[
  Demo(
    _section,
    'Expense tracker',
    (_) => const ExpenseTrackerApp(),
    subtitle: 'Form + persisted list + insights + CSV export',
    fullScreen: true,
  ),
  Demo(
    _section,
    'Volunteer match',
    (_) => const VolunteerMatchApp(),
    subtitle: 'Sign-in + matching + list/detail + XP & badges',
    fullScreen: true,
  ),
  Demo(
    _section,
    'Shared shopping list',
    (_) => const SharedListApp(),
    subtitle: 'Real-time CRDT + voice + offline banner',
    fullScreen: true,
  ),
];
