/// Runs one user-triggered async action (sign in, save, delete) and exposes
/// its progress as an [AsyncValue] the UI can watch: loading disables the
/// button, an error renders inline, and a second tap while busy is ignored.
///
/// Source: Cookly `AuthController._run` (returns whether it succeeded, so
/// the screen can navigate without re-reading state) merged with
/// StudyBuddies `AuthNotifier._run` (rejects a second submit while the
/// first is in flight — a double tap used to create two sign-ups).
///
/// Declare one provider per action so screens do not share loading state:
///
/// ```dart
/// final saveNoteAction =
///     NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(ActionController.new);
///
/// // In the widget:
/// final save = ref.watch(saveNoteAction);
/// PrimaryButton(
///   label: 'Save',
///   isLoading: save.isLoading,
///   onPressed: () async {
///     final ok = await ref.read(saveNoteAction.notifier).run(() => repo.save(note));
///     if (ok && context.mounted) Navigator.pop(context);
///   },
/// );
/// if (save.hasError) Text(AppException.from(save.error!).message);
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  /// Runs [action]. Returns true on success, false on failure or when an
  /// earlier action is still running (in which case nothing runs).
  Future<bool> run(Future<void> Function() action) async {
    if (isBusy) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Clears a shown error — e.g. when the user starts editing again.
  void reset() => state = const AsyncData(null);
}
