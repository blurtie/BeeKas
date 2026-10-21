import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/copy.dart';
import '../data/listing_repository.dart';
import '../domain/catalog.dart';
import '../domain/registration.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

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
  List<MyListing>? _listings;
  var _failed = false;
  // The listing whose action is running; its buttons are disabled.
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final listings = await widget.repository.myListings();
      if (mounted) setState(() => _listings = listings);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _snack(String key) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t(key))));

  Future<void> _act(
    String id,
    Future<void> Function() action,
    String done,
  ) async {
    setState(() => _busy = id);
    try {
      await action();
      if (!mounted) return;
      _snack(done);
      await _load();
    } catch (_) {
      if (mounted) _snack('myListingsActionFailed');
    } finally {
      if (mounted) setState(() => _busy = null);
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
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t('myListingsWithdrawConfirm')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _act(
      l.id,
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
    if (saved == true && mounted) {
      _snack('myListingsSaved');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listings = _listings;
    final now = widget.now();
    return Scaffold(
      appBar: BeeHeader(title: Text(t('myListingsTitle'))),
      body: SafeArea(
        child: switch (listings) {
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
              for (final l
                  in [...listings]..sort(
                    (a, b) => listingStatus(
                      a,
                      now,
                    ).index.compareTo(listingStatus(b, now).index),
                  ))
                _MyListingCard(
                  listing: l,
                  status: listingStatus(l, now),
                  daysLeft: daysLeft(l, now),
                  busy: _busy == l.id,
                  onEdit: () => _edit(l),
                  onWithdraw: () => _withdraw(l),
                  onRelist: () => _act(
                    l.id,
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
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              label: Text(t(status.copyKey)),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              l.title,
              style: textTheme.titleSmall?.copyWith(
                color: BeeColors.textHeading,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              l.isDonation ? t('free') : formatRupiah(l.price),
              style: textTheme.titleSmall?.copyWith(color: BeeColors.link),
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
                t('myListingsDaysLeft').replaceAll('{n}', '$daysLeft'),
                style: textTheme.bodySmall,
              ),
            if (l.removalReason case final reason?)
              Text(
                t('myListingsRemovedReason').replaceAll('{reason}', reason),
                style: textTheme.bodySmall,
              ),
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
  var _failed = false;

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
      _failed = false;
    });
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateListing(_l.id, edit);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
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
            if (_failed) ...[
              const SizedBox(height: 16),
              BeeFormError(t('myListingsActionFailed')),
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
