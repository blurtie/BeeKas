import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo.dart';

/// Rear camera only, no gallery (D-13). Returns the photo without metadata, or
/// null when the member backs out of the camera. image_picker's temp file is
/// deleted right after reading, so the photo lives only in memory until #29
/// uploads it; closing the app loses it.
Future<Uint8List?> takeCardPhoto() async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      // Readable card, a few hundred KB: far below the 5 MB bucket limit.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    throw PhotoException(
      e.code == 'camera_access_denied'
          ? PhotoError.cameraDenied
          : PhotoError.failed,
    );
  }
  if (file == null) return null;
  final Uint8List raw;
  try {
    raw = await file.readAsBytes();
  } on FileSystemException {
    throw const PhotoException(PhotoError.failed);
  } finally {
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
  return preparePhoto(raw);
}

const _settings = MethodChannel('beekas/settings');

/// This app's page in the system settings (MainActivity.kt, AppDelegate.swift).
Future<void> openAppSettings() => _settings.invokeMethod('openAppSettings');
