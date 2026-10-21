import 'dart:async';

import 'package:beekas/data/order_repository.dart';
import 'package:beekas/domain/order.dart';
import 'package:beekas/domain/registration.dart';

/// Plays the order functions in memory. [errors] holds one failure per
/// method name; [gate] holds [mine].
class FakeOrderRepository implements OrderRepository {
  final orders = <Order>[];
  final calls = <String>[];
  final errors = <String, Object>{};
  Completer<void>? gate;
  var _ids = 0;

  void _fail(String method) {
    final error = errors.remove(method);
    if (error != null) throw error;
  }

  Order add({
    OrderKind kind = OrderKind.booking,
    OrderStatus status = OrderStatus.waiting,
    bool isBuyer = true,
    String title = 'Macbook Air M1',
    DateTime? createdAt,
    DateTime? holdUntil,
    DateTime? codAt,
    bool extensionRequested = false,
  }) {
    final at = createdAt ?? DateTime.utc(2026, 11, 23, 9);
    final o = (
      id: 'o${_ids++}',
      listingId: 'l1',
      kind: kind,
      status: status,
      price: 6500000,
      isDonation: false,
      holdUntil: holdUntil ?? at.add(const Duration(hours: 24)),
      extensionRequested: extensionRequested,
      extended: false,
      codCampus: Campus.alamSutera,
      codPlace: 'Lobi Anggrek',
      codAt: codAt,
      cancelReason: null,
      cancelNote: null,
      createdAt: at,
      title: title,
      photo: null,
      isBuyer: isBuyer,
      otherName: isBuyer ? 'Clarencia A.' : 'Faiqi H.',
    );
    orders.insert(0, o);
    return o;
  }

  void _set(String id, Order Function(Order) change) {
    final i = orders.indexWhere((o) => o.id == id);
    orders[i] = change(orders[i]);
  }

  Order _with(Order o, {OrderStatus? status, bool? extensionRequested}) => (
    id: o.id,
    listingId: o.listingId,
    kind: o.kind,
    status: status ?? o.status,
    price: o.price,
    isDonation: o.isDonation,
    holdUntil: o.holdUntil,
    extensionRequested: extensionRequested ?? o.extensionRequested,
    extended: o.extended,
    codCampus: o.codCampus,
    codPlace: o.codPlace,
    codAt: o.codAt,
    cancelReason: o.cancelReason,
    cancelNote: o.cancelNote,
    createdAt: o.createdAt,
    title: o.title,
    photo: o.photo,
    isBuyer: o.isBuyer,
    otherName: o.otherName,
  );

  @override
  Future<String> place(
    String listingId,
    OrderKind kind,
    Campus codCampus,
    String codPlace,
  ) async {
    _fail('place');
    calls.add('place $listingId ${kind.name} ${codCampus.code} $codPlace');
    return add(kind: kind).id;
  }

  @override
  Future<List<Order>> mine() async {
    await gate?.future;
    _fail('mine');
    return List.of(orders);
  }

  @override
  Future<void> accept(String id, DateTime codAt) async {
    _fail('accept');
    calls.add('accept $id');
    _set(id, (o) => _with(o, status: OrderStatus.processing));
  }

  @override
  Future<void> cancel(String id, CancelReason reason, String note) async {
    _fail('cancel');
    calls.add('cancel $id ${reason.code} $note');
    _set(id, (o) => _with(o, status: OrderStatus.cancelled));
  }

  @override
  Future<void> complete(String id) async {
    _fail('complete');
    calls.add('complete $id');
    _set(id, (o) => _with(o, status: OrderStatus.completed));
  }

  @override
  Future<void> requestExtension(String id) async {
    calls.add('requestExtension $id');
    _set(id, (o) => _with(o, extensionRequested: true));
  }

  @override
  Future<void> approveExtension(String id) async {
    calls.add('approveExtension $id');
  }

  @override
  Future<void> updateCod(
    String id,
    Campus campus,
    String place,
    DateTime? codAt,
  ) async {
    calls.add('updateCod $id ${campus.code} $place');
  }
}
