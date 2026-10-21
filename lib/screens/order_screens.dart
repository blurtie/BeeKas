import 'dart:async';

import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/order_repository.dart';
import '../data/signup_repository.dart';
import '../domain/catalog.dart';
import '../domain/order.dart';
import '../domain/registration.dart';
import '../ui/assets.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

const _pad = 16.0;

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

String _errorText(SignupException e) =>
    t(e.error?.copyKey ?? 'errorSignupUnknown');

String _price(int price, bool donation) =>
    donation ? t('free') : formatRupiah(price);

String _two(int n) => n.toString().padLeft(2, '0');

/// "23:48": hours and minutes left.
String _hoursMinutes(Duration d) =>
    '${_two(d.inHours)}:${_two(d.inMinutes % 60)}';

String _dateTime(BuildContext context, DateTime at) {
  final l = MaterialLocalizations.of(context);
  final local = at.toLocal();
  return '${l.formatMediumDate(local)}, '
      '${l.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
}

/// Lokasi COD (D-30): campus plus optional free text. Null when cancelled.
Future<(Campus, String)?> _editLocation(
  BuildContext context,
  Campus campus,
  String place,
) => showDialog<(Campus, String)>(
  context: context,
  builder: (context) => _LocationDialog(campus: campus, place: place),
);

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({required this.campus, required this.place});
  final Campus campus;
  final String place;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late var _campus = widget.campus;
  late final _place = TextEditingController(text: widget.place);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('codLocation')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Campus>(
            initialValue: _campus,
            decoration: InputDecoration(labelText: t('campus')),
            isExpanded: true,
            items: [
              for (final c in Campus.values)
                DropdownMenuItem(value: c, child: Text(t(c.copyKey))),
            ],
            onChanged: (c) => setState(() => _campus = c ?? _campus),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _place,
            maxLength: maxCodPlace,
            decoration: InputDecoration(
              labelText: t('codPlace'),
              hintText: t('codPlaceHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (_campus, _place.text.trim())),
          child: Text(t('save')),
        ),
      ],
    );
  }
}

/// The Lokasi COD card of K9 and K11, with Ubah.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.campus,
    required this.place,
    required this.onChange,
  });
  final Campus campus;
  final String place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_pad, 8, 8, _pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t('codLocation'), style: textTheme.titleMedium),
                ),
                TextButton(onPressed: onChange, child: Text(t('change'))),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: BeeColors.link),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(campus.copyKey), style: textTheme.titleSmall),
                      if (place.isNotEmpty)
                        Text(place, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The listing photo, or a placeholder.
class _Thumb extends StatelessWidget {
  const _Thumb(this.url, {this.size = 72});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: BeeColors.border,
      child: const Icon(Icons.image_outlined, color: BeeColors.textMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(BeeRadius.field),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Mixin for the two order forms: a busy flag and the refusal text.
mixin _Placing<T extends StatefulWidget> on State<T> {
  var busy = false;
  String? error;

  Future<void> run(Future<void> Function() call) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await call();
    } on SignupException catch (e) {
      if (mounted) setState(() => error = _errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

/// K9 Booking Barang (daftar-13), with the Lokasi COD the buyer sets (5.6).
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.listing,
    required this.repository,
    this.now = DateTime.now,
  });
  final Listing listing;
  final OrderRepository repository;
  final DateTime Function() now;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with _Placing<BookingScreen> {
  late var _campus = widget.listing.campus;
  var _place = '';

  Future<void> _book() => run(() async {
    final l = widget.listing;
    await widget.repository.place(l.id, OrderKind.booking, _campus, _place);
    if (!mounted) return;
    final until = holdUntil(widget.now());
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            BookingStatusScreen(listing: l, holdUntil: until, now: widget.now),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l = widget.listing;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BeeSpacing.screenX),
          children: [
            Image.asset(
              BeeAssets.beeWriting,
              height: 160,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 16),
            Text(
              t('bookingTitle'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: BeeColors.textHeading,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('bookingIntro').replaceAll('{title}', l.title),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                color: BeeColors.warningSurface,
                border: Border.all(color: BeeColors.brandPrimary),
                borderRadius: BorderRadius.circular(BeeRadius.banner),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: BeeColors.stepperInactive,
                        child: Icon(Icons.schedule, color: BeeColors.link),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('bookingHeld'), style: textTheme.titleSmall),
                            Text(
                              t('booking24'),
                              style: textTheme.titleLarge?.copyWith(
                                color: BeeColors.link,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t('bookingAutoCancel'),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error, color: BeeColors.brandPrimary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          t('bookingNoPayment'),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LocationCard(
              campus: _campus,
              place: _place,
              onChange: () async {
                final picked = await _editLocation(context, _campus, _place);
                if (picked != null) {
                  setState(() {
                    _campus = picked.$1;
                    _place = picked.$2;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            if (error != null) ...[
              BeeFormError(error!),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: busy ? null : _book,
              child: Text(t('bookingConfirm')),
            ),
            const SizedBox(height: 12),
            BeeOutlinedPillButton(
              label: t('cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// K10 Status Booking (daftar-5): the hold counts down from [holdUntil].
class BookingStatusScreen extends StatefulWidget {
  const BookingStatusScreen({
    super.key,
    required this.listing,
    required this.holdUntil,
    this.now = DateTime.now,
  });
  final Listing listing;
  final DateTime holdUntil;
  final DateTime Function() now;

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l = widget.listing;
    final left = remainingHold(widget.holdUntil, widget.now());
    final heading = textTheme.titleMedium?.copyWith(
      color: BeeColors.textHeading,
      fontWeight: FontWeight.w700,
    );
    Widget unit(int value, String label) => Column(
      children: [
        Text(
          _two(value),
          style: textTheme.headlineMedium?.copyWith(
            color: BeeColors.link,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
    final colon = Text(':', style: textTheme.headlineMedium);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t('bookingStatusTitle')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BeeSpacing.screenX),
          children: [
            Card.outlined(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: BeeColors.success),
                borderRadius: BorderRadius.circular(BeeRadius.banner),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(_pad),
                leading: const Icon(
                  Icons.check_circle,
                  color: BeeColors.success,
                  size: 40,
                ),
                title: Text(t('bookingDone'), style: heading),
                subtitle: Text(t('bookingDoneBody')),
              ),
            ),
            const SizedBox(height: 24),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(_pad),
                child: Row(
                  children: [
                    _Thumb(l.photos.firstOrNull, size: 96),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.title, style: heading),
                          const SizedBox(height: 4),
                          Text(
                            _price(l.price, l.isDonation),
                            style: textTheme.titleMedium?.copyWith(
                              color: BeeColors.link,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(l.sellerName, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(_pad),
                child: Column(
                  children: [
                    Text(t('holdLeftTitle'), style: heading),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: false,
                      label: t('holdLeft')
                          .replaceAll('{time}', _hoursMinutes(left)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: BeeColors.stepperInactive,
                          borderRadius: BorderRadius.circular(BeeRadius.banner),
                        ),
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 16,
                              children: [
                                unit(left.inHours, t('hours')),
                                colon,
                                unit(left.inMinutes % 60, t('minutes')),
                                colon,
                                unit(left.inSeconds % 60, t('seconds')),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BeeWarningBanner(t('holdWarning')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              // Chat comes with T8 (#13).
              onPressed: () => _snack(context, t('comingSoon')),
              child: Text(t('chatSeller')),
            ),
            const SizedBox(height: 12),
            BeeOutlinedPillButton(
              label: t('back'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// K11 Checkout (daftar-7 with the D-22.3 corrections): Lokasi COD instead
/// of a shipping address, COD on campus, qty 1, no other fees.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.listing,
    required this.repository,
    this.now = DateTime.now,
  });
  final Listing listing;
  final OrderRepository repository;
  final DateTime Function() now;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with _Placing<CheckoutScreen> {
  late var _campus = widget.listing.campus;
  var _place = '';

  Future<void> _confirm() => run(() async {
    await widget.repository.place(
      widget.listing.id,
      OrderKind.buy,
      _campus,
      _place,
    );
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OrdersScreen(repository: widget.repository, now: widget.now),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l = widget.listing;
    final price = _price(l.price, l.isDonation);
    Widget line(String label, String value, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style ?? textTheme.bodyMedium)),
          Text(value, style: style ?? textTheme.bodyMedium),
        ],
      ),
    );

    return Scaffold(
      appBar: BeeHeader(title: Text(t('checkoutTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(_pad),
        children: [
          _LocationCard(
            campus: _campus,
            place: _place,
            onChange: () async {
              final picked = await _editLocation(context, _campus, _place);
              if (picked != null) {
                setState(() {
                  _campus = picked.$1;
                  _place = picked.$2;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Text(t('paymentMethod'), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card.outlined(
            margin: EdgeInsets.zero,
            color: BeeColors.warningSurface,
            child: ListTile(
              contentPadding: const EdgeInsets.all(_pad),
              leading: const CircleAvatar(
                backgroundColor: BeeColors.stepperInactive,
                child: Icon(Icons.payments_outlined, color: BeeColors.link),
              ),
              title: Text(t('codMethod')),
              subtitle: Text(t('codMethodBody')),
            ),
          ),
          const SizedBox(height: 16),
          Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(_pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('orderSummary'), style: textTheme.titleMedium),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _Thumb(l.photos.firstOrNull),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.title, style: textTheme.titleSmall),
                            Text(
                              t('orderQty').replaceAll('{n}', '1'),
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        price,
                        style: textTheme.titleSmall?.copyWith(
                          color: BeeColors.link,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  line(t('subtotal'), price),
                  line(
                    t('total'),
                    price,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BeeWarningBanner(t('checkoutCodOnly')),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                BeeFormError(error!),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: busy ? null : _confirm,
                child: Text(t('checkoutConfirm')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The K12 chips (D-36): every status, or one.
enum _Filter { all, waiting, processing, completed, cancelled }

/// K12 Pesanan Saya (daftar-8 with the COD statuses): Pembelian and
/// Penjualan tabs (K-16), filtered by status.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });
  final OrderRepository repository;
  final DateTime Function() now;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _orders = widget.repository.mine();
  var _filter = _Filter.all;

  void _reload() {
    setState(() {
      _orders = widget.repository.mine();
    });
  }

  Future<void> _open(Order order) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          order: order,
          repository: widget.repository,
          now: widget.now,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Widget _list(List<Order> all, bool buyer) {
    final orders = [
      for (final o in all)
        if (o.isBuyer == buyer &&
            (_filter == _Filter.all || o.status.name == _filter.name))
          o,
    ];
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(_pad),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final f in _Filter.values)
                  ChoiceChip(
                    label: Text(t('orderFilter_${f.name}')),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(t('ordersEmpty'), textAlign: TextAlign.center),
            )
          else
            for (final o in orders)
              _OrderCard(order: o, now: widget.now(), onTap: () => _open(o)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: t('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(t('ordersTitle')),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(text: t('ordersPurchases')),
              Tab(text: t('ordersSales')),
            ],
          ),
        ),
        body: FutureBuilder(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data;
            if (orders == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(BeeSpacing.screenX),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t('ordersLoadFailed'), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _reload,
                        child: Text(t('retry')),
                      ),
                    ],
                  ),
                ),
              );
            }
            return TabBarView(
              children: [_list(orders, true), _list(orders, false)],
            );
          },
        ),
      ),
    );
  }
}

/// The status badge of K12 and K13.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    // success is below 4.5:1 as text, so Selesai keeps it for the border only.
    final (surface, text, border) = switch (status) {
      OrderStatus.waiting => (
        BeeColors.warningSurface,
        BeeColors.link,
        BeeColors.link,
      ),
      OrderStatus.processing => (
        BeeColors.infoSurface,
        BeeColors.textHeading,
        BeeColors.textHeading,
      ),
      OrderStatus.completed => (
        BeeColors.surface,
        BeeColors.textHeading,
        BeeColors.success,
      ),
      OrderStatus.cancelled => (
        BeeColors.surface,
        BeeColors.error,
        BeeColors.error,
      ),
    };
    return Chip(
      label: Text(t('orderStatus_${status.name}')),
      labelStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: text, fontWeight: FontWeight.w600),
      backgroundColor: surface,
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.now,
    required this.onTap,
  });
  final Order order;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final o = order;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_pad),
          child: Row(
            children: [
              _Thumb(o.photo, size: 88),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: BeeColors.textHeading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _price(o.price, o.isDonation),
                      style: textTheme.titleSmall?.copyWith(
                        color: BeeColors.link,
                      ),
                    ),
                    _StatusBadge(o.status),
                    if (o.status == OrderStatus.waiting && o.holdUntil != null)
                      Text(
                        t('holdLeft').replaceAll(
                          '{time}',
                          _hoursMinutes(remainingHold(o.holdUntil!, now)),
                        ),
                        style: textTheme.bodySmall,
                      ),
                    Text(
                      _dateTime(context, o.createdAt),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// K13 Detail Pesanan (no design): the order and what this party may do
/// with it (6.6). After each action the order is read again.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.repository,
    this.now = DateTime.now,
  });
  final Order order;
  final OrderRepository repository;
  final DateTime Function() now;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late var _order = widget.order;
  var _busy = false;

  Future<void> _act(Future<void> Function() call) async {
    setState(() => _busy = true);
    String message;
    try {
      await call();
      message = t('orderUpdated');
    } on SignupException catch (e) {
      message = _errorText(e);
    }
    try {
      final fresh = await widget.repository.mine();
      _order = fresh.firstWhere((o) => o.id == _order.id, orElse: () => _order);
    } on SignupException {
      // Keep what is shown; the list reloads on the way back.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(context, message);
  }

  /// A date, then a time, from now on; null when backed out.
  Future<DateTime?> _pickCodTime() async {
    final now = widget.now().toLocal();
    final start = _order.codAt?.toLocal() ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _run(OrderAction action) async {
    final o = _order;
    final repo = widget.repository;
    switch (action) {
      case OrderAction.accept:
        final at = await _pickCodTime();
        if (at != null) await _act(() => repo.accept(o.id, at));
      case OrderAction.cancel:
        final reason = await showDialog<(CancelReason, String)>(
          context: context,
          builder: (_) => const _CancelDialog(),
        );
        if (reason != null) {
          await _act(() => repo.cancel(o.id, reason.$1, reason.$2));
        }
      case OrderAction.complete:
        await _act(() => repo.complete(o.id));
      case OrderAction.requestExtension:
        await _act(() => repo.requestExtension(o.id));
      case OrderAction.approveExtension:
        await _act(() => repo.approveExtension(o.id));
      case OrderAction.updateLocation:
        final picked = await _editLocation(
          context,
          o.codCampus,
          o.codPlace ?? '',
        );
        if (picked != null) {
          await _act(() => repo.updateCod(o.id, picked.$1, picked.$2, o.codAt));
        }
      case OrderAction.updateCodTime:
        final at = await _pickCodTime();
        if (at != null) {
          await _act(
            () => repo.updateCod(o.id, o.codCampus, o.codPlace ?? '', at),
          );
        }
    }
  }

  String _label(OrderAction action) =>
      action == OrderAction.cancel &&
          !_order.isBuyer &&
          _order.status == OrderStatus.waiting
      ? t('orderAction_reject')
      : t('orderAction_${action.name}');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final o = _order;
    final actions = orderActions(roleOf(o), stateOf(o));
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label, style: textTheme.labelLarge)),
          Expanded(child: value),
        ],
      ),
    );
    Text text(String s) => Text(s, style: textTheme.bodyMedium);
    // Accept and Sudah diterima lead; the rest are outlined.
    const primary = {OrderAction.accept, OrderAction.complete};

    return Scaffold(
      appBar: BeeHeader(title: Text(t('orderDetailTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(_pad),
        children: [
          Row(
            children: [
              _Thumb(o.photo, size: 88),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: BeeColors.textHeading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _price(o.price, o.isDonation),
                      style: textTheme.titleMedium?.copyWith(
                        color: BeeColors.link,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          row(
            t('orderStatus'),
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(o.status),
            ),
          ),
          row(t('orderKind'), text(t('orderKind_${o.kind.name}'))),
          row(t(o.isBuyer ? 'orderSeller' : 'orderBuyer'), text(o.otherName)),
          row(
            t('codLocation'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(t(o.codCampus.copyKey)),
                if (o.codPlace != null) text(o.codPlace!),
              ],
            ),
          ),
          row(
            t('codTime'),
            text(
              o.codAt == null
                  ? t('codTimeUnset')
                  : _dateTime(context, o.codAt!),
            ),
          ),
          if (o.status == OrderStatus.waiting && o.holdUntil != null)
            row(
              '',
              text(
                t('holdLeft').replaceAll(
                  '{time}',
                  _hoursMinutes(remainingHold(o.holdUntil!, widget.now())),
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (o.status == OrderStatus.waiting &&
              o.extensionRequested &&
              !o.extended)
            BeeWarningBanner(t('extensionRequested')),
          if (o.status == OrderStatus.processing)
            BeeWarningBanner(t('autoCompleteNote')),
          if (o.status == OrderStatus.cancelled)
            BeeWarningBanner(
              o.cancelReason == null
                  ? t('cancelledAuto')
                  : t('cancelledReason').replaceAll(
                      '{reason}',
                      [t(o.cancelReason!.copyKey), ?o.cancelNote].join(' · '),
                    ),
            ),
          const SizedBox(height: 24),
          for (final action in OrderAction.values)
            if (actions.contains(action))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: primary.contains(action)
                    ? FilledButton(
                        onPressed: _busy ? null : () => _run(action),
                        child: Text(_label(action)),
                      )
                    : OutlinedButton(
                        onPressed: _busy ? null : () => _run(action),
                        child: Text(_label(action)),
                      ),
              ),
          BeeOutlinedPillButton(
            label: t('chatSeller'),
            onPressed: () => _snack(context, t('comingSoon')),
          ),
        ],
      ),
    );
  }
}

/// K-18: a fixed reason, plus a note required for Lainnya.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  CancelReason? _reason;
  final _note = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isValidCancellation(_reason, _note.text)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, (_reason!, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('cancelTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in CancelReason.values)
                  ChoiceChip(
                    label: Text(t(r.copyKey)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: maxCancelNote,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: t('cancelNote')),
            ),
            if (_invalid) BeeFormError(t('cancelReasonRequired')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('back')),
        ),
        TextButton(onPressed: _submit, child: Text(t('cancelOrder'))),
      ],
    );
  }
}
