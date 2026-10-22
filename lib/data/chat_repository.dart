import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_repository.dart';

/// The item card on top of K15 (5.8).
typedef ChatItem = ({String title, int price, bool isDonation, String? photo});

/// A row of K14. The other member's name only, never their phone (D-26).
typedef Conversation = ({
  String id,
  String otherName,
  bool iAmBuyer,
  String? lastBody,
  DateTime? lastAt,
  String? listingId,
  ChatItem? item,
});

typedef ChatMessage = ({String id, bool mine, String body, DateTime createdAt});

/// One Admin BeeKas message (K21).
typedef Announcement = ({String body, DateTime createdAt});

/// K14: my conversations and the latest Admin BeeKas message.
typedef ChatOverview = ({
  List<Conversation> conversations,
  Announcement? announcement,
});

/// Text chat (#86). Streams emit the whole list again on every new message
/// (Supabase Realtime, filtered by RLS). Failures are [SignupException]s.
abstract interface class ChatRepository {
  Stream<ChatOverview> overview();

  /// The caller's conversation as buyer with this listing's seller, if any.
  Future<String?> conversationFor(String listingId);

  /// The conversation between this order's buyer and seller, if any; for
  /// either party.
  Future<String?> conversationForOrder(String orderId);

  /// Oldest first.
  Stream<List<ChatMessage>> messages(String conversationId);

  /// Sends into [conversationId], or starts one from [listingId]; returns
  /// the conversation. [listingId] also moves the item card.
  Future<String> send(String body, {String? conversationId, String? listingId});

  /// Newest first.
  Future<List<Announcement>> announcements();

  /// K21, admins only.
  Future<void> postAnnouncement(String body);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);
  final SupabaseClient _client;

  /// Loads once, then again on every new message or announcement Realtime
  /// lets through RLS. Only the newest load reaches the screen.
  @override
  Stream<ChatOverview> overview() {
    late final StreamController<ChatOverview> out;
    RealtimeChannel? channel;
    var latest = 0;
    Future<void> load() async {
      final run = ++latest;
      try {
        final overview = await guardBackend(_overview);
        if (run == latest && !out.isClosed) out.add(overview);
      } on Object catch (e) {
        if (run == latest && !out.isClosed) out.addError(e);
      }
    }

    out = StreamController(
      onListen: () {
        void reload(PostgresChangePayload _) => load();
        channel = _client
            .channel('chat-overview-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: reload,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'announcements',
              callback: reload,
            )
            .subscribe();
        load();
      },
      onCancel: () async {
        final c = channel;
        if (c != null) await _client.removeChannel(c);
        await out.close();
      },
    );
    return out.stream;
  }

  Future<ChatOverview> _overview() async {
    final (rows, latest) = await (
      _client.rpc<List<dynamic>>('my_conversations'),
      announcements(),
    ).wait;
    final photos = _client.storage.from('listing-photos');
    return (
      conversations: [
        for (final row in rows.cast<Map<String, dynamic>>())
          (
            id: row['id'] as String,
            otherName: row['other_name'] as String,
            iAmBuyer: row['i_am_buyer'] as bool,
            lastBody: row['last_body'] as String?,
            lastAt: _time(row['last_at']),
            listingId: row['listing_id'] as String?,
            item: row['listing_id'] == null
                ? null
                : (
                    title: row['listing_title'] as String,
                    price: row['listing_price'] as int,
                    isDonation: row['listing_donation'] as bool,
                    photo: switch (row['listing_photo']) {
                      final String path => photos.getPublicUrl(path),
                      _ => null,
                    },
                  ),
          ),
      ],
      announcement: latest.firstOrNull,
    );
  }

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  @override
  Future<String?> conversationFor(String listingId) => guardBackend(
    () => _client.rpc<String?>(
      'conversation_for_listing',
      params: {'p_listing': listingId},
    ),
  );

  @override
  Future<String?> conversationForOrder(String orderId) => guardBackend(
    () => _client.rpc<String?>(
      'conversation_for_order',
      params: {'p_order': orderId},
    ),
  );

  @override
  Stream<List<ChatMessage>> messages(String conversationId) {
    final me = _client.auth.currentUser!.id;
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map(
          (rows) => [
            for (final row in rows)
              (
                id: row['id'] as String,
                mine: row['sender_id'] == me,
                body: row['body'] as String,
                createdAt: _time(row['created_at'])!,
              ),
          ],
        );
  }

  @override
  Future<String> send(
    String body, {
    String? conversationId,
    String? listingId,
  }) => guardBackend(
    () => _client.rpc<String>(
      'send_message',
      params: {
        'p_body': body.trim(),
        'p_conversation': conversationId,
        'p_listing': listingId,
      },
    ),
  );

  @override
  Future<List<Announcement>> announcements() => guardBackend(() async {
    final rows = await _client
        .from('announcements')
        .select('body, created_at')
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        (body: row['body'] as String, createdAt: _time(row['created_at'])!),
    ];
  });

  @override
  Future<void> postAnnouncement(String body) => guardBackend(
    () =>
        _client.rpc<void>('post_announcement', params: {'p_body': body.trim()}),
  );
}
