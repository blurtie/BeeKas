import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/catalog_repository.dart';
import '../domain/access.dart';
import '../domain/catalog.dart';
import '../ui/assets.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Chat, Booking, Beli, favorites and selling come with later PRDs (#74).
/// [onSignOut], for signed-in members, rides along until Profil exists.
void showComingSoon(BuildContext context, {VoidCallback? onSignOut}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(t('comingSoon')),
        action: onSignOut == null
            ? null
            : SnackBarAction(label: t('signOut'), onPressed: onSignOut),
      ),
    );
}

String _categoryLabel(ListingCategory c) => t(c.copyKey);

/// A category's label in every language, for search (D-41).
Iterable<String> _categoryLabels(ListingCategory c) =>
    copy.values.map((m) => m[c.copyKey]!);

/// Beranda (home.png) and Kategori (Daftar-12) behind one bottom bar; both
/// page through the catalog on the server (#77). Guests and every status
/// browse it (D-06).
class CatalogShell extends StatefulWidget {
  const CatalogShell({
    super.key,
    required this.repository,
    this.onSignOut,
    this.status,
    this.onSell,
    this.onQuota,
    this.onMyListings,
  });

  final CatalogRepository repository;
  final VoidCallback? onSignOut;

  /// Null for guests.
  final AccountStatus? status;

  /// Opens Pasang barang (#82); completes true once a listing is live.
  final Future<bool?> Function()? onSell;

  /// Opens K8 Kuota Listing (#84) from Profil, for signed-in members.
  final VoidCallback? onQuota;

  /// Opens K7 Barang Saya (#83) from Profil, for signed-in members.
  final VoidCallback? onMyListings;

  @override
  State<CatalogShell> createState() => _CatalogShellState();
}

class _CatalogShellState extends State<CatalogShell> {
  var _tab = 0;
  // Bumped after a listing goes live, so the feeds load it.
  var _refresh = 0;

  void _soon() => showComingSoon(context);

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// + : approved accounts open the form; the rest learn why not (D-06).
  /// Freezes are invisible to the app; create_listing refuses those (K-26).
  Future<void> _sell() async {
    final status = widget.status;
    final onSell = widget.onSell;
    if (!canCreateListing(status, frozen: false) || onSell == null) {
      return _snack(t('sellNeedsApproval_${status?.name ?? 'guest'}'));
    }
    if (await onSell() == true && mounted) {
      setState(() => _refresh++);
      _snack(t('sellPosted'));
    }
  }

  /// Temporary Profil until K17: Kuota and Keluar for members; guests and
  /// accounts without them get Segera hadir.
  void _profile() {
    final onQuota = widget.onQuota;
    final onSignOut = widget.onSignOut;
    final onMyListings = widget.onMyListings;
    if (onQuota == null) return showComingSoon(context, onSignOut: onSignOut);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onMyListings != null)
              ListTile(
                title: Text(t('profileMyListings')),
                onTap: () {
                  Navigator.pop(sheet);
                  onMyListings();
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(t('profileQuota')),
              onTap: () {
                Navigator.pop(sheet);
                onQuota();
              },
            ),
            if (onSignOut != null)
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(t('signOut')),
                onTap: () {
                  Navigator.pop(sheet);
                  onSignOut();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _tab == 0
            ? _HomeView(
                key: ValueKey(_refresh),
                repository: widget.repository,
                onSoon: _soon,
              )
            : _CategoryView(
                key: ValueKey(_refresh),
                repository: widget.repository,
                onBack: () => setState(() => _tab = 0),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: t('navSell'),
        shape: const CircleBorder(),
        onPressed: _sell,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => i < 2
            ? setState(() => _tab = i)
            : i == 3
            ? _profile()
            : showComingSoon(context),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t('navHome'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: t('navCategories'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: t('navChat'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: t('navProfile'),
          ),
        ],
      ),
    );
  }
}

/// Listings matching [search], a page at a time: the next page loads when
/// the end of the list scrolls into view, where loading, empty and error
/// (with retry) show too.
class _ListingFeed extends StatefulWidget {
  const _ListingFeed({
    required this.repository,
    required this.search,
    this.searching = false,
  });
  final CatalogRepository repository;
  final CatalogSearch search;

  /// Empty then reads "no match" rather than "no items yet".
  final bool searching;

  @override
  State<_ListingFeed> createState() => _ListingFeedState();
}

class _ListingFeedState extends State<_ListingFeed> {
  final _items = <Listing>[];
  var _more = true;
  var _loading = false;
  var _failed = false;
  // Bumped on a new search, so a late page of the old one is dropped.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_ListingFeed old) {
    super.didUpdateWidget(old);
    if (old.search.text != widget.search.text ||
        !listEquals(old.search.matched, widget.search.matched) ||
        !listEquals(old.search.categories, widget.search.categories)) {
      _generation++;
      _items.clear();
      _more = true;
      _fetch();
    }
  }

  void _fetch() {
    _loading = true;
    _failed = false;
    _page(_generation);
  }

  Future<void> _page(int generation) async {
    try {
      final page = await widget.repository.listings(
        query: widget.search.text,
        matched: widget.search.matched,
        categories: widget.search.categories,
        after: _items.lastOrNull,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _more = page.length == catalogPageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// The last card is built: it nears the viewport, so fetch the next page
  /// after this frame. The grid builds cards lazily, unlike a footer.
  void _nearEnd() {
    if (!_more || _loading || _failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _more && !_loading && !_failed) setState(_fetch);
    });
  }

  /// What shows at the end of the list; null when there is nothing more.
  Widget? _end() {
    if (_failed) {
      return Column(
        children: [
          Text(t('catalogError'), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(_fetch),
            child: Text(t('retry')),
          ),
        ],
      );
    }
    if (_loading) return const CircularProgressIndicator();
    if (_more) return null;
    if (_items.isEmpty) {
      return Text(
        t(widget.searching ? 'searchEmpty' : 'catalogEmpty'),
        textAlign: TextAlign.center,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final end = _end();
    return SliverMainAxisGroup(
      slivers: [
        _ListingGrid(listings: _items, onLast: _nearEnd),
        if (end != null)
          SliverPadding(
            padding: const EdgeInsets.all(32),
            sliver: SliverToBoxAdapter(child: Center(child: end)),
          ),
      ],
    );
  }
}

const _pad = 16.0;

class _HomeView extends StatefulWidget {
  const _HomeView({super.key, required this.repository, required this.onSoon});
  final CatalogRepository repository;
  final VoidCallback onSoon;

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  var _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final search = catalogSearch(_query, _categoryLabels);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, 0),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Image.asset(
                    BeeAssets.mascot,
                    height: 56,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bee',
                                style: TextStyle(color: BeeColors.brandOrange),
                              ),
                              TextSpan(
                                text: 'Kas',
                                style: TextStyle(color: BeeColors.logoKas),
                              ),
                            ],
                          ),
                          style: textTheme.headlineSmall,
                        ),
                        Text(t('tagline'), style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t('favorites'),
                    icon: const Icon(Icons.favorite_border),
                    onPressed: widget.onSoon,
                  ),
                  IconButton(
                    tooltip: t('notifications'),
                    icon: const Icon(Icons.notifications_none),
                    onPressed: widget.onSoon,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  // One server call once typing pauses, not one per key.
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () => setState(() => _query = value),
                  );
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t('searchHint'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              const _Banner(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final group in CategoryGroup.values)
                    Expanded(
                      child: _Shortcut(
                        group: group,
                        onTap: () => _openResults(
                          context,
                          t(group.copyKey),
                          widget.repository,
                          group == CategoryGroup.all ? null : group.categories,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('recommended'),
                      style: textTheme.titleMedium?.copyWith(
                        color: BeeColors.textHeading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        _ListingFeed(
          repository: widget.repository,
          search: search,
          searching: _query.trim().isNotEmpty,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        color: BeeColors.warningSurface,
        borderRadius: BorderRadius.circular(BeeRadius.banner),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('bannerTitle'),
                  style: textTheme.titleLarge?.copyWith(
                    color: BeeColors.textHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(t('bannerBody'), style: textTheme.bodySmall),
              ],
            ),
          ),
          Image.asset(
            BeeAssets.beeWriting,
            height: 96,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.group, required this.onTap});
  final CategoryGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeeRadius.field),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Image.asset(
              BeeAssets.groups[group.name]!,
              width: 56,
              height: 56,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 4),
            Text(
              t(group.copyKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

void _openResults(
  BuildContext context,
  String title,
  CatalogRepository repository,
  List<ListingCategory>? categories,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: BeeHeader(title: Text(title)),
      body: CustomScrollView(
        slivers: [
          _ListingFeed(
            repository: repository,
            search: (text: null, matched: null, categories: categories),
          ),
        ],
      ),
    ),
  ),
);

class _ListingGrid extends StatelessWidget {
  const _ListingGrid({required this.listings, this.onLast});
  final List<Listing> listings;

  /// Called when the last card is built.
  final VoidCallback? onLast;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: _pad),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 250,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: listings.length,
        itemBuilder: (context, i) {
          if (i == listings.length - 1) onLast?.call();
          return _ListingCard(listing: listings[i]);
        },
      ),
    );
  }
}

String _priceLabel(Listing l) =>
    l.isDonation ? t('free') : formatRupiah(l.price);

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ListingDetailScreen(listing: listing),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Photo(listing.photos.firstOrNull),
                  if (listing.isDonation)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Chip(
                        label: Text(t('donation')),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      tooltip: t('addFavorite'),
                      icon: const Icon(Icons.favorite_border),
                      style: IconButton.styleFrom(
                        backgroundColor: BeeColors.surface,
                      ),
                      onPressed: () => showComingSoon(context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: BeeColors.textHeading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _priceLabel(listing),
                    style: textTheme.titleSmall?.copyWith(
                      color: BeeColors.link,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(listing.campus.copyKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A listing photo, or a placeholder when there is none or it fails.
class _Photo extends StatelessWidget {
  const _Photo(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: BeeColors.border,
      child: Center(
        child: Icon(Icons.image_outlined, color: BeeColors.textMuted),
      ),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _CategoryView extends StatefulWidget {
  const _CategoryView({
    super.key,
    required this.repository,
    required this.onBack,
  });
  final CatalogRepository repository;
  final VoidCallback onBack;

  @override
  State<_CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<_CategoryView> {
  var _query = '';
  var _group = CategoryGroup.all;

  // Daftar-12 shows four chips; Perlengkapan is a Beranda shortcut only.
  static const _chips = [
    CategoryGroup.all,
    CategoryGroup.electronics,
    CategoryGroup.fashion,
    CategoryGroup.books,
  ];

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final categories = [
      for (final c in _group.categories)
        if (_categoryLabel(c).toLowerCase().contains(q)) c,
    ];

    return CustomScrollView(
      slivers: [
        SliverList.list(
          children: [
            BeeHeader(
              title: Text(
                t('navCategories'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              onBack: widget.onBack,
            ),
            Padding(
              padding: const EdgeInsets.all(_pad),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: t('searchCategoryHint'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _pad),
              child: Row(
                spacing: 8,
                children: [
                  for (final group in _chips)
                    ChoiceChip(
                      label: Text(t(group.copyKey)),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _pad),
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
            children: [
              for (final c in categories)
                Card.outlined(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openResults(
                      context,
                      _categoryLabel(c),
                      widget.repository,
                      [c],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.asset(
                              BeeAssets.categories[c.code]!,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _categoryLabel(c),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: BeeColors.textBody),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

/// Detail barang (Daftar-14).
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});
  final Listing listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final textTheme = Theme.of(context).textTheme;
    final discount = discountPercent(l.price, l.previousPrice);
    final heading = textTheme.titleMedium?.copyWith(
      color: BeeColors.textHeading,
      fontWeight: FontWeight.w700,
    );
    void soon() => showComingSoon(context);

    return Scaffold(
      appBar: const BeeHeader(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(BeeRadius.banner),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: l.photos.isEmpty
                  ? Semantics(label: t('noPhoto'), child: const _Photo(null))
                  : Stack(
                      children: [
                        PageView(
                          controller: _pages,
                          onPageChanged: (i) => setState(() => _page = i),
                          children: [for (final url in l.photos) _Photo(url)],
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Semantics(
                            label: t('photoCount')
                                .replaceAll('{i}', '${_page + 1}')
                                .replaceAll('{n}', '${l.photos.length}'),
                            child: ExcludeSemantics(
                              child: Chip(
                                label: Text('${_page + 1}/${l.photos.length}'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (l.photos.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (i, url) in l.photos.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        button: true,
                        selected: i == _page,
                        label: t('photoCount')
                            .replaceAll('{i}', '${i + 1}')
                            .replaceAll('{n}', '${l.photos.length}'),
                        child: InkWell(
                          onTap: () => _pages.jumpToPage(i),
                          child: SizedBox(width: 64, child: _Photo(url)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(l.title, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _priceLabel(l),
                style: textTheme.titleLarge?.copyWith(
                  color: BeeColors.link,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (l.isDonation) Chip(label: Text(t('donation'))),
              if (discount != null) ...[
                Text(
                  formatRupiah(l.previousPrice!),
                  style: textTheme.bodyMedium?.copyWith(
                    color: BeeColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Chip(
                  label: Text(
                    '-$discount%',
                    style: const TextStyle(color: BeeColors.error),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: BeeColors.warningSurface,
                child: Icon(Icons.person, color: BeeColors.textHeading),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.sellerName, style: heading),
                    Text(t(l.sellerCampus.copyKey), style: textTheme.bodySmall),
                    if (l.sellerVerified)
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: BeeColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(t('verified'), style: textTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card.outlined(
            margin: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (label, value)) in [
                    ('condition', t(l.condition.copyKey)),
                    ('warranty', l.warranty ?? '-'),
                    ('location', t(l.campus.copyKey)),
                  ].indexed) ...[
                    if (i > 0) const VerticalDivider(width: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t(label), style: textTheme.labelMedium),
                            const SizedBox(height: 8),
                            Text(value, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${t('stock')}: ${t('stockCount').replaceAll('{n}', '${l.stock}')}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(t('description'), style: heading),
          const SizedBox(height: 4),
          Text(l.description, style: textTheme.bodyMedium),
          if (l.specs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('specs'), style: heading),
            const SizedBox(height: 4),
            Text(l.specs.join('  |  '), style: textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_pad, 8, _pad, _pad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: soon,
                      child: Text(t('chatSeller')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: soon,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(t('booking24h')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: soon,
                      child: Text(t('buyNow')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    tooltip: t('addFavorite'),
                    onPressed: soon,
                    icon: const Icon(Icons.favorite_border),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
