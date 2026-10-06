import 'dart:convert';
import 'dart:typed_data';

import 'package:beekas/domain/photo.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> u16(int v) => [v >> 8 & 0xFF, v & 0xFF];
List<int> u32(int v) => [...u16(v >> 16), ...u16(v & 0xFFFF)];
List<int> segment(int marker, List<int> data) => [
  0xFF,
  marker,
  ...u16(data.length + 2),
  ...data,
];

/// Big-endian EXIF: IFD0 with Make, Orientation and a GPS pointer, then a GPS
/// IFD holding a latitude reference "S".
List<int> exif({int? orientation}) {
  final entries = <List<int>>[
    [...u16(0x010F), ...u16(2), ...u32(4), ...ascii.encode('Cam\x00')],
    if (orientation != null)
      [...u16(0x0112), ...u16(3), ...u32(1), ...u16(orientation), 0, 0],
    [...u16(0x8825), ...u16(4), ...u32(1), ...u32(0)], // offset patched below
  ];
  final ifd0Size = 2 + entries.length * 12 + 4;
  final gpsOffset = 8 + ifd0Size;
  entries.last.setRange(8, 12, u32(gpsOffset));
  return [
    ...ascii.encode('Exif\x00\x00'),
    ...ascii.encode('MM'), ...u16(42), ...u32(8),
    ...u16(entries.length), for (final e in entries) ...e, ...u32(0),
    // GPS IFD: GPSLatitudeRef = "S".
    ...u16(1), ...u16(0x0001), ...u16(2), ...u32(2), ...ascii.encode('S\x00'),
    0, 0, ...u32(0),
  ];
}

final scan = [
  0xFF,
  0xDA,
  ...u16(4),
  1,
  2,
  0x11,
  0x22,
  0xFF,
  0x00,
  0x33,
  0xFF,
  0xD9,
];

Uint8List jpeg(List<List<int>> segments) =>
    Uint8List.fromList([0xFF, 0xD8, for (final s in segments) ...s, ...scan]);

final jfif = segment(0xE0, [
  ...ascii.encode('JFIF\x00'),
  1,
  1,
  0,
  0,
  1,
  0,
  1,
  0,
  0,
]);
final icc = segment(0xE2, ascii.encode('ICC_PROFILE\x00x'));
final quant = segment(0xDB, List.filled(5, 7));

bool contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length && hit; j++) {
      hit = haystack[i + j] == needle[j];
    }
    if (hit) return true;
  }
  return false;
}

void main() {
  group('stripJpegMetadata', () {
    final input = jpeg([
      jfif,
      segment(0xE1, exif(orientation: 6)),
      segment(0xE1, ascii.encode('http://ns.adobe.com/xap/1.0/\x00<gps/>')),
      segment(0xED, ascii.encode('Photoshop 3.0\x00IPTC')),
      segment(0xFE, ascii.encode('comment')),
      icc,
      quant,
    ]);
    final out = stripJpegMetadata(input);

    test('drops EXIF (with GPS), XMP, IPTC and comments', () {
      expect(contains(out, ascii.encode('Cam')), isFalse);
      expect(contains(out, ascii.encode('<gps/>')), isFalse);
      expect(contains(out, ascii.encode('IPTC')), isFalse);
      expect(contains(out, ascii.encode('comment')), isFalse);
      expect(contains(out, u16(0x8825)), isFalse);
    });

    test('keeps only the orientation, so the photo is not shown sideways', () {
      expect(jpegOrientation(out), 6);
      expect(contains(out, segment(0xE1, exif(orientation: 6))), isFalse);
    });

    test('keeps JFIF, the colour profile, image data and the scan', () {
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
      expect(contains(out, jfif), isTrue);
      expect(contains(out, icc), isTrue);
      expect(contains(out, quant), isTrue);
      expect(out.sublist(out.length - scan.length), scan);
    });

    test('adds no EXIF when there was no orientation', () {
      final plain = stripJpegMetadata(jpeg([segment(0xE1, exif()), quant]));
      expect(plain, jpeg([quant]));
      expect(jpegOrientation(plain), isNull);
    });

    test('reads little-endian EXIF too', () {
      final le = [
        ...ascii.encode('Exif\x00\x00II'),
        42,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
        0x12,
        0x01,
        3,
        0,
        1,
        0,
        0,
        0,
        3,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ];
      expect(jpegOrientation(stripJpegMetadata(jpeg([segment(0xE1, le)]))), 3);
    });

    test('refuses anything that is not a JPEG', () {
      expect(
        () => stripJpegMetadata(
          Uint8List.fromList([0x89, ...ascii.encode('PNG')]),
        ),
        throwsFormatException,
      );
      expect(
        () => stripJpegMetadata(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0, 40]),
        ),
        throwsFormatException,
      );
    });
  });

  group('preparePhoto', () {
    test('returns the stripped JPEG', () {
      expect(preparePhoto(jpeg([segment(0xE1, exif()), quant])), jpeg([quant]));
    });

    test('refuses photos over the 5 MB bucket limit', () {
      final big = jpeg([
        quant,
        for (var i = 0; i < 81; i++) segment(0xDB, List.filled(65000, 0)),
      ]);
      expect(
        () => preparePhoto(big),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.error,
            'error',
            PhotoError.tooLarge,
          ),
        ),
      );
    });

    test('a broken file is a failed photo', () {
      expect(
        () => preparePhoto(Uint8List(3)),
        throwsA(
          isA<PhotoException>().having(
            (e) => e.error,
            'error',
            PhotoError.failed,
          ),
        ),
      );
    });
  });
}
