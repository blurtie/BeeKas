import 'dart:convert';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/photo.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/screens/card_photo_screen.dart';
import 'package:beekas/screens/consent_screen.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_signup_repository.dart';

// 1×1 PNG, standing in for a card photo.
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 3000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

FilledButton _button(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
);

void main() {
  group('L7 Persetujuan data', () {
    testWidgets('Lanjut stays off until the box is ticked, then records the '
        'consent version', (tester) async {
      final repo = FakeSignupRepository();
      var agreed = false;
      await _pump(
        tester,
        ConsentScreen(repository: repo, onAgreed: () => agreed = true),
      );
      for (final key in [
        'consentData',
        'consentPurpose',
        'consentViewer',
        'consentRetention',
      ]) {
        expect(find.text(t(key)), findsOneWidget);
      }
      expect(_button(tester, t('next')).onPressed, isNull);

      await tester.tap(find.text(t('consentAgree')));
      await tester.pump();
      await tester.tap(find.text(t('next')));
      await tester.pump();

      expect(repo.consentVersion, consentVersion);
      expect(agreed, isTrue);
    });

    testWidgets('a failed save shows an error and does not continue', (
      tester,
    ) async {
      final repo = FakeSignupRepository(
        errors: {
          'recordConsent': [const SignupException(null)],
        },
      );
      var agreed = false;
      await _pump(
        tester,
        ConsentScreen(repository: repo, onAgreed: () => agreed = true),
      );
      await tester.tap(find.text(t('consentAgree')));
      await tester.pump();
      await tester.tap(find.text(t('next')));
      await tester.pump();

      expect(find.text(t('errorNetwork')), findsOneWidget);
      expect(agreed, isFalse);
    });
  });

  group('L8–L9 Foto kartu', () {
    Future<List<Uint8List>> pumpCard(
      WidgetTester tester, {
      required List<Object?> shots,
      AccountType type = AccountType.student,
      VoidCallback? onSettings,
    }) async {
      final used = <Uint8List>[];
      await _pump(
        tester,
        CardPhotoScreen(
          accountType: type,
          takePhoto: () async {
            final shot = shots.removeAt(0);
            if (shot is PhotoException) throw shot;
            return shot as Uint8List?;
          },
          openSettings: () async => onSettings?.call(),
          onUse: used.add,
        ),
      );
      return used;
    }

    testWidgets('asks for the card that matches the account type (D-15)', (
      tester,
    ) async {
      await pumpCard(tester, shots: [], type: AccountType.lecturer);
      final card = t('card_lecturer');
      expect(find.text(t('cardTake').replaceFirst('{card}', card)), findsOne);
    });

    testWidgets('photo → confirm → Use photo hands over the bytes', (
      tester,
    ) async {
      final used = await pumpCard(tester, shots: [_photo]);
      await tester.tap(find.text(t('takePhoto')));
      await tester.pumpAndSettle();

      expect(find.text(t('cardConfirmTitle')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text(t('usePhoto')));
      expect(used, [_photo]);
    });

    testWidgets('Retake goes back and opens the camera again', (tester) async {
      final shots = <Object?>[_photo, null];
      await pumpCard(tester, shots: shots);
      await tester.tap(find.text(t('takePhoto')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('retake')));
      await tester.pumpAndSettle();

      expect(shots, isEmpty, reason: 'camera opened a second time');
      // Backing out of the camera leaves L8 without an error.
      expect(find.text(t('cardTitle')), findsOneWidget);
      expect(find.text(t('errorPhotoFailed')), findsNothing);
    });

    testWidgets('camera refused: message and a way to Settings', (
      tester,
    ) async {
      var opened = false;
      await pumpCard(
        tester,
        shots: [const PhotoException(PhotoError.cameraDenied)],
        onSettings: () => opened = true,
      );
      await tester.tap(find.text(t('takePhoto')));
      await tester.pump();

      expect(find.text(t('errorCameraDenied')), findsOneWidget);
      await tester.tap(find.text(t('openSettings')));
      expect(opened, isTrue);
    });

    testWidgets('a photo over 5 MB asks for another', (tester) async {
      await pumpCard(
        tester,
        shots: [const PhotoException(PhotoError.tooLarge)],
      );
      await tester.tap(find.text(t('takePhoto')));
      await tester.pump();

      expect(find.text(t('errorPhotoTooLarge')), findsOneWidget);
      expect(find.text(t('openSettings')), findsNothing);
    });
  });
}
