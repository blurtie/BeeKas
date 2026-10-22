import 'package:beekas/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

final _created = DateTime.utc(2026, 11, 23, 9);

OrderState _order({
  OrderKind kind = OrderKind.booking,
  OrderStatus status = OrderStatus.waiting,
  bool extensionRequested = false,
  bool extended = false,
}) => (
  kind: kind,
  status: status,
  extensionRequested: extensionRequested,
  extended: extended,
);

void main() {
  group('6.6 actions per role and status', () {
    test('seller of a waiting order accepts or rejects', () {
      expect(orderActions(OrderRole.seller, _order()), {
        OrderAction.accept,
        OrderAction.cancel,
        OrderAction.updateLocation,
      });
    });

    test('buyer of a waiting booking cancels or asks for an extension', () {
      expect(orderActions(OrderRole.buyer, _order()), {
        OrderAction.cancel,
        OrderAction.requestExtension,
        OrderAction.updateLocation,
      });
    });

    test('a waiting Beli Sekarang has no extension', () {
      expect(orderActions(OrderRole.buyer, _order(kind: OrderKind.buy)), {
        OrderAction.cancel,
        OrderAction.updateLocation,
      });
    });

    test(
      'a requested extension: seller may approve, buyer may not ask again',
      () {
        final o = _order(extensionRequested: true);
        expect(
          orderActions(OrderRole.seller, o),
          contains(OrderAction.approveExtension),
        );
        expect(
          orderActions(OrderRole.buyer, o),
          isNot(contains(OrderAction.requestExtension)),
        );
      },
    );

    test('an extension happens only once', () {
      final o = _order(extensionRequested: true, extended: true);
      expect(
        orderActions(OrderRole.buyer, o),
        isNot(contains(OrderAction.requestExtension)),
      );
      expect(
        orderActions(OrderRole.seller, o),
        isNot(contains(OrderAction.approveExtension)),
      );
    });

    test('processing: buyer confirms receipt; both cancel and change COD', () {
      final o = _order(status: OrderStatus.processing);
      expect(orderActions(OrderRole.buyer, o), {
        OrderAction.complete,
        OrderAction.cancel,
        OrderAction.updateLocation,
        OrderAction.updateCodTime,
      });
      expect(orderActions(OrderRole.seller, o), {
        OrderAction.cancel,
        OrderAction.updateLocation,
        OrderAction.updateCodTime,
      });
    });

    test('completed and cancelled orders allow nothing', () {
      for (final status in [OrderStatus.completed, OrderStatus.cancelled]) {
        for (final role in OrderRole.values) {
          expect(orderActions(role, _order(status: status)), isEmpty);
        }
      }
    });
  });

  group('6.7 times', () {
    test('a new order is held for 24 hours', () {
      expect(holdUntil(_created), DateTime.utc(2026, 11, 24, 9));
    });

    test('remaining hold time counts down and stops at zero', () {
      final until = DateTime.utc(2026, 11, 24, 9);
      expect(
        remainingHold(until, DateTime.utc(2026, 11, 23, 9, 11, 48)),
        const Duration(hours: 23, minutes: 48, seconds: 12),
      );
      expect(remainingHold(until, DateTime.utc(2026, 11, 25)), Duration.zero);
    });

    test('an extension adds 24 hours to the hold', () {
      expect(
        extendedHold(DateTime.utc(2026, 11, 24, 9)),
        DateTime.utc(2026, 11, 25, 9),
      );
    });

    test('a waiting order is cancelled once the hold has passed', () {
      final until = DateTime.utc(2026, 11, 24, 9);
      expect(isHoldOver(until, DateTime.utc(2026, 11, 24, 8, 59)), isFalse);
      expect(isHoldOver(until, DateTime.utc(2026, 11, 24, 9)), isTrue);
    });

    test('a processing order completes 3 days after the COD time', () {
      expect(
        autoCompleteAt(DateTime.utc(2026, 11, 24, 13)),
        DateTime.utc(2026, 11, 27, 13),
      );
    });
  });

  group('6.8 donations', () {
    test('at most 2 running donation orders per member', () {
      expect(canOrderDonation(0), isTrue);
      expect(canOrderDonation(1), isTrue);
      expect(canOrderDonation(2), isFalse);
    });
  });

  group('6.13 cancel reasons', () {
    test('a fixed reason needs no note', () {
      expect(isValidCancellation(CancelReason.changedMind, ''), isTrue);
    });

    test('Lainnya needs a note', () {
      expect(isValidCancellation(CancelReason.other, '  '), isFalse);
      expect(isValidCancellation(CancelReason.other, 'Barang rusak'), isTrue);
    });

    test('a note is at most 500 characters', () {
      expect(isValidCancellation(CancelReason.other, 'a' * 501), isFalse);
    });

    test('length counts characters as the database does (code points)', () {
      // A family emoji is one grapheme but 7 code points.
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}‍\u{1F466}';
      expect(isValidCancellation(CancelReason.other, family * 72), isFalse);
      expect(isValidCancellation(CancelReason.other, family * 71), isTrue);
      expect(isValidCodPlace(family * 29), isFalse);
      expect(isValidCodPlace(family * 28), isTrue);
      expect(isValidCodPlace(''), isTrue, reason: 'the place is optional');
    });

    test('no reason is not a cancellation', () {
      expect(isValidCancellation(null, 'x'), isFalse);
    });
  });
}
