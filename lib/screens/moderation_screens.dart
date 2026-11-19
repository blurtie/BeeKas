import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/moderation_repository.dart';
import '../data/signup_repository.dart';
import '../domain/moderation.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// K16 Lapor (#87, belum ada desain): a reason (K-22) and a note, required
/// for Lainnya. Shows "Laporan terkirim" once [submit] succeeds.
Future<void> showReportSheet(
  BuildContext context, {
  required String title,
  required Future<void> Function(ReportReason reason, String note) submit,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportSheet(title: title, submit: submit),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('reportSent'))));
  }
}

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.title, required this.submit});

  final String title;
  final Future<void> Function(ReportReason reason, String note) submit;

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _note = TextEditingController();
  ReportReason? _reason;
  var _tried = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _tried = true);
    if (!isValidReport(_reason, _note.text)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_reason!, _note.text);
      if (mounted) Navigator.pop(context, true);
    } on SignupException catch (e) {
      if (mounted) setState(() => _error = e.error?.copyKey ?? 'errorNetwork');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final other = _reason == ReportReason.other;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BeeSpacing.screenX,
        0,
        BeeSpacing.screenX,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(t('reportReasonLabel'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ReportReason.values)
                  ChoiceChip(
                    label: Text(t(r.copyKey)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            if (_tried && _reason == null) ...[
              const SizedBox(height: 8),
              BeeFormError(t('reportReasonRequired')),
            ],
            const SizedBox(height: 16),
            BeeTextField(
              label: other ? t('reportReason_other') : t('reportNote'),
              controller: _note,
              maxLines: null,
              errorText: _tried && other && _note.text.trim().isEmpty
                  ? t('reportNoteRequired')
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              BeeFormError(t(_error!)),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _busy ? null : _send,
              child: BeeButtonLabel(t('reportSend'), loading: _busy),
            ),
          ],
        ),
      ),
    );
  }
}

/// K19 Admin: Laporan (#87, belum ada desain). Open reports, one row per
/// object, oldest first.
class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key, required this.repository});

  final ModerationRepository repository;

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  late Future<List<ReportGroup>> _reports = widget.repository.openReports();

  void _reload() {
    setState(() {
      _reports = widget.repository.openReports();
    });
  }

  Future<void> _open(ReportGroup group) async {
    final outcome = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ReportDetailScreen(repository: widget.repository, group: group),
      ),
    );
    if (!mounted) return;
    if (outcome != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t(outcome))));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BeeHeader(title: Text(t('reportsAdminTitle'))),
      body: SafeArea(
        child: FutureBuilder(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final reports = snapshot.data;
            if (reports == null) {
              final error = snapshot.error;
              return _Message(
                text: [
                  t('reportsLoadFailed'),
                  if (error is SignupException)
                    t(error.error?.copyKey ?? 'errorNetwork'),
                ].join('\n'),
                action: OutlinedButton(
                  onPressed: _reload,
                  child: Text(t('retry')),
                ),
              );
            }
            if (reports.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  children: [
                    const SizedBox(height: 120),
                    _Message(text: t('reportsEmpty')),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: reports.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = reports[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: BeeSpacing.screenX / 2,
                      vertical: 4,
                    ),
                    title: Text(r.listingTitle ?? r.memberName ?? ''),
                    subtitle: Text(
                      '${t(r.listingId != null ? 'reportKindListing' : 'reportKindMember')} · '
                      '${t('reportReporters').replaceAll('{n}', '${r.reporters}')} · '
                      '${t(r.reasons.first.copyKey)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(r),
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

/// K19 detail: the reasons and notes; Turunkan listing (reason required) for
/// a listing, Abaikan for either. Pops the outcome's copy key.
class _ReportDetailScreen extends StatefulWidget {
  const _ReportDetailScreen({required this.repository, required this.group});

  final ModerationRepository repository;
  final ReportGroup group;

  @override
  State<_ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<_ReportDetailScreen> {
  var _busy = false;
  String? _error;

  Future<void> _remove() async {
    final g = widget.group;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RemoveDialog(title: g.listingTitle ?? ''),
    );
    if (reason == null || !mounted) return;
    await _decide(
      () => widget.repository.removeListing(g.listingId!, reason),
      'reportRemoved',
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
      if (mounted) setState(() => _error = e.error?.copyKey ?? 'errorNetwork');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final textTheme = Theme.of(context).textTheme;
    final local = MaterialLocalizations.of(context);
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
      appBar: BeeHeader(title: Text(t('reportDetailTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BeeSpacing.screenX,
            16,
            BeeSpacing.screenX,
            24,
          ),
          children: [
            field(
              t(g.listingId != null ? 'reportKindListing' : 'reportKindMember'),
              g.listingTitle ?? g.memberName ?? '',
            ),
            field(
              t('reportReasons'),
              [for (final r in g.reasons.toSet()) t(r.copyKey)].join(', '),
            ),
            if (g.notes.isNotEmpty)
              field(t('reportNotes'), g.notes.map((n) => '• $n').join('\n')),
            field(
              t('reportFirstAt'),
              '${local.formatShortDate(g.firstAt)} '
              '${local.formatTimeOfDay(TimeOfDay.fromDateTime(g.firstAt))} · '
              '${t('reportReporters').replaceAll('{n}', '${g.reporters}')}',
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              BeeFormError(t(_error!)),
              const SizedBox(height: 16),
            ],
            if (g.listingId != null) ...[
              FilledButton(
                onPressed: _busy ? null : _remove,
                child: BeeButtonLabel(t('reportRemove'), loading: _busy),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _decide(
                      () => widget.repository.dismiss(g.reportId),
                      'reportDismissed',
                    ),
              child: Text(t('reportDismiss')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pops the reason, or null on Batal.
class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.title});

  final String title;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _reason = TextEditingController();
  var _tried = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (isValidRemoval(_reason.text)) {
      Navigator.pop(context, _reason.text.trim());
    } else {
      setState(() => _tried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('reportRemoveTitle').replaceAll('{title}', widget.title)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('reportRemoveBody')),
          const SizedBox(height: 16),
          BeeTextField(
            label: t('reportRemoveReason'),
            controller: _reason,
            maxLines: null,
            errorText: _tried && !isValidRemoval(_reason.text)
                ? t('reportRemoveReasonRequired')
                : null,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        TextButton(onPressed: _submit, child: Text(t('reportRemove'))),
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
