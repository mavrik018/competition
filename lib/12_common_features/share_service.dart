/// Opening the system share sheet for text, links and files, behind an
/// interface with a recording fake.
///
/// Source: Cookly and StudyBuddies called `share_plus` directly from
/// screens (recipe cards, exported notes). Wrapped so sharing flows can be
/// tested and demoed without a share sheet.
///
/// ```dart
/// final share = ref.read(shareServiceProvider);
/// await share.shareText('I scored 9/10 on the biology quiz!', subject: 'Quiz result');
///
/// final bytes = toCsv(rows).codeUnits;                         // see data_export.dart
/// await share.shareFile(name: 'expenses.csv', bytes: Uint8List.fromList(bytes), mimeType: 'text/csv');
/// ```
///
/// On iPad the share sheet must be anchored: pass [ShareService.shareText]'s
/// `origin` (the tapped button's rect) or it will not appear.
library;

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Whether the user actually shared (where the platform can tell).
enum ShareOutcome { shared, dismissed, unknown }

abstract interface class ShareService {
  Future<ShareOutcome> shareText(String text, {String? subject, Rect? origin});

  Future<ShareOutcome> shareFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    String? text,
    Rect? origin,
  });
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
    return _outcome(result);
  }

  @override
  Future<ShareOutcome> shareFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    String? text,
    Rect? origin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
        fileNameOverrides: [name],
        text: text,
        sharePositionOrigin: origin,
      ),
    );
    return _outcome(result);
  }

  ShareOutcome _outcome(ShareResult result) => switch (result.status) {
    ShareResultStatus.success => ShareOutcome.shared,
    ShareResultStatus.dismissed => ShareOutcome.dismissed,
    ShareResultStatus.unavailable => ShareOutcome.unknown,
  };
}

/// Records what would have been shared. **A test/demo double — nothing
/// leaves the app.**
class FakeShareService implements ShareService {
  final shared = <({String? text, String? fileName, int? bytes})>[];

  @override
  Future<ShareOutcome> shareText(
    String text, {
    String? subject,
    Rect? origin,
  }) async {
    shared.add((text: text, fileName: null, bytes: null));
    return ShareOutcome.shared;
  }

  @override
  Future<ShareOutcome> shareFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    String? text,
    Rect? origin,
  }) async {
    shared.add((text: text, fileName: name, bytes: bytes.length));
    return ShareOutcome.shared;
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SystemShareService(),
);
