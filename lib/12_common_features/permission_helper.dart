/// Asks for a runtime permission (camera, microphone, photos, location,
/// notifications) and says clearly what happened, including the case the
/// app can no longer ask about.
///
/// Source: Couple `core/permissions/permission_service.dart`. Its rules are
/// kept: return early when already granted, never re-prompt a permanently
/// denied permission (the OS ignores it), and ask in context — right before
/// the feature that needs it, not at launch. Changed: the source returned a
/// bare `bool`, which hid "permanently denied"; [PermissionOutcome] lets the
/// UI offer "Open Settings" in exactly that case.
///
/// ```dart
/// final outcome = await requestPermission(Permission.camera);
/// switch (outcome) {
///   case PermissionOutcome.granted: openCamera();
///   case PermissionOutcome.blocked:
///     if (await showAppConfirm(context, title: 'Camera is off',
///         message: 'Turn it on in Settings to scan notes.', confirmLabel: 'Open Settings')) {
///       await openAppSettings();
///     }
///   case PermissionOutcome.denied: break; // they said no — respect it
/// }
/// ```
library;

import 'package:permission_handler/permission_handler.dart';

export 'package:permission_handler/permission_handler.dart'
    show Permission, openAppSettings;

enum PermissionOutcome {
  /// Usable now (including iOS "limited" photo access and provisional
  /// notifications).
  granted,

  /// Refused this time; asking again later is allowed.
  denied,

  /// Refused permanently or restricted by the device (parental controls,
  /// MDM). Only the Settings app can change it.
  blocked,
}

/// Maps a platform status onto the three outcomes the UI cares about.
PermissionOutcome outcomeFor(PermissionStatus status) => switch (status) {
  PermissionStatus.granted ||
  PermissionStatus.limited ||
  PermissionStatus.provisional => PermissionOutcome.granted,
  PermissionStatus.denied => PermissionOutcome.denied,
  PermissionStatus.permanentlyDenied ||
  PermissionStatus.restricted => PermissionOutcome.blocked,
};

/// Requests [permission] unless it is already granted or blocked.
Future<PermissionOutcome> requestPermission(Permission permission) async {
  final current = outcomeFor(await permission.status);
  if (current != PermissionOutcome.denied) return current;
  return outcomeFor(await permission.request());
}

/// The current outcome without prompting.
Future<PermissionOutcome> checkPermission(Permission permission) async =>
    outcomeFor(await permission.status);
