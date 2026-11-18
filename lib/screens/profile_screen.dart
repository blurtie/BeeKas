import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/chat_repository.dart';
import '../data/order_repository.dart';
import '../domain/access.dart';
import '../domain/campus_area.dart';
import '../domain/order.dart';
import '../domain/registration.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'catalog_screens.dart' show showComingSoon;
import 'order_screens.dart';

const _pad = 16.0;

/// K17 Profil, versi Festival (PRD-katalog 5.10, daftar-6): name, campus and
/// Verified BINUS; Pesanan Saya (Semua, Diproses, Selesai); Barang Saya,
/// Kuota & Token, Bantuan, Bahasa, Keluar. No @username, followers, BINUSIAN
/// badge, Edit Profil, Alamat Saya or Metode Pembayaran (D-32, K-28).
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.fullName,
    required this.status,
    this.campus,
    this.orders,
    this.chats,
    this.now = DateTime.now,
    this.onMyListings,
    this.onQuota,
    this.onHelp,
    this.onSignOut,
  });

  final String? fullName;
  final AccountStatus? status;
  final Campus? campus;
  final OrderRepository? orders;
  final ChatRepository? chats;
  final DateTime Function() now;
  final VoidCallback? onMyListings;
  final VoidCallback? onQuota;
  final VoidCallback? onHelp;
  final VoidCallback? onSignOut;

  void _openOrders(BuildContext context, OrderStatus? filter) {
    final repo = orders;
    if (repo == null) return showComingSoon(context);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrdersScreen(
          repository: repo,
          now: now,
          chats: chats,
          initialFilter: filter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final c = campus;
    return ListView(
      padding: const EdgeInsets.all(_pad),
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: BeeColors.warningSurface,
              child: Icon(
                Icons.person,
                size: 40,
                color: BeeColors.textHeading,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName ?? '-',
                    style: textTheme.titleLarge?.copyWith(
                      color: BeeColors.textHeading,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (c != null)
                    Text(
                      '${t(c.copyKey)} · ${c.tag}',
                      style: textTheme.bodySmall,
                    ),
                  if (status == AccountStatus.approved) ...[
                    const SizedBox(height: 4),
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
                ],
              ),
            ),
          ],
        ),
        if (c != null) ...[
          const SizedBox(height: 12),
          Text(
            c.area == null
                ? t('profileAreaAll')
                : t('profileArea').replaceAll(
                    '{area}',
                    t('area_${c.area!.name}'),
                  ),
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        Card.outlined(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(_pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('ordersTitle'),
                  style: textTheme.titleMedium?.copyWith(
                    color: BeeColors.textHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (i, (filter, icon)) in [
                      (null, Icons.description_outlined),
                      (OrderStatus.processing, Icons.forum_outlined),
                      (OrderStatus.completed, Icons.task_alt),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _openOrders(context, filter),
                          child: Column(
                            children: [
                              Icon(icon, color: BeeColors.link),
                              const SizedBox(height: 4),
                              Text(
                                t('profileOrders_${filter?.name ?? 'all'}'),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (onMyListings case final open?)
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: Text(t('profileMyListings')),
            trailing: const Icon(Icons.chevron_right),
            onTap: open,
          ),
        if (onQuota case final open?)
          ListTile(
            leading: const Icon(Icons.toll_outlined),
            title: Text(t('profileQuota')),
            trailing: const Icon(Icons.chevron_right),
            onTap: open,
          ),
        if (onHelp case final open?)
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(t('profileHelp')),
            trailing: const Icon(Icons.chevron_right),
            onTap: open,
          ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(t('profileLanguage')),
          trailing: const BeeLanguageToggle(),
        ),
        if (onSignOut case final out?)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t('signOut')),
            onTap: out,
          ),
      ],
    );
  }
}
