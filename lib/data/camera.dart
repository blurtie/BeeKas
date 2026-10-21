import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo.dart';

/// Camera only, no gallery (D-13): rear for the card, front for the selfie.
/// Returns the photo without metadata, or null when the member backs out of
/// the camera. image_picker's temp file is deleted right after reading, so the
/// photo lives only in memory until L10 uploads it; closing the app loses it.
Future<Uint8List?> takePhoto(CameraDevice camera) async {
  final raw = await _pick(ImageSource.camera, camera);
  return raw == null ? null : preparePhoto(raw);
}

/// A listing photo from the camera or the gallery (D-28), as a JPEG without
/// metadata (K-05), or null when the seller backs out. image_picker
/// re-encodes opaque images as JPEG but keeps PNG for images with alpha; on
/// Android MainActivity converts those. iOS has no converter yet (D-27), so
/// preparePhoto refuses a non-JPEG there.
Future<Uint8List?> pickListingPhoto(ImageSource source) async {
  var raw = await _pick(source, CameraDevice.rear);
  if (raw == null) return null;
  if (!isJpeg(raw) && Platform.isAndroid) {
    try {
      raw = await _settings.invokeMethod<Uint8List>('toJpeg', raw) ?? raw;
    } on PlatformException {
      throw const PhotoException(PhotoError.unsupported);
    }
  }
  return preparePhoto(raw);
}

Future<Uint8List?> _pick(ImageSource source, CameraDevice camera) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: camera,
      // Readable card, face or product, a few hundred KB: far below the 5 MB
      // bucket limit, and small enough to convert without running out of memory.
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
  try {
    return await file.readAsBytes();
  } on FileSystemException {
    throw const PhotoException(PhotoError.failed);
  } finally {
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

const _settings = MethodChannel('beekas/settings');

/// This app's page in the system settings (MainActivity.kt, AppDelegate.swift).
Future<void> openAppSettings() => _settings.invokeMethod('openAppSettings');
