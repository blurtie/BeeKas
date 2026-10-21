import 'package:beekas/domain/catalog.dart';
import 'package:beekas/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 1, 12);

MyListing _listing({
  String description = 'desc',
  bool isDonation = false,
  int stock = 2,
  int stockLeft = 2,
  DateTime? expiresAt,
  DateTime? removedAt,
  DateTime? withdrawnAt,
}) => (
  id: 'l1',
  title: 'Macbook',
  category: ListingCategory.laptopComputer,
  isDonation: isDonation,
  description: description,
  condition: ListingCondition.likeNew,
  price: isDonation ? 0 : 50000,
  previousPrice: null,
  stock: stock,
  stockLeft: stockLeft,
  campus: Campus.bandung,
  warranty: null,
  specs: const [],
  photos: const [],
  createdAt: _now.subtract(const Duration(days: 1)),
  expiresAt: expiresAt ?? _now.add(const Duration(days: 10)),
  removedAt: removedAt,
  removalReason: removedAt == null ? null : 'penipuan',
  withdrawnAt: withdrawnAt,
);

ListingEdit _edit({
  int? price = 40000,
  int? stock = 2,
  String description = 'd',
}) => (
  description: description,
  condition: ListingCondition.usedGood,
  price: price,
  stock: stock,
  campus: Campus.senayan,
  warranty: '',
  specs: '',
);

void main() {
  group('listingStatus (PRD-katalog 6.3)', () {
    test('live while stock is left and the 60 days run', () {
      expect(listingStatus(_listing(), _now), ListingStatus.live);
    });

    test('sold out when no stock is left', () {
      expect(
        listingStatus(_listing(stockLeft: 0), _now),
        ListingStatus.soldOut,
      );
    });

    test('expired from the moment expiresAt passes', () {
      expect(
        listingStatus(_listing(expiresAt: _now), _now),
        ListingStatus.expired,
      );
      expect(
        listingStatus(_listing(expiresAt: _now, stockLeft: 0), _now),
        ListingStatus.expired,
      );
    });

    test('withdrawn and removed by an admin outrank the rest', () {
      expect(
        listingStatus(_listing(withdrawnAt: _now, expiresAt: _now), _now),
        ListingStatus.withdrawn,
      );
      expect(
        listingStatus(_listing(removedAt: _now, withdrawnAt: _now), _now),
        ListingStatus.removed,
      );
    });
  });

  test('daysLeft rounds up and stops at 0', () {
    expect(daysLeft(_listing(), _now), 10);
    expect(
      daysLeft(_listing(expiresAt: _now.add(const Duration(hours: 1))), _now),
      1,
    );
    expect(daysLeft(_listing(expiresAt: _now), _now), 0);
    expect(
      daysLeft(
        _listing(expiresAt: _now.subtract(const Duration(days: 3))),
        _now,
      ),
      0,
    );
  });

  test('a frozen or unapproved seller hides the listing', () {
    expect(
      listingStatus(_listing(), _now, sellerListed: false),
      ListingStatus.hidden,
    );
    expect(
      listingStatus(_listing(withdrawnAt: _now), _now, sellerListed: false),
      ListingStatus.withdrawn,
    );
  });

  test('sortMyListings: by status, then newest first', () {
    MyListing at(String id, int day, {DateTime? withdrawnAt}) {
      final l = _listing(withdrawnAt: withdrawnAt);
      return (
        id: id,
        title: l.title,
        category: l.category,
        isDonation: false,
        description: l.description,
        condition: l.condition,
        price: l.price,
        previousPrice: null,
        stock: 2,
        stockLeft: 2,
        campus: l.campus,
        warranty: null,
        specs: const [],
        photos: const [],
        createdAt: DateTime.utc(2026, 10, day),
        expiresAt: l.expiresAt,
        removedAt: null,
        removalReason: null,
        withdrawnAt: withdrawnAt,
      );
    }

    final sorted = sortMyListings([
      at('old', 1),
      at('down', 9, withdrawnAt: _now),
      at('new', 5),
    ], _now);
    expect(sorted.map((p) => p.$1.id), ['new', 'old', 'down']);
    expect(sorted.first.$2, ListingStatus.live);
  });

  test('actions per status', () {
    for (final s in ListingStatus.values) {
      final open =
          s == ListingStatus.live ||
          s == ListingStatus.soldOut ||
          s == ListingStatus.expired;
      expect(canEditListing(s), open, reason: '$s edit');
      expect(
        canWithdrawListing(s),
        open || s == ListingStatus.hidden,
        reason: '$s withdraw',
      );
      expect(canRelistListing(s), s == ListingStatus.expired, reason: '$s');
    }
  });

  group('validateEdit (PRD-katalog 6.2, K-06)', () {
    test('name, category, photos and sale/donation stay locked', () {
      expect(lockedAfterListing, {
        ListingField.title,
        ListingField.category,
        ListingField.photos,
      });
    });

    test('a valid edit passes', () {
      expect(validateEdit(_listing(), _edit()), isEmpty);
    });

    test('price, stock and description follow the listing rules', () {
      expect(validateEdit(_listing(), _edit(price: 999)), {ListingField.price});
      expect(validateEdit(_listing(), _edit(stock: 0)), {ListingField.stock});
      expect(validateEdit(_listing(), _edit(description: ' ')), {
        ListingField.description,
      });
    });

    test('an unchanged description passes even over the limit', () {
      final long = 'x' * 600;
      expect(
        validateEdit(_listing(description: long), _edit(description: long)),
        isEmpty,
      );
      expect(
        validateEdit(
          _listing(description: long),
          _edit(description: '${long}y'),
        ),
        {ListingField.description},
      );
    });

    test('a donation needs no price', () {
      expect(
        validateEdit(_listing(isDonation: true), _edit(price: null)),
        isEmpty,
      );
    });

    test('stock cannot drop below the units already taken', () {
      final l = _listing(stock: 3, stockLeft: 1);
      expect(validateEdit(l, _edit(stock: 1)), {ListingField.stock});
      expect(validateEdit(l, _edit(stock: 2)), isEmpty);
    });
  });
}
