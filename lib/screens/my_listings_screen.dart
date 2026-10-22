import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/copy.dart';
import '../data/listing_repository.dart';
import '../data/signup_repository.dart';
import '../domain/catalog.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'catalog_screens.dart' show ListingPhoto;

/// K7 Barang Saya (#83), no design yet: PRD-katalog 5.2. Every own listing
/// with its status, days left and stock left; Edit, Turunkan and Tayang
/// ulang where the status allows them.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  final ListingRepository repository;
  final DateTime Function() now;

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  // Sorted with their status once per load (sortMyListings).
  List<(MyListing, ListingStatus)>? _items;
  late DateTime _loadedAt;
  var _failed = false;
  // One action at a time: every button is disabled while it runs.
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _items = null;
    });
    try {
      final mine = await widget.repository.myListings();
      final now = widget.now();
      if (!mounted) return;
      setState(() {
        _loadedAt = now;
        _items = sortMyListings(
          mine.listings,
          now,
          sellerListed: mine.sellerListed,
        );
      });
    } catch (_) {
      // Never keep a stale list: show the error state.
      if (mounted) setState(() => _failed = true);
    }
  }

  void _snack(String key) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t(key))));

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (mounted) _snack(done);
    } catch (e) {
      if (!mounted) return;
      // not_allowed: the listing or the account changed since loading.
      if (e is SignupException && e.error == SignupError.notAllowed) {
        _snack('myListingsStale');
        await _load();
      } else if (e is SignupException &&
          e.error == SignupError.listingHasOrders) {
        _snack('errorListingHasOrders');
        await _load();
      } else {
        _snack('myListingsActionFailed');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(MyListing l) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          t('myListingsWithdrawTitle').replaceAll('{title}', l.title),
        ),
        content: Text(t('myListingsWithdrawBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            // The theme's full-width minimum would stack it under Batal.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t('myListingsWithdrawConfirm')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _act(
      () => widget.repository.withdrawListing(l.id),
      'myListingsWithdrawn',
    );
  }

  Future<void> _edit(MyListing l) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditListingScreen(repository: widget.repository, listing: l),
      ),
    );
    if (!mounted) return;
    if (saved == true) _snack('myListingsSaved');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: BeeHeader(title: Text(t('myListingsTitle'))),
      body: SafeArea(
        child: switch (items) {
          null when _failed => Center(
            child: Padding(
              padding: const EdgeInsets.all(BeeSpacing.screenX),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('myListingsLoadFailed'), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _load, child: Text(t('retry'))),
                ],
              ),
            ),
          ),
          null => const Center(child: CircularProgressIndicator()),
          [] => Center(
            child: Padding(
              padding: const EdgeInsets.all(BeeSpacing.screenX),
              child: Text(t('myListingsEmpty'), textAlign: TextAlign.center),
            ),
          ),
          _ => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (l, status) in items)
                _MyListingCard(
                  listing: l,
                  status: status,
                  daysLeft: daysLeft(l, _loadedAt),
                  busy: _busy,
                  onEdit: () => _edit(l),
                  onWithdraw: () => _withdraw(l),
                  onRelist: () => _act(
                    () => widget.repository.relistListing(l.id),
                    'myListingsRelisted',
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.listing,
    required this.status,
    required this.daysLeft,
    required this.busy,
    required this.onEdit,
    required this.onWithdraw,
    required this.onRelist,
  });

  final MyListing listing;
  final ListingStatus status;
  final int daysLeft;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;
  final VoidCallback onRelist;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final textTheme = Theme.of(context).textTheme;
    final running =
        status == ListingStatus.live || status == ListingStatus.soldOut;
    final hasActions =
        canEditListing(status) ||
        canWithdrawListing(status) ||
        canRelistListing(status);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, hasActions ? 4 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(BeeRadius.field),
                  child: SizedBox.square(
                    dimension: 72,
                    child: ListingPhoto(l.photos.firstOrNull),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusLabel(status),
                      const SizedBox(height: 4),
                      Text(
                        l.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: BeeColors.textHeading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l.isDonation ? t('free') : formatRupiah(l.price),
                        style: textTheme.titleSmall?.copyWith(
                          color: BeeColors.link,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('myListingsStockLeft')
                            .replaceAll('{left}', '${l.stockLeft}')
                            .replaceAll('{stock}', '${l.stock}'),
                        style: textTheme.bodySmall,
                      ),
                      if (running)
                        Text(
                          t('myListingsDaysLeft')
                              .replaceAll('{n}', '$daysLeft'),
                          style: textTheme.bodySmall,
                        ),
                      if (l.removalReason case final reason?)
                        Text(
                          t('myListingsRemovedReason')
                              .replaceAll('{reason}', reason),
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasActions)
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  if (canEditListing(status))
                    TextButton(
                      onPressed: busy ? null : onEdit,
                      child: Text(t('edit')),
                    ),
                  if (canWithdrawListing(status))
                    TextButton(
                      onPressed: busy ? null : onWithdraw,
                      child: Text(t('myListingsWithdraw')),
                    ),
                  if (canRelistListing(status))
                    TextButton(
                      onPressed: busy ? null : onRelist,
                      child: Text(t('myListingsRelist')),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Status as a coloured label, one colour per group; text no larger than
/// the title. Each pair is ≥ 4.5:1.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status);
  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      ListingStatus.live => (BeeColors.infoSurface, BeeColors.textHeading),
      ListingStatus.soldOut ||
      ListingStatus.expired => (BeeColors.warningSurface, BeeColors.link),
      _ => (BeeColors.border, BeeColors.error),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BeeRadius.field),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          t(status.copyKey),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Edit (D-28, K-06), no design yet: the K6 fields plus the description;
/// the locked ones are named, not editable. Pops true once saved.
class EditListingScreen extends StatefulWidget {
  const EditListingScreen({
    super.key,
    required this.repository,
    required this.listing,
  });

  final ListingRepository repository;
  final MyListing listing;

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late final MyListing _l = widget.listing;
  late final _description = TextEditingController(text: _l.description);
  late final _price = TextEditingController(text: '${_l.price}');
  late final _stock = TextEditingController(text: '${_l.stock}');
  late final _warranty = TextEditingController(text: _l.warranty ?? '');
  late final _specs = TextEditingController(text: _l.specs.join('\n'));
  late ListingCondition _condition = _l.condition;
  late Campus _campus = _l.campus;
  var _errors = <ListingField>{};
  var _saving = false;
  // The copy key of the last save failure.
  String? _failed;

  @override
  void dispose() {
    for (final c in [_description, _price, _stock, _warranty, _specs]) {
      c.dispose();
    }
    super.dispose();
  }

  ListingEdit get _edit => (
    description: _description.text,
    condition: _condition,
    // Donations stay Rp0 (D-28).
    price: _l.isDonation ? 0 : int.tryParse(_price.text),
    stock: int.tryParse(_stock.text),
    campus: _campus,
    warranty: _warranty.text,
    specs: _specs.text,
  );

  String? _error(ListingField f) => _errors.contains(f) ? t(f.copyKey) : null;

  Future<void> _save() async {
    final edit = _edit;
    setState(() {
      _errors = validateEdit(_l, edit);
      _failed = null;
    });
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateListing(_l.id, edit);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = e is SignupException && e.error == SignupError.notAllowed
              ? 'myListingsStale'
              : 'myListingsActionFailed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
    ];
    return Scaffold(
      appBar: BeeHeader(title: Text(t('editListingTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text(
              _l.title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: BeeColors.textHeading),
            ),
            const SizedBox(height: 8),
            BeeWarningBanner(t('myListingsLocked')),
            const SizedBox(height: 24),
            BeeTextField(
              label: t('description'),
              controller: _description,
              maxLines: null,
              maxLength: maxDescriptionLength,
              keyboardType: TextInputType.multiline,
              errorText: _error(ListingField.description),
            ),
            const SizedBox(height: 16),
            BeeDropdownField<ListingCondition>(
              label: t('condition'),
              items: ListingCondition.values,
              itemLabel: (c) => t(c.copyKey),
              value: _condition,
              onChanged: (c) => setState(() => _condition = c ?? _condition),
            ),
            const SizedBox(height: 16),
            if (!_l.isDonation) ...[
              BeeTextField(
                label: t('sellPrice'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                errorText: _error(ListingField.price),
              ),
              const SizedBox(height: 16),
            ],
            BeeTextField(
              label: t('stock'),
              controller: _stock,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              errorText: _error(ListingField.stock),
            ),
            const SizedBox(height: 16),
            BeeTextField(
              label: t('sellWarranty'),
              hint: t('sellWarrantyHint'),
              controller: _warranty,
            ),
            const SizedBox(height: 16),
            BeeTextField(
              label: t('sellSpecs'),
              controller: _specs,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              helperText: t('sellSpecsHelp'),
              errorText: _error(ListingField.specs),
            ),
            const SizedBox(height: 16),
            BeeDropdownField<Campus>(
              label: t('location'),
              items: Campus.values,
              itemLabel: (c) => t(c.copyKey),
              value: _campus,
              onChanged: (c) => setState(() => _campus = c ?? _campus),
            ),
            if (_failed case final key?) ...[
              const SizedBox(height: 16),
              BeeFormError(t(key)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: BeeButtonLabel(t('save'), loading: _saving),
            ),
          ],
        ),
      ),
    );
  }
}
