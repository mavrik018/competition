/// Pure checks for picked or uploaded files: size and extension limits,
/// MIME type from the file name, and "is this really an image/PDF?" from
/// the first bytes.
///
/// Newly written. Couple's `UploadManager` checked extensions only on the
/// web; the other apps trusted the picker. Checking content bytes catches a
/// renamed file (`virus.exe` → `photo.jpg`) before it is uploaded.
///
/// ```dart
/// const rules = FileRules(maxBytes: 5 * 1024 * 1024, allowedExtensions: {'jpg', 'png', 'pdf'});
/// final problem = rules.check(file.name, file.bytes);
/// if (problem != null) return context.showError(problem);
/// ```
library;

import 'dart:typed_data';

import '../11_utilities/number_format.dart';

class FileRules {
  const FileRules({
    this.maxBytes,
    this.allowedExtensions,
    this.checkContent = true,
  });

  /// Null for no size limit.
  final int? maxBytes;

  /// Lower-case, without the dot. Null allows any extension.
  final Set<String>? allowedExtensions;

  /// Compare the file's first bytes with its extension, for the types
  /// [sniffFileType] knows.
  final bool checkContent;

  /// Null when the file is acceptable, otherwise a user-facing reason.
  String? check(String fileName, Uint8List bytes) {
    final extension = extensionOf(fileName);
    final allowed = allowedExtensions;
    if (allowed != null && !allowed.contains(extension)) {
      return 'Only ${(allowed.toList()..sort()).map((e) => e.toUpperCase()).join(', ')} files are allowed.';
    }
    if (maxBytes != null && bytes.length > maxBytes!) {
      return 'That file is ${formatBytes(bytes.length)}. The limit is ${formatBytes(maxBytes!)}.';
    }
    if (bytes.isEmpty) return 'That file is empty.';
    if (checkContent) {
      final sniffed = sniffFileType(bytes);
      final expected = _canonical(extension);
      if (sniffed != null && expected != null && sniffed != expected) {
        return "That file's contents don't match its .$extension name.";
      }
    }
    return null;
  }
}

/// `report.Final.PDF` → `pdf`. Empty when there is no extension.
String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

const _mimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'pdf': 'application/pdf',
  'csv': 'text/csv',
  'txt': 'text/plain',
  'json': 'application/json',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'wav': 'audio/wav',
  'zip': 'application/zip',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// MIME type for a file name, `application/octet-stream` when unknown.
String mimeTypeFor(String fileName) =>
    _mimeTypes[extensionOf(fileName)] ?? 'application/octet-stream';

bool isImageFile(String fileName) => mimeTypeFor(fileName).startsWith('image/');

/// Identifies common formats by their magic bytes: `jpeg`, `png`, `gif`,
/// `webp`, `pdf`, `zip`. Null when unknown — callers should then trust the
/// extension, not reject the file.
String? sniffFileType(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0xFF, 0xD8, 0xFF])) return 'jpeg';
  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'gif';
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'webp';
  }
  if (startsWith([0x25, 0x50, 0x44, 0x46])) return 'pdf';
  if (startsWith([0x50, 0x4B, 0x03, 0x04])) return 'zip';
  return null;
}

// Extensions that share a signature map to one name ('jpg' → 'jpeg';
// Office files are zip archives).
String? _canonical(String extension) => switch (extension) {
  'jpg' || 'jpeg' => 'jpeg',
  'png' || 'gif' || 'webp' || 'pdf' || 'zip' => extension,
  'docx' || 'xlsx' || 'pptx' => 'zip',
  _ => null,
};
