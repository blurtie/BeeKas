import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/copy.dart';
import '../data/payment_repository.dart';
import '../data/signup_repository.dart';
import '../domain/access.dart';
import '../domain/catalog.dart';
import '../domain/payment.dart';
import '../domain/signup_error.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// K8 Kuota Listing (#84, no design): the balance, Beli paket and the
/// purchase history with each payment's status (PRD-katalog 5.3).
class QuotaScreen extends StatefulWidget {
  const QuotaScreen({
    super.key,
    required this.repository,
    required this.pickProof,
  });

  final PaymentRepository repository;

  /// A screenshot from the gallery as a JPEG without metadata, or null when
  /// the member backs out.
  final Future<Uint8List?> Function() pickProof;

  @override
  State<QuotaScreen> createState() => _QuotaScreenState();
}

class _QuotaScreenState extends State<QuotaScreen> {
  late Future<QuotaOverview> _overview = widget.repository.overview();

  void _reload() {
    setState(() {
      _overview = widget.repository.overview();
    });
  }

  Future<void> _buy() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _QrisScreen(
          repository: widget.repository,
          pickProof: widget.pickProof,
        ),
      ),
    );
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('qrisSent'))));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: BeeHeader(title: Text(t('quotaTitle'))),
      body: SafeArea(
        child: FutureBuilder(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final overview = snapshot.data;
            if (overview == null) {
              return _Message(
                text: t('sellLoadFailed'),
                action: OutlinedButton(
                  onPressed: _reload,
                  child: Text(t('retry')),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  BeeSpacing.screenX,
                  16,
                  BeeSpacing.screenX,
                  24,
                ),
                children: [
                  Text(
                    t('quotaLeft').replaceAll('{n}', '${overview.quota}'),
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _buy,
                    child: Text(
                      t('quotaBuy').replaceAll(
                        '{price}',
                        formatRupiah(PaymentKind.package.amount),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(t('quotaHistory'), style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (overview.payments.isEmpty)
                    Text(t('quotaHistoryEmpty'), style: textTheme.bodyMedium)
                  else
                    for (final p in overview.payments)
                      _PaymentTile(payment: p, onReupload: _buy),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onReupload});

  final Payment payment;
  final VoidCallback onReupload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = payment;
    final rejected = p.status == PaymentStatus.rejected;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('paymentKind_${p.kind.name}')} · ${formatRupiah(p.amount)}',
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              MaterialLocalizations.of(context)
                  .formatMediumDate(p.createdAt.toLocal()),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              t('paymentStatus_${p.status.name}'),
              style: textTheme.bodyMedium?.copyWith(
                color: rejected ? BeeColors.error : null,
              ),
            ),
            if (rejected) ...[
              if (p.reason != null)
                Text(
                  t('paymentReason').replaceAll('{reason}', p.reason!),
                  style: textTheme.bodyMedium,
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onReupload,
                child: Text(t('paymentReupload')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Beli paket: the QRIS from public storage (K-09), the price, then the
/// proof. Pops true once the payment is recorded.
class _QrisScreen extends StatefulWidget {
  const _QrisScreen({required this.repository, required this.pickProof});

  final PaymentRepository repository;
  final Future<Uint8List?> Function() pickProof;

  @override
  State<_QrisScreen> createState() => _QrisScreenState();
}

class _QrisScreenState extends State<_QrisScreen> {
  var _sending = false;
  String? _error;

  Future<void> _upload() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final proof = await widget.pickProof();
      if (proof == null) return;
      await submitPayment(widget.repository, PaymentKind.package, proof);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // D-43 says why; anything else is a failed upload, a refused payment
      // or an unreadable picture.
      final pending =
          e is SignupException && e.error == SignupError.paymentPending;
      if (mounted) {
        setState(
          () => _error = t(pending ? 'errorPaymentPending' : 'qrisFailed'),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: BeeHeader(title: Text(t('qrisTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(BeeRadius.field),
              child: Image(
                image: widget.repository.qris,
                fit: BoxFit.contain,
                semanticLabel: t('qrisTitle'),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const AspectRatio(
                        aspectRatio: 1,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (context, _, _) => AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: Text(
                      t('qrisMissing'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t('qrisAmount'), style: textTheme.labelMedium),
            Text(
              formatRupiah(PaymentKind.package.amount),
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(t('qrisSteps'), style: textTheme.bodyMedium),
            if (_error != null) ...[
              const SizedBox(height: 16),
              BeeFormError(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _sending ? null : _upload,
              child: BeeButtonLabel(t('qrisUpload'), loading: _sending),
            ),
          ],
        ),
      ),
    );
  }
}

/// K18 Admin: Pembayaran (#84, no design). Waiting payments, longest
/// waiting first, flagged after 24 hours (D-29).
class PaymentListScreen extends StatefulWidget {
  const PaymentListScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  final PaymentRepository repository;
  final DateTime Function() now;

  @override
  State<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends State<PaymentListScreen> {
  late Future<List<PendingPayment>> _pending = widget.repository.pending();

  void _reload() {
    setState(() {
      _pending = widget.repository.pending();
    });
  }

  Future<void> _open(PendingPayment payment) async {
    final outcome = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _PaymentDetailScreen(
          repository: widget.repository,
          payment: payment,
        ),
      ),
    );
    if (!mounted) return;
    if (outcome != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(outcome).replaceAll('{name}', payment.memberName)),
        ),
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: BeeHeader(title: Text(t('paymentsAdminTitle'))),
      body: SafeArea(
        child: FutureBuilder(
          future: _pending,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final payments = snapshot.data;
            if (payments == null) {
              final error = snapshot.error;
              return _Message(
                text: [
                  t('paymentsLoadFailed'),
                  if (error is SignupException)
                    t(error.error?.copyKey ?? 'errorNetwork'),
                ].join('\n'),
                action: OutlinedButton(
                  onPressed: _reload,
                  child: Text(t('retry')),
                ),
              );
            }
            if (payments.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  children: [
                    const SizedBox(height: 120),
                    _Message(text: t('paymentsEmpty')),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: payments.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = payments[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: BeeSpacing.screenX / 2,
                      vertical: 4,
                    ),
                    title: Text(p.memberName),
                    subtitle: Text(
                      '${t('paymentKind_${p.kind.name}')} · '
                      '${formatRupiah(p.amount)} · '
                      '${_waiting(widget.now(), p.createdAt)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOverdue(p.createdAt, widget.now()))
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
                    onTap: () => _open(p),
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

String _waiting(DateTime now, DateTime since) {
  final wait = now.difference(since);
  final time = wait.inHours >= 1
      ? t('reviewHours').replaceFirst('{n}', '${wait.inHours}')
      : t('reviewMinutes').replaceFirst('{n}', '${wait.inMinutes}');
  return t('reviewWaiting').replaceFirst('{time}', time);
}

/// K18 detail: the proof, the member, the amount due; Konfirmasi with the
/// amount received, or Tolak with a reason. Pops the outcome's copy key.
class _PaymentDetailScreen extends StatefulWidget {
  const _PaymentDetailScreen({required this.repository, required this.payment});

  final PaymentRepository repository;
  final PendingPayment payment;

  @override
  State<_PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<_PaymentDetailScreen> {
  // In memory only, like verification photos.
  late final _proof = widget.repository.proof(widget.payment.proofPath);
  final _received = TextEditingController();
  var _receivedInvalid = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = receivedAmount(_received.text);
    setState(() => _receivedInvalid = amount == null);
    if (amount == null) return;
    await _decide(
      () => widget.repository.confirm(widget.payment.id, amount),
      'paymentConfirmed',
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectPaymentDialog(name: widget.payment.memberName),
    );
    if (reason == null || !mounted) return;
    await _decide(
      () => widget.repository.reject(widget.payment.id, reason),
      'paymentRejected',
    );
  }

  Future<void> _decide(Future<void> Function() call, String outcome) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      if (mounted) Navigator.pop(context, outcome);
    } on SignupException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.error == SignupError.notPending
            ? 'paymentNotPending'
            : e.error?.copyKey ?? 'errorNetwork',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final textTheme = Theme.of(context).textTheme;
    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );

    return Scaffold(
      appBar: BeeHeader(title: Text(t('paymentDetailTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            Text(t('paymentProof'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: BeeColors.border),
                  borderRadius: BorderRadius.circular(BeeRadius.field),
                ),
                child: FutureBuilder(
                  future: _proof,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return Center(
                        child: Text(
                          t('paymentProofFailed'),
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        ),
                      );
                    }
                    return InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(data, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ),
            field(t('paymentMember'), p.memberName),
            field(t('emailBinus'), p.memberEmail),
            field(t('paymentKind'), t('paymentKind_${p.kind.name}')),
            field(t('paymentExpected'), formatRupiah(p.amount)),
            const SizedBox(height: 24),
            BeeTextField(
              label: t('paymentReceived'),
              controller: _received,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              errorText: _receivedInvalid ? t('paymentReceivedInvalid') : null,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              BeeFormError(t(_error!)),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: BeeButtonLabel(t('paymentConfirm'), loading: _busy),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _reject,
              child: Text(t('reject')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tolak needs a reason the member will read (rule 5). Pops it, or null on
/// Batal.
class _RejectPaymentDialog extends StatefulWidget {
  const _RejectPaymentDialog({required this.name});

  final String name;

  @override
  State<_RejectPaymentDialog> createState() => _RejectPaymentDialogState();
}

class _RejectPaymentDialogState extends State<_RejectPaymentDialog> {
  final _reason = TextEditingController();
  var _tried = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (isValidPaymentRejection(_reason.text)) {
      Navigator.pop(context, _reason.text.trim());
    } else {
      setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('paymentRejectTitle').replaceAll('{name}', widget.name)),
      scrollable: true,
      content: BeeTextField(
        label: t('paymentRejectReason'),
        controller: _reason,
        maxLines: null,
        errorText: _tried && !isValidPaymentRejection(_reason.text)
            ? t('paymentReasonRequired')
            : null,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        TextButton(onPressed: _submit, child: Text(t('reject'))),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
      ),
    );
  }
}
