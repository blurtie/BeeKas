import 'package:beekas/data/chat_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/chat_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chat_repository.dart';

final _now = DateTime(2026, 10, 21, 15);

Conversation _conv(
  String id,
  String name, {
  required bool iAmBuyer,
  String? last,
}) => (
  id: id,
  otherName: name,
  iAmBuyer: iAmBuyer,
  lastBody: last,
  lastAt: DateTime(2026, 10, 21, 14, 32),
  listingId: 'l-$id',
  item: (title: 'Kalkulator', price: 50000, isDonation: false, photo: null),
);

ChatMessage _msg(String id, String body, {bool mine = false}) =>
    (id: id, mine: mine, body: body, createdAt: _now);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

void main() {
  group('K14 Daftar Chat', () {
    testWidgets('loads, then lists chats live; Penjual shows where I buy', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      await _pump(tester, ChatListScreen(repository: repo, now: () => _now));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.overviews.add((
        conversations: [
          _conv('1', 'Najwa', iAmBuyer: true, last: 'Bisa nego?'),
          _conv('2', 'Evan', iAmBuyer: false, last: 'Masih ada?'),
        ],
        announcement: null,
      ));
      await tester.pump();
      expect(find.text('Najwa'), findsOneWidget);
      expect(find.text('Evan'), findsOneWidget);
      expect(find.text('14.32'), findsNWidgets(2));

      await tester.tap(find.text('Sellers'));
      await tester.pump();
      expect(find.text('Najwa'), findsOneWidget);
      expect(find.text('Evan'), findsNothing);

      await tester.tap(find.text('All'));
      repo.overviews.add((
        conversations: [
          _conv('2', 'Evan', iAmBuyer: false, last: 'Oke, aku ambil'),
          _conv('1', 'Najwa', iAmBuyer: true, last: 'Bisa nego?'),
        ],
        announcement: null,
      ));
      await tester.pump();
      expect(find.text('Oke, aku ambil'), findsOneWidget);
    });

    testWidgets('empty and error states', (tester) async {
      final repo = FakeChatRepository();
      await _pump(tester, ChatListScreen(repository: repo, now: () => _now));
      repo.overviews.add((conversations: [], announcement: null));
      await tester.pump();
      expect(
        find.text('No chats yet. Start one from an item page.'),
        findsOneWidget,
      );
      // Admin BeeKas is always there.
      expect(find.text('Admin BeeKas'), findsOneWidget);

      repo.overviews.addError(const SignupException(SignupError.unknown));
      await tester.pump();
      expect(find.text("Couldn't load your chats."), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Admin BeeKas opens announcements without a reply field', (
      tester,
    ) async {
      final repo = FakeChatRepository()
        ..announcementList = [
          (body: 'Layanan libur 1 November.', createdAt: _now),
        ];
      await _pump(tester, ChatListScreen(repository: repo, now: () => _now));
      repo.overviews.add((
        conversations: [],
        announcement: repo.announcementList.first,
      ));
      await tester.pump();
      expect(find.text('Layanan libur 1 November.'), findsOneWidget);

      await tester.tap(find.text('Admin BeeKas'));
      await tester.pumpAndSettle();
      expect(find.text('Layanan libur 1 November.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Only the BeeKas team posts here.'), findsOneWidget);
    });
  });

  group('K15 Ruang Chat', () {
    Future<FakeChatRepository> room(
      WidgetTester tester, {
      String? conversationId = 'c1',
    }) async {
      final repo = FakeChatRepository();
      await _pump(
        tester,
        ChatRoomScreen(
          repository: repo,
          title: 'Najwa',
          conversationId: conversationId,
          listingId: 'l1',
          item: (
            title: 'Kalkulator',
            price: 50000,
            isDonation: false,
            photo: null,
          ),
        ),
      );
      return repo;
    }

    testWidgets('shows the item card and new messages as they arrive', (
      tester,
    ) async {
      final repo = await room(tester);
      expect(find.text('Kalkulator'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.room('c1').add([_msg('1', 'Masih ada?', mine: true)]);
      await tester.pump();
      expect(find.text('Masih ada?'), findsOneWidget);

      repo.room('c1').add([
        _msg('1', 'Masih ada?', mine: true),
        _msg('2', 'Masih, kak'),
      ]);
      await tester.pump();
      expect(find.text('Masih, kak'), findsOneWidget);
    });

    testWidgets('sends the trimmed text, with the listing for the card', (
      tester,
    ) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();
      expect(find.text('Say hello about this item.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Bisa COD besok?  ');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(repo.sent.single, (
        body: 'Bisa COD besok?',
        conversationId: 'c1',
        listingId: 'l1',
      ));
      expect(find.text('Bisa COD besok?'), findsNothing);
    });

    testWidgets('warns before sending contact details; may still send', (
      tester,
    ) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'WA aku 0812 3456 7890');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Share contact details?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);

      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send anyway'));
      await tester.pumpAndSettle();
      expect(repo.sent.single.body, 'WA aku 0812 3456 7890');
    });

    testWidgets('online and prices send without a warning', (tester) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'online, Rp1.500.000');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Share contact details?'), findsNothing);
      expect(repo.sent, hasLength(1));
    });

    testWidgets('refuses messages over 1.000 characters', (tester) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'a' * 1001);
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(
        find.text('Messages can be up to 1,000 characters.'),
        findsOneWidget,
      );
      expect(repo.sent, isEmpty);
    });

    testWidgets('a new chat starts from the listing on the first send', (
      tester,
    ) async {
      final repo = await room(tester, conversationId: null);
      await tester.pump();
      expect(find.text('Say hello about this item.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Halo');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(repo.sent.single, (
        body: 'Halo',
        conversationId: null,
        listingId: 'l1',
      ));
      repo.room('new').add([_msg('1', 'Halo', mine: true)]);
      await tester.pump();
      expect(find.text('Halo'), findsOneWidget);
    });

    testWidgets('shows why a send failed and keeps the text', (tester) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();
      repo.errors['send'] = const SignupException(SignupError.chatNotAllowed);
      await tester.enterText(find.byType(TextField), 'Halo');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(
        find.textContaining('Only verified accounts that are not frozen'),
        findsOneWidget,
      );
      expect(find.text('Halo'), findsOneWidget);
    });

    testWidgets('any other send failure shows the generic error', (
      tester,
    ) async {
      final repo = await room(tester);
      repo.room('c1').add([]);
      await tester.pump();
      repo.errors['send'] = StateError('socket closed');
      await tester.enterText(find.byType(TextField), 'Halo');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.text("Couldn't send the message."), findsOneWidget);
      expect(find.text('Halo'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final repo = await room(tester);
      repo.room('c1').addError(const SignupException(SignupError.unknown));
      await tester.pump();
      expect(find.text("Couldn't load the messages."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      repo.room('c1').add([_msg('1', 'Halo')]);
      await tester.pump();
      expect(find.text('Halo'), findsOneWidget);
    });
  });

  group('K21 Pengumuman', () {
    testWidgets('admin previews, then posts', (tester) async {
      final repo = FakeChatRepository();
      await _pump(tester, PostAnnouncementScreen(repository: repo));
      await tester.tap(find.text('Preview'));
      await tester.pump();
      expect(find.text('Write the announcement.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' Layanan libur. ');
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Layanan libur.'), findsOneWidget);
      await tester.tap(find.text('Send to all members'));
      await tester.pumpAndSettle();
      expect(repo.posted, ['Layanan libur.']);
      expect(find.text('Announcement sent.'), findsOneWidget);
    });
  });
}
