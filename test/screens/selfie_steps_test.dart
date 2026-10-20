import 'dart:convert';
import 'dart:typed_data';

import 'package:beekas/config/copy.dart';
import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/photo.dart';
import 'package:beekas/domain/registration.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:beekas/screens/pending_screen.dart';
import 'package:beekas/screens/phone_screen.dart';
import 'package:beekas/screens/selfie_screen.dart';
import 'package:beekas/ui/components.dart';
import 'package:beekas/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_signup_repository.dart';

// 1×1 PNG, standing in for both photos.
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: beeTheme(), home: screen));
}

Future<void> _pumpSelfie(
  WidgetTester tester,
  FakeSignupRepository repo, {
  Future<Uint8List?> Function()? takePhoto,
  VoidCallback? onSent,
}) {
  var attempts = 0;
  return _pump(
    tester,
    SelfieScreen(
      accountType: AccountType.student,
      card: _photo,
      repository: repo,
      newAttempt: () => 'a${++attempts}',
      takePhoto: takePhoto ?? () async => _photo,
      openSettings: () async {},
      onSent: onSent ?? () {},
    ),
  );
}

void main() {
  testWidgets('L10 shows the four PRD tips, then Ulangi and Kirim after the '
      'selfie', (tester) async {
    var sent = false;
    final repo = FakeSignupRepository();
    await _pumpSelfie(tester, repo, onSent: () => sent = true);
    for (final key in [
      'tipFaceLight',
      'tipFaceClear',
      'tipFaceCover',
      'tipFaceClothes',
    ]) {
      expect(find.text(t(key)), findsOneWidget);
    }
    expect(find.text(t('send')), findsNothing);

    await tester.tap(find.text(t('startVerification')));
    await tester.pump();
    expect(find.bySemanticsLabel(t('selfiePreview')), findsOneWidget);
    expect(find.text(t('retake')), findsOneWidget);

    await tester.tap(find.text(t('send')));
    await tester.pump();
    expect(repo.uploads, hasLength(2));
    expect(repo.calls.last, 'submitForReview');
    expect(sent, isTrue);
  });

  testWidgets('a failed upload keeps the selfie and Kirim tries again in a new '
      'folder', (tester) async {
    final repo = FakeSignupRepository();
    var sent = false;
    await _pumpSelfie(tester, repo, onSent: () => sent = true);
    await tester.tap(find.text(t('startVerification')));
    await tester.pump();
    // Card goes in, then the selfie upload fails.
    repo.failUpload = 'a1/selfie.jpg';
    await tester.tap(find.text(t('send')));
    await tester.pump();
    expect(find.text(t('errorNetwork')), findsOneWidget);
    expect(find.bySemanticsLabel(t('selfiePreview')), findsOneWidget);
    expect(sent, isFalse);

    await tester.tap(find.text(t('send')));
    await tester.pump();
    expect(repo.uploads, ['a1/card.jpg', 'a2/card.jpg', 'a2/selfie.jpg']);
    expect(sent, isTrue);
  });

  testWidgets('submit_for_review errors show their copy', (tester) async {
    final repo = FakeSignupRepository(
      errors: {
        'submitForReview': [const SignupException(SignupError.photosMissing)],
      },
    );
    await _pumpSelfie(tester, repo);
    await tester.tap(find.text(t('startVerification')));
    await tester.pump();
    await tester.tap(find.text(t('send')));
    await tester.pump();
    expect(find.text(t('errorPhotosMissing')), findsOneWidget);
  });

  testWidgets('a denied front camera offers Settings', (tester) async {
    await _pumpSelfie(
      tester,
      FakeSignupRepository(),
      takePhoto: () async =>
          throw const PhotoException(PhotoError.cameraDenied),
    );
    await tester.tap(find.text(t('startVerification')));
    await tester.pump();
    expect(find.text(t('errorCameraDenied')), findsOneWidget);
    expect(find.text(t('openSettings')), findsOneWidget);
  });

  testWidgets('phone_missing opens the #27 phone step, then sends the same '
      'photos again', (tester) async {
    final repo = FakeSignupRepository(
      errors: {
        'submitForReview': [const SignupException(SignupError.phoneMissing)],
      },
    );
    var sent = false;
    await _pumpSelfie(tester, repo, onSent: () => sent = true);
    await tester.tap(find.text(t('startVerification')));
    await tester.pump();
    await tester.tap(find.text(t('send')));
    await tester.pump();
    expect(find.text(t('errorPhoneMissing')), findsOneWidget);

    await tester.tap(find.text(t('addPhone')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.text(t('phoneSubtitleMissing')), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0813-1111-2222');
    await tester.tap(find.text(t('next')));
    // Not pumpAndSettle: Kirim keeps spinning after success, as L11 replaces
    // the route in the app.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repo.phone, '+6281311112222');
    expect(find.byType(SelfieScreen), findsOneWidget);
    expect(repo.uploads, ['a1/card.jpg', 'a1/selfie.jpg']);
    expect(repo.calls.where((c) => c == 'submitForReview'), hasLength(2));
    expect(sent, isTrue);
  });

  testWidgets('phone step, rejected mode: stepper and the error', (
    tester,
  ) async {
    await _pump(
      tester,
      PhoneScreen(
        repository: FakeSignupRepository(),
        initialError: SignupError.phoneTaken,
        onSaved: () {},
      ),
    );
    expect(find.text(t('phoneSubtitle')), findsOneWidget);
    expect(find.text(t('errorPhoneTaken')), findsOneWidget);
    expect(find.byType(BeeStepper), findsOneWidget);
  });

  testWidgets('phone step, missing mode: only the subtitle, no stepper', (
    tester,
  ) async {
    final repo = FakeSignupRepository(
      errors: {
        'setPhone': [const SignupException(null)],
      },
    );
    await _pump(
      tester,
      PhoneScreen(
        repository: repo,
        initialError: SignupError.phoneMissing,
        onSaved: () {},
        mode: PhoneScreenMode.missing,
      ),
    );
    expect(find.text(t('phoneSubtitleMissing')), findsOneWidget);
    expect(find.text(t('errorPhoneMissing')), findsNothing);
    expect(find.byType(BeeStepper), findsNothing);

    // A failed save still shows its error.
    await tester.enterText(find.byType(TextField), '0813-1111-2222');
    await tester.tap(find.text(t('next')));
    await tester.pump();
    expect(find.text(t('errorNetwork')), findsOneWidget);
  });

  testWidgets('L11 offers Lihat katalog and Keluar', (tester) async {
    var browsed = false, signedOut = false;
    await _pump(
      tester,
      PendingScreen(
        onBrowse: () => browsed = true,
        onSignOut: () => signedOut = true,
      ),
    );
    expect(find.text(t('pendingTitle')), findsOneWidget);
    await tester.tap(find.text(t('browseCatalog')));
    await tester.tap(find.text(t('signOut')));
    expect(browsed && signedOut, isTrue);
  });
}
