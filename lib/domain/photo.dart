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

/// Removes EXIF (GPS, device, time), XMP, IPTC, comments and every other
/// application segment from [jpeg], keeping only the ICC colour profile. The
/// EXIF orientation is written back on its own, because image_picker leaves the
/// pixels unrotated and copies GPS tags along with it. Anything after the main
/// image ends is cut: phones append a second image there (MPF, Ultra HDR gain
/// map) with its own metadata.
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
        // Image data up to and including the main image's EOI.
        out.add(Uint8List.sublistView(jpeg, i, _endOfImage(jpeg, i)));
        break;
      }
      final end = i + 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
      if (end > jpeg.length) throw const FormatException('truncated');
      final segment = Uint8List.sublistView(jpeg, i, end);
      if (marker == 0xE1) {
        orientation ??= _exifOrientation(Uint8List.sublistView(segment, 4));
      }
      // Of the application segments (APP0-APP15) and comments, only the ICC
      // profile stays; APP2 also holds MPF and gain-map pointers.
      final metadata =
          (marker >= 0xE0 && marker <= 0xEF && !_isIcc(segment)) ||
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

/// APP2 whose payload starts with "ICC_PROFILE\0".
bool _isIcc(Uint8List segment) {
  const id = [
    0x49,
    0x43,
    0x43,
    0x5F,
    0x50,
    0x52,
    0x4F,
    0x46,
    0x49,
    0x4C,
    0x45,
    0,
  ];
  if (segment[1] != 0xE2 || segment.length < 4 + id.length) return false;
  for (var k = 0; k < id.length; k++) {
    if (segment[4 + k] != id[k]) return false;
  }
  return true;
}

/// Index just past the EOI that ends the image whose first scan starts at
/// [sos]. Inside scan data 0xFF is followed by 0x00 (stuffing), a restart
/// marker or fill bytes; marker segments between progressive scans are skipped
/// by their length.
int _endOfImage(Uint8List jpeg, int sos) {
  var i = sos + 2 + (jpeg[sos + 2] << 8 | jpeg[sos + 3]);
  while (i + 1 < jpeg.length) {
    if (jpeg[i] != 0xFF) {
      i++;
      continue;
    }
    final next = jpeg[i + 1];
    if (next == 0xD9) return i + 2;
    if (next == 0xFF) {
      i++;
    } else if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
      i += 2;
    } else {
      i += 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
    }
  }
  throw const FormatException('no end of image');
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
