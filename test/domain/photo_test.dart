import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

    test('keeps the colour profile, image data and the scan', () {
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
      expect(contains(out, jfif), isFalse);
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

  group('a second image after the main one (MPF, Ultra HDR gain map)', () {
    // A real 2×2 JPEG (Pillow), so the result can be decoded.
    final real = base64Decode(
      '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDTooor+cj99P/Z',
    );

    /// [real] with [segments] inserted right after SOI.
    List<int> withSegments(List<List<int>> segments) => [
      0xFF,
      0xD8,
      for (final s in segments) ...s,
      ...real.sublist(2),
    ];

    final mpf = segment(0xE2, [...ascii.encode('MPF\x00MM'), ...u16(42)]);
    final iso21496 = segment(
      0xE2,
      ascii.encode('urn:iso:std:iso:ts:21496:-1\x00'),
    );
    final gainMapXmp = segment(
      0xE1,
      ascii.encode('http://ns.adobe.com/xap/1.0/\x00<hdrgm:Version/>'),
    );
    // The gain map, carrying its own EXIF with GPS.
    final secondImage = withSegments([segment(0xE1, exif(orientation: 1))]);
    final input = Uint8List.fromList([
      ...withSegments([
        segment(0xE1, exif(orientation: 6)),
        gainMapXmp,
        mpf,
        iso21496,
        icc,
      ]),
      ...secondImage,
    ]);
    final out = stripJpegMetadata(input);

    test('cuts the file after the main image', () {
      expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
      expect(contains(out, real.sublist(real.length - 40)), isTrue);
      // Only one SOI: the second image is gone.
      var sois = 0;
      for (var i = 0; i + 1 < out.length; i++) {
        if (out[i] == 0xFF && out[i + 1] == 0xD8) sois++;
      }
      expect(sois, 1);
    });

    test('no GPS and nothing pointing to a second image', () {
      expect(contains(out, ascii.encode('Cam')), isFalse);
      expect(contains(out, u16(0x8825)), isFalse);
      expect(contains(out, ascii.encode('MPF')), isFalse);
      expect(contains(out, ascii.encode('21496')), isFalse);
      expect(contains(out, ascii.encode('hdrgm')), isFalse);
    });

    test('keeps the colour profile and the orientation', () {
      expect(contains(out, icc), isTrue);
      expect(jpegOrientation(out), 6);
    });

    testWidgets('still decodes', (tester) async {
      final size = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(out);
        final frame = await codec.getNextFrame();
        return (frame.image.width, frame.image.height);
      });
      expect(size, (2, 2));
    });

    test('a scan without an end is refused', () {
      expect(
        () => stripJpegMetadata(
          Uint8List.fromList(real.sublist(0, real.length - 2)),
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
