/// Picking photos (camera or gallery) and files, behind one interface with
/// a device implementation and a fake for tests and demos.
///
/// Newly written around `image_picker` and `file_picker` (StudyBuddies and
/// Couple called them directly from screens). The interface means a screen
/// can be tested — and demoed on a desktop/web build — without a camera.
///
/// ```dart
/// final picker = ref.read(mediaPickerProvider);         // DeviceMediaPicker in the app
/// final photo = await picker.pickImage(source: MediaSource.camera, maxWidth: 1600);
/// if (photo == null) return;                            // user cancelled
/// final problem = const FileRules(maxBytes: 5 << 20).check(photo.name, photo.bytes);
/// ```
///
/// **Platform setup** (device implementation only):
/// * iOS `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
/// * Android: no permission needed for the system photo picker; camera
///   capture uses an intent.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'file_rules.dart';

enum MediaSource { camera, gallery }

/// A picked file, already read into memory.
class PickedMedia {
  const PickedMedia({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;

  /// On-disk path when the platform has one (null on the web).
  final String? path;

  int get sizeBytes => bytes.length;
  String get mimeType => mimeTypeFor(name);
  bool get isImage => isImageFile(name);
}

abstract interface class MediaPicker {
  /// Null when the user cancels.
  Future<PickedMedia?> pickImage({
    MediaSource source = MediaSource.gallery,
    double? maxWidth,
    int? imageQuality,
  });

  /// Empty when the user cancels. [allowedExtensions] like `['pdf', 'csv']`.
  Future<List<PickedMedia>> pickFiles({
    List<String>? allowedExtensions,
    bool multiple = false,
  });
}

class DeviceMediaPicker implements MediaPicker {
  DeviceMediaPicker({ImagePicker? imagePicker})
    : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<PickedMedia?> pickImage({
    MediaSource source = MediaSource.gallery,
    double? maxWidth,
    int? imageQuality,
  }) async {
    final file = await _images.pickImage(
      source: source == MediaSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    if (file == null) return null;
    return PickedMedia(
      name: file.name,
      bytes: await file.readAsBytes(),
      path: file.path,
    );
  }

  @override
  Future<List<PickedMedia>> pickFiles({
    List<String>? allowedExtensions,
    bool multiple = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: multiple,
      withData: true, // bytes on every platform, including the web
    );
    if (result == null) return const [];
    return [
      for (final file in result.files)
        if (file.bytes != null)
          PickedMedia(
            name: file.name,
            bytes: file.bytes!,
            // `path` throws on the web, so only read it elsewhere.
            path: kIsWeb ? null : file.path,
          ),
    ];
  }
}

/// A test/demo double: returns queued results instead of opening a picker.
/// **Not production functionality** — nothing is read from the device.
class FakeMediaPicker implements MediaPicker {
  FakeMediaPicker({this.images = const [], this.files = const []});

  /// Returned in order by [pickImage]; null entries simulate a cancel.
  final List<PickedMedia?> images;

  /// Returned by [pickFiles], filtered by extension.
  final List<PickedMedia> files;
  int _imageIndex = 0;
  final calls = <String>[];

  @override
  Future<PickedMedia?> pickImage({
    MediaSource source = MediaSource.gallery,
    double? maxWidth,
    int? imageQuality,
  }) async {
    calls.add('pickImage(${source.name})');
    if (_imageIndex >= images.length) return null;
    return images[_imageIndex++];
  }

  @override
  Future<List<PickedMedia>> pickFiles({
    List<String>? allowedExtensions,
    bool multiple = false,
  }) async {
    calls.add('pickFiles');
    final matching = [
      for (final f in files)
        if (allowedExtensions == null ||
            allowedExtensions.contains(extensionOf(f.name)))
          f,
    ];
    return multiple ? matching : matching.take(1).toList();
  }
}

final mediaPickerProvider = Provider<MediaPicker>((ref) => DeviceMediaPicker());
