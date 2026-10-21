import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/copy.dart';
import '../data/listing_repository.dart';
import '../data/signup_repository.dart';
import '../domain/catalog.dart';
import '../domain/photo.dart';
import '../domain/quota.dart';
import '../domain/registration.dart';
import '../domain/signup_error.dart';
import '../ui/assets.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Pasang barang (#82): K5 Tambah Barang (daftar-11.png), then K6 Detail
/// Barang (no design yet). One screen holds both steps so nothing typed is
/// lost going back, or going to K8 when the quota is 0. Pops true once the
/// listing is live.
class SellScreen extends StatefulWidget {
  const SellScreen({
    super.key,
    required this.repository,
    required this.pickPhoto,
    required this.onBuyQuota,
  });

  final ListingRepository repository;

  /// A prepared JPEG (data/camera.dart), or null when the seller backs out.
  final Future<Uint8List?> Function({required bool camera}) pickPhoto;

  /// Opens K8 and completes when the seller comes back.
  final Future<void> Function() onBuyQuota;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  var _donation = false;
  ListingCategory? _category;
  ListingCondition? _condition;
  Campus? _campus;
  final _photos = <Uint8List>[];
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _warranty = TextEditingController();
  final _specs = TextEditingController();

  // One id per draft: Pasang again after a lost answer must not list twice.
  final _listingId = newListingId();
  final _scroll = ScrollController();
  var _onDetails = false;
  var _errors = <ListingField>{};
  String? _photoError;
  SellerInfo? _seller;
  var _sellerFailed = false;
  var _posting = false;
  String? _postError;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _stock, _warranty, _specs]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSeller() async {
    setState(() => _sellerFailed = false);
    try {
      final seller = await widget.repository.seller();
      if (mounted) setState(() => _seller = seller);
    } catch (_) {
      if (mounted) setState(() => _sellerFailed = true);
    }
  }

  ListingDraft get _draft => (
    isDonation: _donation,
    category: _category,
    photoCount: _photos.length,
    title: _title.text,
    description: _description.text,
    condition: _condition,
    price: int.tryParse(_price.text),
    stock: int.tryParse(_stock.text),
    specs: _specs.text,
  );

  String? _error(ListingField f) => _errors.contains(f) ? t(f.copyKey) : null;

  Future<void> _addPhoto() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t('sellCamera')),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t('sellGallery')),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    setState(() => _photoError = null);
    try {
      final photo = await widget.pickPhoto(camera: camera);
      if (photo != null && mounted) setState(() => _photos.add(photo));
    } on PhotoException catch (e) {
      if (!mounted) return;
      setState(
        () => _photoError = t(
          e.error == PhotoError.cameraDenied
              ? 'sellCameraDenied'
              : e.error.copyKey,
        ),
      );
    }
  }

  void _next() {
    final errors = validateListing(_draft).intersection(k5Fields);
    setState(() {
      _errors = errors;
      if (errors.isEmpty) _onDetails = true;
    });
    if (_onDetails && _scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _post() async {
    final errors = validateListing(_draft);
    setState(() {
      _errors = errors;
      _postError = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _posting = true);
    try {
      await publishListing(widget.repository, (
        id: _listingId,
        draft: _draft,
        campus: _campus ?? _seller!.campus,
        warranty: _warranty.text,
      ), List.of(_photos));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final error = e is SignupException ? e.error : null;
      setState(() {
        _posting = false;
        _postError = switch (error) {
          SignupError.noQuota || SignupError.notAllowed => t(error!.copyKey),
          _ => t('sellFailed'),
        };
      });
      if (error == SignupError.noQuota) await _loadSeller();
    }
  }

  Future<void> _buyQuota() async {
    await widget.onBuyQuota();
    if (mounted) await _loadSeller();
  }

  void _back() {
    if (_posting) return;
    if (_onDetails) {
      setState(() {
        _onDetails = false;
        _postError = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_onDetails && !_posting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: BeeHeader(
          title: Text(t(_onDetails ? 'sellDetails' : 'sellTitle')),
          onBack: _back,
        ),
        body: SafeArea(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              BeeSpacing.screenX,
              16,
              BeeSpacing.screenX,
              24,
            ),
            children: _onDetails ? _details(context) : _basics(context),
          ),
        ),
      ),
    );
  }

  /// K5, daftar-11.png.
  List<Widget> _basics(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: BeeChoiceCard(
              image: BeeAssets.sellItem,
              title: t('sellTypeSale'),
              body: t('sellTypeSaleBody'),
              selected: !_donation,
              onTap: () => setState(() => _donation = false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: BeeChoiceCard(
              image: BeeAssets.donateItem,
              title: t('sellTypeDonation'),
              body: t('sellTypeDonationBody'),
              selected: _donation,
              onTap: () => setState(() => _donation = true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      BeeWarningBanner(t('sellProhibited')),
      const SizedBox(height: 24),
      BeeDropdownField<ListingCategory>(
        label: t('sellCategory'),
        hint: t('sellCategoryHint'),
        items: ListingCategory.values,
        itemLabel: (c) => t(c.copyKey),
        value: _category,
        errorText: _error(ListingField.category),
        onChanged: (c) => setState(() => _category = c),
      ),
      const SizedBox(height: 24),
      Text(t('sellPhotos'), style: textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(t('sellPhotosHelp'), style: textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, photo) in _photos.indexed)
            _PhotoTile(
              photo: photo,
              removeLabel: t('sellRemovePhoto').replaceAll('{i}', '${i + 1}'),
              onRemove: () => setState(() => _photos.removeAt(i)),
            ),
          if (_photos.length < maxListingPhotos)
            SizedBox.square(
              dimension: _PhotoTile.size,
              child: IconButton.outlined(
                tooltip: t('sellAddPhoto'),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BeeRadius.field),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                onPressed: _addPhoto,
              ),
            ),
        ],
      ),
      if (_photoError != null) ...[
        const SizedBox(height: 8),
        BeeFormError(_photoError!),
      ],
      if (_error(ListingField.photos) case final error?) ...[
        const SizedBox(height: 8),
        BeeFormError(error),
      ],
      const SizedBox(height: 24),
      BeeTextField(
        label: t('sellName'),
        hint: t('sellNameHint'),
        controller: _title,
        maxLength: maxTitleLength,
        errorText: _error(ListingField.title),
      ),
      const SizedBox(height: 16),
      BeeTextField(
        label: t('description'),
        hint: t('sellDescriptionHint'),
        controller: _description,
        maxLines: null,
        maxLength: maxDescriptionLength,
        keyboardType: TextInputType.multiline,
        errorText: _error(ListingField.description),
      ),
      const SizedBox(height: 32),
      FilledButton(onPressed: _next, child: Text(t('sellNext'))),
    ];
  }

  /// K6, no design yet: PRD-katalog 5.2.
  List<Widget> _details(BuildContext context) {
    final seller = _seller;
    if (seller == null) {
      return [
        if (_sellerFailed) ...[
          Text(t('sellLoadFailed'), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _loadSeller, child: Text(t('retry'))),
        ] else
          const Center(child: CircularProgressIndicator()),
      ];
    }
    // 9 digits stay within a Postgres integer.
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
    ];
    final canPost = canList(seller.quota);
    return [
      BeeDropdownField<ListingCondition>(
        label: t('condition'),
        hint: t('sellConditionHint'),
        items: ListingCondition.values,
        itemLabel: (c) => t(c.copyKey),
        value: _condition,
        errorText: _error(ListingField.condition),
        onChanged: (c) => setState(() => _condition = c),
      ),
      const SizedBox(height: 16),
      // Donations are Rp0 (D-28): no price to fill in.
      if (!_donation) ...[
        BeeTextField(
          label: t('sellPrice'),
          hint: t('sellPriceHint'),
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
        value: _campus ?? seller.campus,
        onChanged: (c) => setState(() => _campus = c),
      ),
      const SizedBox(height: 24),
      Text(
        canPost
            ? t('sellQuota').replaceAll('{n}', '${seller.quota}')
            : t('sellQuotaEmpty'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (_postError != null) ...[
        const SizedBox(height: 16),
        BeeFormError(_postError!),
      ],
      const SizedBox(height: 16),
      if (canPost)
        FilledButton(
          onPressed: _posting ? null : _post,
          child: BeeButtonLabel(t('sellPost'), loading: _posting),
        )
      else
        FilledButton(onPressed: _buyQuota, child: Text(t('sellBuyQuota'))),
    ];
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.removeLabel,
    required this.onRemove,
  });

  static const size = 96.0;

  final Uint8List photo;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(BeeRadius.field),
            child: Image.memory(photo, fit: BoxFit.cover),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton.filledTonal(
              tooltip: removeLabel,
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// K8 placeholder: #84 builds the package purchase here.
class BuyQuotaScreen extends StatelessWidget {
  const BuyQuotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BeeHeader(title: Text(t('buyQuotaTitle'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BeeSpacing.screenX),
          child: Center(
            child: Text(t('buyQuotaSoon'), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
