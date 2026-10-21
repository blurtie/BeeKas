import 'package:flutter/material.dart';

import '../config/copy.dart';
import '../data/chat_repository.dart';
import '../data/signup_repository.dart';
import '../domain/catalog.dart';
import '../domain/chat.dart';
import '../domain/signup_error.dart';
import '../ui/tokens.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 14.32 today, Kemarin yesterday, else the date (daftar-9).
String chatTimeLabel(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  return switch (today.difference(day).inDays) {
    0 => '${_two(at.hour)}.${_two(at.minute)}',
    1 => t('chatYesterday'),
    _ => '${at.day}/${at.month}/${at.year}',
  };
}

String _errorText(String lead, Object? error) => [
  t(lead),
  // unknown's text is about sign-up, so it adds nothing here.
  if (error is SignupException && error.error != SignupError.unknown)
    t(error.error?.copyKey ?? 'errorNetwork'),
].join('\n');

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

const _avatar = CircleAvatar(
  radius: 28,
  backgroundColor: BeeColors.warningSurface,
  child: Icon(Icons.person, color: BeeColors.textHeading),
);

/// K14 Daftar Chat (daftar-9): Semua / Penjual, live, with Admin BeeKas last.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  final ChatRepository repository;
  final DateTime Function() now;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late var _overview = widget.repository.overview();
  var _filter = ChatFilter.all;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row({
      required String name,
      String? body,
      DateTime? at,
      required VoidCallback onTap,
    }) => Card.outlined(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _avatar,
        title: Text(
          name,
          style: textTheme.titleMedium?.copyWith(
            color: BeeColors.textHeading,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: body == null
            ? null
            : Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: at == null
            ? null
            : Text(chatTimeLabel(at, widget.now()), style: textTheme.bodySmall),
        onTap: onTap,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t('chatTitle')), centerTitle: true),
      body: SafeArea(
        child: StreamBuilder(
          stream: _overview,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                text: _errorText('chatLoadFailed', snapshot.error),
                action: OutlinedButton(
                  onPressed: () =>
                      setState(() => _overview = widget.repository.overview()),
                  child: Text(t('retry')),
                ),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final shown = [
              for (final c in data.conversations)
                if (_filter.shows(iAmBuyer: c.iAmBuyer)) c,
            ];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    for (final f in ChatFilter.values) ...[
                      if (f != ChatFilter.all) const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              t(
                                f == ChatFilter.all ? 'chatAll' : 'chatSellers',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: _filter == f,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: _Message(text: t('chatEmpty')),
                  ),
                for (final c in shown)
                  row(
                    name: c.otherName,
                    body: c.lastBody,
                    at: c.lastAt,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ChatRoomScreen(
                          repository: widget.repository,
                          title: c.otherName,
                          conversationId: c.id,
                          item: c.item,
                        ),
                      ),
                    ),
                  ),
                row(
                  name: t('adminBeeKas'),
                  body: data.announcement?.body ?? t('announcementsEmpty'),
                  at: data.announcement?.createdAt,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AnnouncementsScreen(
                        repository: widget.repository,
                        now: widget.now,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Admin BeeKas: one-way, so no reply field (D-31). Belum ada desain.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.repository,
    this.now = DateTime.now,
  });

  final ChatRepository repository;
  final DateTime Function() now;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late var _items = widget.repository.announcements();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('adminBeeKas')), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data;
            if (items == null) {
              return _Message(
                text: _errorText('messagesLoadFailed', snapshot.error),
                action: OutlinedButton(
                  onPressed: () => setState(
                    () => _items = widget.repository.announcements(),
                  ),
                  child: Text(t('retry')),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: items.isEmpty
                      ? _Message(text: t('announcementsEmpty'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final a in items.reversed)
                              _Bubble(
                                body: a.body,
                                time: chatTimeLabel(a.createdAt, widget.now()),
                                mine: false,
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t('announcementsReadOnly'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.body, required this.time, required this.mine});

  final String body;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SelectableText(body, style: theme.textTheme.bodyMedium),
                Text(time, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// K15 Ruang Chat: item card on top, messages live, contact warning before
/// sending (K-20). Belum ada desain. Without [conversationId], the chat with
/// [listingId]'s seller is looked up, or started by the first message.
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.repository,
    required this.title,
    this.conversationId,
    this.listingId,
    this.item,
    this.now = DateTime.now,
  });

  final ChatRepository repository;
  final String title;
  final String? conversationId;
  final String? listingId;
  final ChatItem? item;
  final DateTime Function() now;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _text = TextEditingController();
  late String? _id = widget.conversationId;
  Stream<List<ChatMessage>>? _messages;
  // Looking up the conversation for listingId; or the lookup's error.
  var _finding = false;
  Object? _findError;
  String? _error;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final listing = widget.listingId;
    if (_id == null && listing != null) {
      setState(() {
        _finding = true;
        _findError = null;
      });
      try {
        _id = await widget.repository.conversationFor(listing);
      } on Object catch (e) {
        _findError = e;
      }
      if (!mounted) return;
      _finding = false;
    }
    setState(() {
      final id = _id;
      _messages = id == null ? null : widget.repository.messages(id);
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    final invalid = validateMessage(body);
    if (invalid != null) {
      return setState(
        () => _error = t(
          invalid == MessageError.empty
              ? 'errorMessageEmpty'
              : 'errorMessageTooLong',
        ),
      );
    }
    if (looksLikeContact(body) && await _confirmContact() != true) return;
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      final id = await widget.repository.send(
        body,
        conversationId: _id,
        listingId: widget.listingId,
      );
      if (!mounted) return;
      _text.clear();
      if (_id == null) {
        _id = id;
        _messages = widget.repository.messages(id);
      }
    } on Object catch (e) {
      _error = _errorText('chatSendFailed', e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool?> _confirmContact() => showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(t('contactWarningTitle')),
      content: Text(t('contactWarningBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(t('contactSendAnyway')),
        ),
      ],
    ),
  );

  Widget _body() {
    final retry = OutlinedButton(onPressed: _open, child: Text(t('retry')));
    if (_finding) return const Center(child: CircularProgressIndicator());
    if (_findError != null) {
      return _Message(
        text: _errorText('messagesLoadFailed', _findError),
        action: retry,
      );
    }
    final stream = _messages;
    if (stream == null) return _Message(text: t('chatRoomEmpty'));
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            text: _errorText('messagesLoadFailed', snapshot.error),
            action: retry,
          );
        }
        final messages = snapshot.data;
        if (messages == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (messages.isEmpty) return _Message(text: t('chatRoomEmpty'));
        return ListView(
          reverse: true,
          padding: const EdgeInsets.all(16),
          children: [
            for (final m in messages.reversed)
              _Bubble(
                body: m.body,
                time: chatTimeLabel(m.createdAt, widget.now()),
                mine: m.mine,
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            if (item != null)
              Card.outlined(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: SizedBox.square(
                    dimension: 48,
                    child: item.photo == null
                        ? const Icon(Icons.image_outlined)
                        : Image.network(
                            item.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined),
                          ),
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    item.isDonation ? t('free') : formatRupiah(item.price),
                    style: const TextStyle(color: BeeColors.link),
                  ),
                ),
              ),
            Expanded(child: _body()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: t('chatHint'),
                        errorText: _error,
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t('chatSend'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
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

/// K21 Pengumuman, admins only: write, preview, send. Belum ada desain.
class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key, required this.repository});

  final ChatRepository repository;

  @override
  State<PostAnnouncementScreen> createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  final _text = TextEditingController();
  String? _error;
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final body = _text.text.trim();
    final invalid = validateMessage(body);
    if (invalid != null) {
      return setState(
        () => _error = t(
          invalid == MessageError.empty
              ? 'announcementRequired'
              : 'errorMessageTooLong',
        ),
      );
    }
    setState(() => _error = null);
    final send = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t('adminBeeKas')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 16),
              Text(
                t('announcementSendNote'),
                style: Theme.of(dialog).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t('announcementSend')),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.repository.postAnnouncement(body);
      if (!mounted) return;
      _text.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('announcementSent'))));
    } on Object catch (e) {
      _error = _errorText('announcementFailed', e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('announcementsAdminTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: t('announcementHint'),
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _preview,
              child: Text(t('announcementPreview')),
            ),
          ],
        ),
      ),
    );
  }
}
