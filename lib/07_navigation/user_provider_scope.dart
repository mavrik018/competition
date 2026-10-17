/// Gives every signed-in account its own fresh Riverpod [ProviderScope], so
/// nothing one user loaded (their notes, their plan, a cached avatar URL)
/// can ever be read by the next user on the same device.
///
/// Source: Cookly `app/user_scope.dart`. Cookly's reasoning, kept verbatim in
/// spirit: replacing the scope is a guarantee, whereas a hand-kept list of
/// providers to invalidate on sign-out is not — StudyBuddies' `AuthNotifier`
/// maintained such a list (nine providers) and it had to be updated by hand
/// for every new feature. Generalised from Supabase to any stream of user
/// ids.
///
/// ```dart
/// runApp(UserProviderScope(
///   initialUserId: supabase.auth.currentUser?.id,
///   userIds: supabase.auth.onAuthStateChange.map((e) => e.session?.user.id),
///   child: const App(),
/// ));
/// ```
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

class UserProviderScope extends StatefulWidget {
  const UserProviderScope({
    super.key,
    required this.userIds,
    required this.child,
    this.initialUserId,
    this.overrides = const [],
  });

  /// Emits the current user id on every auth change (null when signed out).
  final Stream<String?> userIds;
  final String? initialUserId;

  /// Overrides applied to every generation of the scope.
  final List<Override> overrides;
  final Widget child;

  @override
  State<UserProviderScope> createState() => _UserProviderScopeState();
}

class _UserProviderScopeState extends State<UserProviderScope> {
  StreamSubscription<String?>? _subscription;
  late String? _userId = widget.initialUserId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.userIds.listen((next) {
      // Token refreshes re-emit the same id; only a real change resets.
      if (next == _userId || !mounted) return;
      setState(() {
        _userId = next;
        _generation++;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A new key throws the old ProviderContainer away (disposing every
    // provider in it) and starts an empty one.
    return ProviderScope(
      key: ValueKey(_generation),
      overrides: widget.overrides,
      child: widget.child,
    );
  }
}
