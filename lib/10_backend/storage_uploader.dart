/// Uploads files to Supabase Storage with retries, cancellation and a
/// consistent path layout, plus a cache for short-lived signed URLs.
///
/// Source: Couple `core/storage/upload_manager.dart` (retry with backoff,
/// cancel handle checked between attempts, `{owner}/{folder}/{uuid}.{ext}`
/// paths) and `signed_url_cache.dart` (refresh a little before expiry so a
/// slow render never gets an expired link). Image/video compression was left
/// out — it pulls in two native plugins and belongs to the caller — and the
/// network calls are injected so the retry logic is unit-tested.
///
/// ```dart
/// final uploader = StorageUploader.supabase(client, bucket: 'media');
/// final handle = UploadHandle();          // keep it to cancel on screen exit
/// final path = await uploader.upload(
///   bytes: await file.readAsBytes(),
///   path: storagePath(ownerId: uid, folder: 'avatars', extension: 'jpg'),
///   contentType: 'image/jpeg',
///   handle: handle,
/// );
///
/// final urls = SignedUrlCache.supabase(client, bucket: 'media');
/// Image.network(await urls.get(path));
/// ```
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../09_persistence/local_id.dart';

/// Lets the UI cancel an upload (e.g. the user leaves the composer).
///
/// Cancellation is checked before each attempt, not mid-request — Supabase's
/// upload has no abort hook — so one in-flight attempt may still finish.
/// Write the database row that references the file only after `upload`
/// returns, so a cancelled upload never leaves a dangling reference.
class UploadHandle {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class UploadCancelled implements Exception {
  const UploadCancelled();
  @override
  String toString() => 'UploadCancelled';
}

/// `{ownerId}/{folder}/{uuid}.{extension}` — scoping by owner first is what
/// lets a Storage RLS policy check `(storage.foldername(name))[1] = auth.uid()`.
String storagePath({
  required String ownerId,
  required String folder,
  required String extension,
  String? id,
}) =>
    '$ownerId/$folder/${id ?? generateLocalId()}.${extension.replaceFirst('.', '')}';

typedef BytesUploader =
    Future<void> Function(String path, Uint8List bytes, String? contentType);

class StorageUploader {
  StorageUploader({
    required BytesUploader uploadBytes,
    this.maxAttempts = 3,
    Future<void> Function(Duration)? wait,
  }) : _uploadBytes = uploadBytes,
       _wait = wait ?? Future<void>.delayed;

  factory StorageUploader.supabase(
    SupabaseClient client, {
    required String bucket,
  }) => StorageUploader(
    uploadBytes: (path, bytes, contentType) => client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        ),
  );

  final BytesUploader _uploadBytes;
  final Future<void> Function(Duration) _wait;
  final int maxAttempts;

  /// Uploads [bytes] to [path] and returns [path]. Retries failures with a
  /// growing pause (2s, 4s, …). Throws [UploadCancelled] if [handle] is
  /// cancelled, or the last error once attempts run out.
  Future<String> upload({
    required Uint8List bytes,
    required String path,
    String? contentType,
    UploadHandle? handle,
    void Function(double fraction)? onProgress,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (handle?.isCancelled ?? false) throw const UploadCancelled();
      try {
        // Supabase reports no byte progress, so this is 0 → 1 per attempt.
        onProgress?.call(0);
        await _uploadBytes(path, bytes, contentType);
        onProgress?.call(1);
        return path;
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) await _wait(Duration(seconds: 2 * attempt));
      }
    }
    throw lastError!;
  }
}

/// In-memory `{path: signed URL}` cache that re-signs shortly before expiry,
/// so widgets can ask for a URL on every build without a network call.
class SignedUrlCache {
  SignedUrlCache(
    this._createSignedUrl, {
    this.ttl = const Duration(minutes: 10),
    this.refreshMargin = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  factory SignedUrlCache.supabase(
    SupabaseClient client, {
    required String bucket,
  }) => SignedUrlCache(
    (path, ttl) =>
        client.storage.from(bucket).createSignedUrl(path, ttl.inSeconds),
  );

  final Future<String> Function(String path, Duration ttl) _createSignedUrl;
  final Duration ttl;

  /// Re-sign this long before expiry so a slow render never races it.
  final Duration refreshMargin;
  final DateTime Function() _now;
  final Map<String, ({String url, DateTime expiresAt})> _cache = {};

  Future<String> get(String path) async {
    final cached = _cache[path];
    final now = _now();
    if (cached != null && cached.expiresAt.isAfter(now.add(refreshMargin))) {
      return cached.url;
    }
    final url = await _createSignedUrl(path, ttl);
    _cache[path] = (url: url, expiresAt: now.add(ttl));
    return url;
  }

  /// Forget one path (e.g. after the file was replaced or deleted).
  void invalidate(String path) => _cache.remove(path);

  void clear() => _cache.clear();
}
