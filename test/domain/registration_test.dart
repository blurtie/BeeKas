import 'package:beekas/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rule 1: BINUS email', () {
    test('accepts both domains, any case, trimmed', () {
      expect(isBinusEmail(' John.Doe@BINUS.AC.ID '), isTrue);
      expect(isBinusEmail('jdoe@binus.edu'), isTrue);
      expect(normalizeEmail(' John@Binus.Edu '), 'john@binus.edu');
    });

    test('rejects other domains and malformed addresses', () {
      for (final e in [
        'a@gmail.com',
        'a@binus.ac.id.evil.com',
        'a@sub.binus.edu.co',
        '@binus.ac.id',
        'a b@binus.ac.id',
        'a@b@binus.edu',
        '',
      ]) {
        expect(isBinusEmail(e), isFalse, reason: e);
      }
    });
  });

  group('rule 2: phone', () {
    test('normalises 08, 628 and +628 with spaces and hyphens', () {
      for (final p in [
        '081234567890',
        '6281234567890',
        '+6281234567890',
        '0812 3456 7890',
        '+62 812-3456-7890',
        ' 0812-3456-7890 ',
      ]) {
        expect(normalizePhone(p), '+6281234567890', reason: p);
      }
    });

    test('10 and 13 digits (counting 08) are the bounds', () {
      expect(normalizePhone('0812345678'), '+62812345678'); // 10
      expect(normalizePhone('0812345678901'), '+62812345678901'); // 13
      expect(normalizePhone('08123456789012'), isNull); // 14
      expect(normalizePhone('081234567'), isNull); // 9
    });

    test('result always matches profiles_phone_check', () {
      final db = RegExp(r'^\+628[0-9]{8,11}$');
      for (var n = 8; n <= 11; n++) {
        expect(normalizePhone('08${'1' * n}'), matches(db));
      }
    });

    test('rejects non-mobile and junk', () {
      for (final p in ['0212345678', '+6221234567890', '08abc4567890', '']) {
        expect(normalizePhone(p), isNull, reason: p);
      }
    });
  });

  group('rule 5: account type from domain', () {
    test('binus.ac.id is fixed to student', () {
      expect(accountTypesFor('a@binus.ac.id'), [AccountType.student]);
    });
    test('binus.edu chooses lecturer or staff', () {
      expect(accountTypesFor('a@BINUS.edu'), [
        AccountType.lecturer,
        AccountType.staff,
      ]);
    });
    test('none until the email is valid', () {
      expect(accountTypesFor('a@binus'), isEmpty);
    });
  });

  test('rule 6: campus codes match the Postgres enum (D-12)', () {
    expect(Campus.values.map((c) => c.code), [
      'kemanggisan',
      'senayan',
      'alam_sutera',
      'base',
      'bekasi',
      'bandung',
      'malang',
      'semarang',
      'online',
    ]);
  });

  group('validateRegistration', () {
    test('every field is required', () {
      final r = validateRegistration(fullName: ' ', email: '', phone: '');
      expect(r.registration, isNull);
      expect(r.errors, {
        RegistrationField.fullName: 'fullNameRequired',
        RegistrationField.email: 'errorEmailRequired',
        RegistrationField.phone: 'errorPhoneRequired',
        RegistrationField.campus: 'errorInvalidCampus',
      });
    });

    test('binus.edu needs lecturer or staff', () {
      final r = validateRegistration(
        fullName: 'A',
        email: 'a@binus.edu',
        phone: '0812345678',
        chosenType: AccountType.student,
        campus: Campus.senayan,
      );
      expect(r.errors, {
        RegistrationField.accountType: 'errorAccountTypeRequired',
      });
    });

    test('student metadata omits account_type', () {
      final r = validateRegistration(
        fullName: ' Ana ',
        email: 'Ana@Binus.ac.id',
        phone: '0812-3456-7890',
        chosenType: AccountType.staff, // ignored for binus.ac.id
        campus: Campus.alamSutera,
      );
      expect(r.errors, isEmpty);
      expect(r.registration!.email, 'ana@binus.ac.id');
      expect(r.registration!.metadata, {
        'full_name': 'Ana',
        'phone': '+6281234567890',
        'campus': 'alam_sutera',
      });
    });

    test('binus.edu metadata carries the chosen type', () {
      final r = validateRegistration(
        fullName: 'B',
        email: 'b@binus.edu',
        phone: '+62812345678',
        chosenType: AccountType.lecturer,
        campus: Campus.online,
      );
      expect(r.registration!.metadata['account_type'], 'lecturer');
    });
  });

  group('afterOtp', () {
    final submitted = validateRegistration(
      fullName: 'A',
      email: 'a@binus.ac.id',
      phone: '0812345678',
      campus: Campus.base,
    ).registration!;

    test('an account with a password is already registered', () {
      final r = afterOtp(
        hasPassword: true,
        storedPhone: '+62899999999',
        submitted: submitted,
      );
      expect(r.next, AfterOtp.alreadyRegistered);
      expect(r.phoneChanged, isFalse);
    });

    test('an abandoned sign-up continues and flags a kept old phone', () {
      final r = afterOtp(
        hasPassword: false,
        storedPhone: '+62899999999',
        submitted: submitted,
      );
      expect(r.next, AfterOtp.continueSignup);
      expect(r.phoneChanged, isTrue);
    });

    test('a fresh sign-up continues without a phone notice', () {
      final r = afterOtp(
        hasPassword: false,
        storedPhone: '+62812345678',
        submitted: submitted,
      );
      expect(r, (next: AfterOtp.continueSignup, phoneChanged: false));
    });
  });
}
