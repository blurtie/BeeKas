import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/review_repository.dart';
import '../data/signup_repository.dart';
import '../domain/access.dart';
import '../ui/tokens.dart';
import 'review_detail_screen.dart';

/// L14 Admin: daftar pendaftar (no design). Pending accounts, longest waiting
/// first, flagged after 24 hours.
class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.onPayments,
    this.onAnnouncements,
    this.now = DateTime.now,
  });

  final ReviewRepository repository;
  final VoidCallback onSignOut;

  /// K18 Pembayaran (#84). This is the admin home, so only admins see it.
  final VoidCallback? onPayments;

  /// K21 Pengumuman Admin BeeKas (#86).
  final VoidCallback? onAnnouncements;
  final DateTime Function() now;

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  late Future<List<PendingAccount>> _pending = widget.repository.pending();

  void _reload() {
    setState(() {
      _pending = widget.repository.pending();
    });
  }

  Future<void> _open(PendingAccount account) async {
    final outcome = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReviewDetailScreen(repository: widget.repository, account: account),
      ),
    );
    if (!mounted) return;
    if (outcome != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(outcome).replaceFirst('{name}', account.fullName)),
        ),
      );
    }
    _reload();
  }

  String _waiting(DateTime submittedAt) {
    final wait = widget.now().difference(submittedAt);
    final time = wait.inHours >= 1
        ? t('reviewHours').replaceFirst('{n}', '${wait.inHours}')
        : t('reviewMinutes').replaceFirst('{n}', '${wait.inMinutes}');
    return t('reviewWaiting').replaceFirst('{time}', time);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('reviewTitle')),
        actions: [
          if (widget.onPayments != null)
            TextButton(
              onPressed: widget.onPayments,
              child: Text(t('paymentsAdminTitle')),
            ),
          if (widget.onAnnouncements != null)
            TextButton(
              onPressed: widget.onAnnouncements,
              child: Text(t('announcementsAdminTitle')),
            ),
          IconButton(
            tooltip: t('signOut'),
            icon: const Icon(Icons.logout),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: _pending,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final accounts = snapshot.data;
            if (accounts == null) {
              final error = snapshot.error;
              return Center(
                child: _Message(
                  text: [
                    t('reviewLoadFailed'),
                    if (error is SignupException)
                      t(error.error?.copyKey ?? 'errorNetwork'),
                  ].join('\n'),
                  action: OutlinedButton(
                    onPressed: _reload,
                    child: Text(t('retry')),
                  ),
                ),
              );
            }
            if (accounts.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  children: [
                    const SizedBox(height: 120),
                    _Message(text: t('reviewEmpty')),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final account = accounts[i];
                  final overdue = isOverdue(account.submittedAt, widget.now());
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: BeeSpacing.screenX / 2,
                      vertical: 4,
                    ),
                    title: Text(account.fullName),
                    subtitle: Text(
                      '${t('accountType_${account.accountType.name}')} · '
                      '${_waiting(account.submittedAt)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (overdue)
                          Chip(
                            avatar: const Icon(
                              Icons.schedule,
                              size: 18,
                              color: BeeColors.error,
                            ),
                            label: Text(
                              t('reviewOverdue'),
                              style: textTheme.labelSmall?.copyWith(
                                color: BeeColors.error,
                              ),
                            ),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _open(account),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BeeSpacing.screenX),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
