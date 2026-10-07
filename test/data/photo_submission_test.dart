import 'dart:typed_data';

import 'package:beekas/data/signup_repository.dart';
import 'package:beekas/domain/signup_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_signup_repository.dart';

final _card = Uint8List.fromList([1]);
final _selfie = Uint8List.fromList([2]);

PhotoSubmission _submission(FakeSignupRepository repo) {
  var n = 0;
  return PhotoSubmission(repo, newAttempt: () => 'a${++n}');
}

void main() {
  _illegalTransitionTests();
  test(
    'uploads card and selfie into one attempt folder, then submits',
    () async {
      final repo = FakeSignupRepository();
      await _submission(repo).send(_card, _selfie);

      expect(repo.uploads, ['a1/card.jpg', 'a1/selfie.jpg']);
      expect(repo.calls.last, 'submitForReview');
    },
  );

  test('after a partial upload the retry uses a new folder, never the same '
      'path', () async {
    // Card goes in, selfie fails.
    final repo = FakeSignupRepository()..failUpload = 'a1/selfie.jpg';
    final submission = _submission(repo);
    await expectLater(
      submission.send(_card, _selfie),
      throwsA(isA<SignupException>()),
    );
    expect(repo.calls, isNot(contains('submitForReview')));

    await submission.send(_card, _selfie);

    expect(repo.uploads, ['a1/card.jpg', 'a2/card.jpg', 'a2/selfie.jpg']);
    expect(repo.calls.last, 'submitForReview');
  });

  test(
    'when only submit failed, the retry submits without uploading again',
    () async {
      final repo = FakeSignupRepository(
        errors: {
          'submitForReview': [const SignupException(null)],
        },
      );
      final submission = _submission(repo);
      await expectLater(
        submission.send(_card, _selfie),
        throwsA(isA<SignupException>()),
      );
      await submission.send(_card, _selfie);

      expect(repo.uploads, ['a1/card.jpg', 'a1/selfie.jpg']);
      expect(repo.calls.where((c) => c == 'submitForReview'), hasLength(2));
    },
  );

  test('a retaken selfie is uploaded into a new folder', () async {
    final repo = FakeSignupRepository(
      errors: {
        'submitForReview': [const SignupException(null)],
      },
    );
    final submission = _submission(repo);
    await expectLater(
      submission.send(_card, _selfie),
      throwsA(isA<SignupException>()),
    );
    await submission.send(_card, Uint8List.fromList([3]));

    expect(repo.uploads, [
      'a1/card.jpg',
      'a1/selfie.jpg',
      'a2/card.jpg',
      'a2/selfie.jpg',
    ]);
  });

  test('after photos_missing the retry uploads again', () async {
    final repo = FakeSignupRepository(
      errors: {
        'submitForReview': [const SignupException(SignupError.photosMissing)],
      },
    );
    final submission = _submission(repo);
    await expectLater(
      submission.send(_card, _selfie),
      throwsA(isA<SignupException>()),
    );
    await submission.send(_card, _selfie);

    expect(repo.uploads, [
      'a1/card.jpg',
      'a1/selfie.jpg',
      'a2/card.jpg',
      'a2/selfie.jpg',
    ]);
  });
}

void _illegalTransitionTests() {
  group('illegal_status_transition re-reads the status', () {
    FakeSignupRepository repo(String status) => FakeSignupRepository(
      errors: {
        'submitForReview': [
          const SignupException(SignupError.illegalTransition),
        ],
      },
    )..profileStatus = status;

    test(
      'pending: an earlier submit went through, so it counts as sent',
      () async {
        final r = repo('pending');
        await _submission(r).send(_card, _selfie);
        expect(r.calls.last, 'status');
      },
    );

    for (final (status, error) in [
      ('approved', SignupError.alreadyApproved),
      ('rejected', SignupError.statusRejected),
      ('incomplete', SignupError.statusIncomplete),
    ]) {
      test('$status: shows its own message', () async {
        await expectLater(
          _submission(repo(status)).send(_card, _selfie),
          throwsA(
            isA<SignupException>().having((e) => e.error, 'error', error),
          ),
        );
      });
    }
  });
}
