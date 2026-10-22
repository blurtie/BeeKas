import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/order.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import 'signup_repository.dart';

/// One of the member's orders as Pesanan Saya (K12) and Detail Pesanan (K13)
/// show it. [isBuyer] tells the tab; [otherName] is the other party.
/// [photo] is a URL.
typedef Order = ({
  String id,
  String listingId,
  OrderKind kind,
  OrderStatus status,
  int price,
  bool isDonation,
  DateTime? holdUntil,
  bool extensionRequested,
  bool extended,
  Campus codCampus,
  String? codPlace,
  DateTime? codAt,
  CancelReason? cancelReason,
  String? cancelNote,
  DateTime createdAt,
  String title,
  String? photo,
  bool isBuyer,
  String otherName,
});

OrderState stateOf(Order o) => (
  kind: o.kind,
  status: o.status,
  extensionRequested: o.extensionRequested,
  extended: o.extended,
);

OrderRole roleOf(Order o) => o.isBuyer ? OrderRole.buyer : OrderRole.seller;

/// Orders (#85). The backend checks every rule again; failures are
/// [SignupException]s.
abstract interface class OrderRepository {
  /// place_order: returns when the server's 24-hour hold ends (K10).
  Future<DateTime> place(
    String listingId,
    OrderKind kind,
    Campus codCampus,
    String codPlace,
  );

  /// my_orders: newest first.
  Future<List<Order>> mine();

  Future<void> accept(String id, DateTime codAt);
  Future<void> cancel(String id, CancelReason reason, String note);
  Future<void> complete(String id);
  Future<void> requestExtension(String id);
  Future<void> approveExtension(String id);

  /// [codAt] stays null while Menunggu.
  Future<void> updateCod(
    String id,
    Campus campus,
    String place,
    DateTime? codAt,
  );
}

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);
  final SupabaseClient _client;

  Future<void> _rpc(String name, Map<String, dynamic> params) =>
      guardBackend(() => _client.rpc<void>(name, params: params));

  @override
  Future<DateTime> place(
    String listingId,
    OrderKind kind,
    Campus codCampus,
    String codPlace,
  ) => guardBackend(() async {
    final until = await _client.rpc<String>(
      'place_order',
      params: {
        'p_listing': listingId,
        'p_kind': kind.name,
        'p_cod_campus': codCampus.code,
        'p_cod_place': codPlace.trim(),
      },
    );
    return DateTime.parse(until);
  });

  @override
  Future<List<Order>> mine() => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>('my_orders');
    try {
      return _orders(rows);
    } on Object {
      // A row this app version cannot read (a new campus or status): the
      // screens show their error state instead of failing half-way.
      throw const SignupException(SignupError.unknown);
    }
  });

  List<Order> _orders(List<dynamic> rows) {
    final bucket = _client.storage.from('listing-photos');
    DateTime? time(Object? v) => v == null ? null : DateTime.parse(v as String);
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          id: row['id'] as String,
          listingId: row['listing_id'] as String,
          kind: OrderKind.values.byName(row['kind'] as String),
          status: OrderStatus.values.byName(row['status'] as String),
          price: row['price'] as int,
          isDonation: row['is_donation'] as bool,
          holdUntil: time(row['hold_until']),
          extensionRequested: row['extension_requested'] as bool,
          extended: row['extended'] as bool,
          codCampus: Campus.values.firstWhere(
            (c) => c.code == row['cod_campus'],
          ),
          codPlace: row['cod_place'] as String?,
          codAt: time(row['cod_at']),
          cancelReason: row['cancel_reason'] == null
              ? null
              : CancelReason.fromCode(row['cancel_reason'] as String),
          cancelNote: row['cancel_note'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          title: row['title'] as String,
          photo: row['photo'] == null
              ? null
              : bucket.getPublicUrl(row['photo'] as String),
          isBuyer: row['is_buyer'] as bool,
          otherName: row['other_name'] as String,
        ),
    ];
  }

  @override
  Future<void> accept(String id, DateTime codAt) => _rpc('accept_order', {
    'p_id': id,
    'p_cod_at': codAt.toUtc().toIso8601String(),
  });

  @override
  Future<void> cancel(String id, CancelReason reason, String note) =>
      _rpc('cancel_order', {
        'p_id': id,
        'p_reason': reason.code,
        'p_note': note.trim().isEmpty ? null : note.trim(),
      });

  @override
  Future<void> complete(String id) => _rpc('complete_order', {'p_id': id});

  @override
  Future<void> requestExtension(String id) =>
      _rpc('request_extension', {'p_id': id});

  @override
  Future<void> approveExtension(String id) =>
      _rpc('approve_extension', {'p_id': id});

  @override
  Future<void> updateCod(
    String id,
    Campus campus,
    String place,
    DateTime? codAt,
  ) => _rpc('update_cod', {
    'p_id': id,
    'p_cod_campus': campus.code,
    'p_cod_place': place.trim(),
    'p_cod_at': codAt?.toUtc().toIso8601String(),
  });
}
