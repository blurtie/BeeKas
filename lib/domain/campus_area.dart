/// D-47: BINUS campuses are far apart, so members order and bid only within
/// their own area. The backend enforces the same in can_reach (place_order,
/// place_bid) and listings_campus_physical.
library;

import 'registration.dart';

/// Nearby campuses grouped; BINUS Online has none.
enum CampusArea { jabodetabek, bandung, malang, semarang }

extension CampusPlace on Campus {
  /// The short tag on listing photos (D-47).
  String get tag => switch (this) {
    Campus.kemanggisan => 'KMG',
    Campus.senayan => 'SNY',
    Campus.alamSutera => 'ALS',
    Campus.base => 'BASE',
    Campus.bekasi => 'BKS',
    Campus.bandung => 'BDG',
    Campus.malang => 'MLG',
    Campus.semarang => 'SMG',
    Campus.online => 'ONL',
  };

  /// Null for BINUS Online.
  CampusArea? get area => switch (this) {
    Campus.kemanggisan ||
    Campus.senayan ||
    Campus.alamSutera ||
    Campus.base ||
    Campus.bekasi => CampusArea.jabodetabek,
    Campus.bandung => CampusArea.bandung,
    Campus.malang => CampusArea.malang,
    Campus.semarang => CampusArea.semarang,
    Campus.online => null,
  };

  /// Whether items can be met here: every campus but BINUS Online.
  bool get isPhysical => this != Campus.online;
}

/// Campuses a listing can be located at (Pasang, Edit, the location filter).
final listingCampuses = [
  for (final c in Campus.values)
    if (c.isPhysical) c,
];

/// The campuses of [area], in list order.
List<Campus> campusesIn(CampusArea area) => [
  for (final c in Campus.values)
    if (c.area == area) c,
];

/// Whether a member at [member] may order or bid at [listing]. A member
/// without an area (BINUS Online, or no campus) reaches every area.
bool canReach(Campus? member, Campus listing) {
  final area = member?.area;
  return area == null || area == listing.area;
}
