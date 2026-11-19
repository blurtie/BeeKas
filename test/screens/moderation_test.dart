import 'dart:async';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/moderation_repository.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/moderation.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/catalog_screens.dart';
import 'package:beekas/screens/chat_screens.dart';
import 'package:beekas/screens/moderation_screens.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog_repository.dart';
import '../support/fake_chat_repository.dart';

class _FakeModeration implements ModerationRepository {
  final reports = <String>[];
  final removed = <String>[];
  final dismissed = <String>[];
  var groups = <ReportGroup>[];
  Completer<void>? gate;
  Object? fail;

  Future<void> _call() async {
    await gate?.future;
    final error = fail;
    fail = null;
    if (error != null) throw error;
  }

  @override
  Future<void> reportListing(String id, ReportReason r, String note) async {
    await _call();
    reports.add('listing:$id:${r.code}:$note');
  }

  @override
  Future<void> reportChat(String id, ReportReason r, String note) async {
    await _call();
    reports.add('chat:$id:${r.code}:$note');
  }

  @override
  Future<List<ReportGroup>> openReports() async {
    await _call();
    return groups;
  }

  @override
  Future<void> removeListing(String id, String reason) async {
    await _call();
    removed.add('$id:$reason');
    groups = [];
  }

  @override
  Future<void> dismiss(String id) async {
    await _call();
    dismissed.add(id);
    groups = [];
  }
}

final _group = (
  reportId: 'r1',
  listingId: 'l1',
  listingTitle: 'Kalkulator',
  memberName: null,
  reporters: 2,
  reasons: [ReportReason.scam, ReportReason.other],
  notes: ['Palsu'],
  firstAt: DateTime(2026, 11, 20, 9),
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => language.value = Lang.en);

  group('K16 Lapor', () {
    testWidgets('from Detail Barang: Lainnya needs a note', (tester) async {
      final repo = _FakeModeration();
      await _pump(
        tester,
        ListingDetailScreen(
          listing: fakeListing('Kalkulator'),
          status: AccountStatus.approved,
          moderation: repo,
        ),
      );
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report this item'), findsOneWidget);

      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Choose a reason.'), findsOneWidget);

      await tester.tap(find.text('Other'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Tell us what is wrong.'), findsOneWidget);
      expect(repo.reports, isEmpty);

      await tester.enterText(find.byType(TextField), 'Barang palsu');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(repo.reports, ['listing:Kalkulator:other:Barang palsu']);
      expect(find.text('Report sent'), findsOneWidget);
    });

    testWidgets('hidden on own listings and for pending accounts', (
      tester,
    ) async {
      for (final (listing, status) in [
        (fakeListing('Mine', isMine: true), AccountStatus.approved),
        (fakeListing('Theirs'), AccountStatus.pending),
      ]) {
        await _pump(
          tester,
          ListingDetailScreen(
            listing: listing,
            status: status,
            moderation: _FakeModeration(),
          ),
        );
        expect(find.byTooltip('Report'), findsNothing);
      }
    });

    testWidgets('from chat, with the backend refusal shown', (tester) async {
      final repo = _FakeModeration()
        ..fail = const SignupException(SignupError.alreadyReported);
      final chats = FakeChatRepository();
      tester.view.physicalSize = const Size(1080, 4800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: beeTheme(),
          home: ChatRoomScreen(
            repository: chats,
            title: 'Najwa',
            conversationId: 'c1',
            moderation: repo,
          ),
        ),
      );
      chats.room('c1').add(const []);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report Najwa'), findsOneWidget);
      await tester.tap(find.text('Spam'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(find.text(t('errorAlreadyReported')), findsOneWidget);

      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(repo.reports, ['chat:c1:spam:']);
      expect(find.text('Report sent'), findsOneWidget);
    });
  });

  group('K19 Laporan', () {
    testWidgets('loading, error, then empty', (tester) async {
      final repo = _FakeModeration()
        ..gate = Completer()
        ..fail = const SignupException(SignupError.notAdmin);
      await tester.pumpWidget(
        MaterialApp(
          theme: beeTheme(),
          home: ReportListScreen(repository: repo),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load reports."), findsOneWidget);
      await tester.tap(find.text(t('retry')));
      await tester.pumpAndSettle();
      expect(find.text('No open reports.'), findsOneWidget);
    });

    testWidgets('takes a listing down with a reason', (tester) async {
      final repo = _FakeModeration()..groups = [_group];
      await _pump(tester, ReportListScreen(repository: repo));
      expect(find.text('Kalkulator'), findsOneWidget);
      expect(find.textContaining('2 reporters'), findsOneWidget);

      await tester.tap(find.text('Kalkulator'));
      await tester.pumpAndSettle();
      expect(find.text('Scam, Other'), findsOneWidget);
      expect(find.text('• Palsu'), findsOneWidget);

      await tester.tap(find.text('Take down listing'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Take down listing'));
      await tester.pump();
      expect(find.text('Write the reason.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Barang terlarang');
      await tester.tap(find.widgetWithText(TextButton, 'Take down listing'));
      await tester.pumpAndSettle();

      expect(repo.removed, ['l1:Barang terlarang']);
      expect(find.text('Listing taken down'), findsOneWidget);
      expect(find.text('No open reports.'), findsOneWidget);
    });

    testWidgets('dismisses a member report (no take down)', (tester) async {
      final repo = _FakeModeration()
        ..groups = [
          (
            reportId: 'r2',
            listingId: null,
            listingTitle: null,
            memberName: 'Budi',
            reporters: 1,
            reasons: [ReportReason.inappropriate],
            notes: const [],
            firstAt: DateTime(2026, 11, 20, 9),
          ),
        ];
      await _pump(tester, ReportListScreen(repository: repo));
      await tester.tap(find.text('Budi'));
      await tester.pumpAndSettle();
      expect(find.text('Take down listing'), findsNothing);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(repo.dismissed, ['r2']);
      expect(find.text('Report dismissed'), findsOneWidget);
    });

    testWidgets('Indonesian copy', (tester) async {
      language.value = Lang.id;
      await _pump(tester, ReportListScreen(repository: _FakeModeration()));
      expect(find.text('Laporan'), findsOneWidget);
      expect(find.text('Tidak ada laporan terbuka.'), findsOneWidget);
    });
  });
}
