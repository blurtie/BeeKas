/// Verification photos before they leave the device (D-07, D-19).
library;

import 'dart:typed_data';

/// The verification bucket's file_size_limit (D-19).
const maxPhotoBytes = 5 * 1024 * 1024;

/// Values are copy keys in lib/config/copy.dart.
enum PhotoError {
  cameraDenied('errorCameraDenied'),
  tooLarge('errorPhotoTooLarge'),
  failed('errorPhotoFailed');

  const PhotoError(this.copyKey);
  final String copyKey;
}

class PhotoException implements Exception {
  const PhotoException(this.error);
  final PhotoError error;
}

/// The camera's JPEG made safe to keep and upload: no metadata, within the
/// bucket limit.
Uint8List preparePhoto(Uint8List jpeg) {
  final Uint8List clean;
  try {
    clean = stripJpegMetadata(jpeg);
  } on FormatException {
    throw const PhotoException(PhotoError.failed);
  }
  if (clean.length > maxPhotoBytes) {
    throw const PhotoException(PhotoError.tooLarge);
  }
  return clean;
}

/// Removes EXIF (GPS, device, time), XMP, IPTC and comments from [jpeg]. The
/// EXIF orientation is written back on its own, because image_picker leaves the
/// pixels unrotated and copies GPS tags along with it.
Uint8List stripJpegMetadata(Uint8List jpeg) {
  final out = BytesBuilder(copy: false);
  int? orientation;
  try {
    if (jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
      throw const FormatException('not a JPEG');
    }
    var i = 2;
    while (true) {
      if (jpeg[i] != 0xFF) throw const FormatException('bad marker');
      final marker = jpeg[i + 1];
      if (marker == 0xDA) {
        // Start of scan: the rest is image data.
        out.add(Uint8List.sublistView(jpeg, i));
        break;
      }
      final end = i + 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
      if (end > jpeg.length) throw const FormatException('truncated');
      final segment = Uint8List.sublistView(jpeg, i, end);
      if (marker == 0xE1) {
        orientation ??= _exifOrientation(Uint8List.sublistView(segment, 4));
      }
      // Keep APP0 (JFIF), APP2 (ICC colour profile) and everything that is not
      // an application segment or comment.
      final metadata =
          (marker >= 0xE1 && marker <= 0xEF && marker != 0xE2) ||
          marker == 0xFE;
      if (!metadata) out.add(segment);
      i = end;
    }
  } on RangeError {
    throw const FormatException('truncated');
  }
  final body = out.takeBytes();
  return Uint8List.fromList([
    0xFF,
    0xD8,
    if (orientation != null) ..._orientationSegment(orientation),
    ...body,
  ]);
}

/// The EXIF orientation of [jpeg], or null.
int? jpegOrientation(Uint8List jpeg) {
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF && jpeg[i + 1] != 0xDA) {
    final end = i + 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
    if (jpeg[i + 1] == 0xE1) {
      final found = _exifOrientation(Uint8List.sublistView(jpeg, i + 4, end));
      if (found != null) return found;
    }
    i = end;
  }
  return null;
}

/// Reads tag 0x0112 from IFD0 of an APP1 payload; null if it is not EXIF.
int? _exifOrientation(Uint8List app1) {
  const header = [0x45, 0x78, 0x69, 0x66, 0, 0]; // "Exif\0\0"
  if (app1.length < 14) return null;
  for (var k = 0; k < header.length; k++) {
    if (app1[k] != header[k]) return null;
  }
  final tiff = ByteData.sublistView(app1, 6);
  final endian = tiff.getUint16(0) == 0x4949 ? Endian.little : Endian.big;
  final ifd0 = tiff.getUint32(4, endian);
  final count = tiff.getUint16(ifd0, endian);
  for (var n = 0; n < count; n++) {
    final entry = ifd0 + 2 + n * 12;
    if (tiff.getUint16(entry, endian) == 0x0112) {
      return tiff.getUint16(entry + 8, endian);
    }
  }
  return null;
}

/// A big-endian APP1 whose IFD0 holds only the orientation.
List<int> _orientationSegment(int orientation) => [
  0xFF, 0xE1, 0, 34, // length: 2 + "Exif\0\0" + 26 bytes of TIFF
  0x45, 0x78, 0x69, 0x66, 0, 0,
  0x4D, 0x4D, 0, 42, 0, 0, 0, 8, // "MM", 42, IFD0 at 8
  0, 1, // one entry
  0x01, 0x12, 0, 3, 0, 0, 0, 1, orientation >> 8, orientation & 0xFF, 0, 0,
  0, 0, 0, 0, // no next IFD
];
