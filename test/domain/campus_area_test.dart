import 'package:beekas/domain/campus_area.dart';
import 'package:beekas/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every campus has a short tag (D-47)', () {
    expect(Campus.alamSutera.tag, 'ALS');
    expect(Campus.kemanggisan.tag, 'KMG');
    expect(Campus.bandung.tag, 'BDG');
    expect({for (final c in Campus.values) c.tag}.length, Campus.values.length);
  });

  test('Jabodetabek campuses share an area', () {
    expect(campusesIn(CampusArea.jabodetabek), [
      Campus.kemanggisan,
      Campus.senayan,
      Campus.alamSutera,
      Campus.base,
      Campus.bekasi,
    ]);
    expect(campusesIn(CampusArea.bandung), [Campus.bandung]);
    expect(Campus.online.area, isNull);
  });

  test('members reach only their area', () {
    expect(canReach(Campus.kemanggisan, Campus.alamSutera), isTrue);
    expect(canReach(Campus.bandung, Campus.alamSutera), isFalse);
    expect(canReach(Campus.alamSutera, Campus.bandung), isFalse);
    expect(canReach(Campus.malang, Campus.malang), isTrue);
  });

  test('BINUS Online and accounts without a campus reach every area', () {
    for (final c in listingCampuses) {
      expect(canReach(Campus.online, c), isTrue);
      expect(canReach(null, c), isTrue);
    }
  });

  test('listings are never located at BINUS Online', () {
    expect(listingCampuses, isNot(contains(Campus.online)));
    expect(listingCampuses.length, Campus.values.length - 1);
  });
}
