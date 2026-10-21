/// Rules 6-8 and 13: orders (D-30, D-36, PRD-katalog 5.4-5.7). The backend
/// enforces the same in the orders table and its functions.
library;

/// Booking 24 Jam holds a unit; Beli Sekarang promises to buy it.
enum OrderKind { booking, buy }

/// D-30: Menunggu konfirmasi penjual → Diproses → Selesai / Dibatalkan.
enum OrderStatus { waiting, processing, completed, cancelled }

enum OrderRole { buyer, seller }

/// What a party may do from Detail Pesanan (K13). [updateLocation] changes
/// the Lokasi COD until Selesai; [updateCodTime] the COD time in Diproses
/// (K-17).
enum OrderAction {
  accept,
  cancel,
  complete,
  requestExtension,
  approveExtension,
  updateLocation,
  updateCodTime,
}

/// K-18: fixed codes, matching the cancel_reason enum.
enum CancelReason {
  changedMind('changed_mind'),
  notAsDescribed('not_as_described'),
  cannotMeet('cannot_meet'),
  soldElsewhere('sold_elsewhere'),
  other('other');

  const CancelReason(this.code);
  final String code;
  String get copyKey => 'cancelReason_$code';

  static CancelReason fromCode(String code) =>
      values.firstWhere((r) => r.code == code);
}

typedef OrderState = ({
  OrderKind kind,
  OrderStatus status,
  bool extensionRequested,
  bool extended,
});

Set<OrderAction> orderActions(OrderRole role, OrderState o) {
  final buyer = role == OrderRole.buyer;
  return switch (o.status) {
    OrderStatus.waiting => {
      if (!buyer) OrderAction.accept,
      OrderAction.cancel,
      OrderAction.updateLocation,
      if (o.kind == OrderKind.booking && !o.extended)
        if (buyer && !o.extensionRequested)
          OrderAction.requestExtension
        else if (!buyer && o.extensionRequested)
          OrderAction.approveExtension,
    },
    OrderStatus.processing => {
      if (buyer) OrderAction.complete,
      OrderAction.cancel,
      OrderAction.updateLocation,
      OrderAction.updateCodTime,
    },
    OrderStatus.completed || OrderStatus.cancelled => {},
  };
}

const holdDuration = Duration(hours: 24);

/// K-13: one extension adds 24 hours.
const extensionDuration = Duration(hours: 24);

/// D-30: Selesai on its own 3 days after the COD time.
const autoCompleteAfter = Duration(days: 3);

/// K-15: bookings and Beli Sekarang alike wait 24 hours for the seller.
DateTime holdUntil(DateTime createdAt) => createdAt.add(holdDuration);

DateTime extendedHold(DateTime until) => until.add(extensionDuration);

Duration remainingHold(DateTime until, DateTime now) {
  final left = until.difference(now);
  return left.isNegative ? Duration.zero : left;
}

bool isHoldOver(DateTime until, DateTime now) => !now.isBefore(until);

DateTime autoCompleteAt(DateTime codAt) => codAt.add(autoCompleteAfter);

/// D-30: running = Menunggu or Diproses.
const maxRunningDonations = 2;

bool canOrderDonation(int runningDonations) =>
    runningDonations < maxRunningDonations;

const maxCancelNote = 500;

/// Text length as Postgres char_length counts it: code points, not
/// graphemes (TextField.maxLength counts graphemes).
int textLength(String text) => text.trim().runes.length;

/// K-18: a code, plus a note when Lainnya.
bool isValidCancellation(CancelReason? reason, String note) {
  if (reason == null || textLength(note) > maxCancelNote) return false;
  return reason != CancelReason.other || note.trim().isNotEmpty;
}

/// Lokasi COD free text (D-30), next to the campus; optional.
const maxCodPlace = 200;

bool isValidCodPlace(String place) => textLength(place) <= maxCodPlace;
