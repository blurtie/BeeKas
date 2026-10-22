import 'dart:async';

import 'package:beekas/data/chat_repository.dart';

/// Chat in memory. The streams are controllers the test pushes into, as
/// Realtime would; [errors] holds one failure per method name.
class FakeChatRepository implements ChatRepository {
  final overviews = StreamController<ChatOverview>.broadcast();
  final rooms = <String, StreamController<List<ChatMessage>>>{};
  final sent = <({String body, String? conversationId, String? listingId})>[];
  final posted = <String>[];
  final existing = <String, String>{};
  var announcementList = <Announcement>[];
  final errors = <String, Object>{};

  void _fail(String method) {
    final error = errors.remove(method);
    if (error != null) throw error;
  }

  StreamController<List<ChatMessage>> room(String id) =>
      rooms.putIfAbsent(id, StreamController.broadcast);

  @override
  Stream<ChatOverview> overview() => overviews.stream;

  @override
  Future<String?> conversationFor(String listingId) async {
    _fail('conversationFor');
    return existing[listingId];
  }

  /// Order id to conversation id.
  final byOrder = <String, String>{};

  @override
  Future<String?> conversationForOrder(String orderId) async {
    _fail('conversationForOrder');
    return byOrder[orderId];
  }

  @override
  Stream<List<ChatMessage>> messages(String conversationId) =>
      room(conversationId).stream;

  @override
  Future<String> send(
    String body, {
    String? conversationId,
    String? listingId,
  }) async {
    _fail('send');
    sent.add((
      body: body,
      conversationId: conversationId,
      listingId: listingId,
    ));
    return conversationId ?? 'new';
  }

  @override
  Future<List<Announcement>> announcements() async {
    _fail('announcements');
    return announcementList;
  }

  @override
  Future<void> postAnnouncement(String body) async {
    _fail('postAnnouncement');
    posted.add(body);
  }
}
