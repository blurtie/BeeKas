import 'package:beekas/domain/chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contact warning (K-20)', () {
    for (final text in [
      '081234567890',
      'hubungi 0812-3456-7890 ya',
      '0812 3456 789',
      '+6281234567890',
      '+62 812 3456 7890',
      '6281234567890',
      'wa.me/6281234',
      'https://t.me/budi',
      'follow @budi_jual',
      'WA aku aja',
      'chat lewat whatsapp',
      'add LINE ku',
      'cek ig ku',
      'Telegram: budi',
    ]) {
      test('flags "$text"', () => expect(looksLikeContact(text), isTrue));
    }

    for (final text in [
      'online',
      'deadline',
      'big',
      '1.500.000',
      'Harganya Rp1.500.000, bisa nego?',
      'aku online jam 5, deadline besok',
      'barangnya big size',
      'kirim ke budi@binus.ac.id',
      'ketemu di lobby jam 10',
      '0812345',
      'swap',
      'wage',
    ]) {
      test(
        'leaves "$text" alone',
        () => expect(looksLikeContact(text), isFalse),
      );
    }
  });

  group('message validation (K-21)', () {
    test('empty and blank messages are refused', () {
      expect(validateMessage(''), MessageError.empty);
      expect(validateMessage('  \n '), MessageError.empty);
    });

    test('up to 1.000 characters are allowed', () {
      expect(validateMessage('Halo'), isNull);
      expect(validateMessage('a' * 1000), isNull);
      expect(validateMessage('  ${'a' * 1000}  '), isNull);
      expect(validateMessage('a' * 1001), MessageError.tooLong);
    });

    test('counts characters as the database does, not UTF-16 units', () {
      expect(validateMessage('🐝' * 1000), isNull);
      expect(validateMessage('🐝' * 1001), MessageError.tooLong);
    });
  });

  test('Penjual shows chats where I am the buyer (5.8)', () {
    expect(ChatFilter.all.shows(iAmBuyer: true), isTrue);
    expect(ChatFilter.all.shows(iAmBuyer: false), isTrue);
    expect(ChatFilter.sellers.shows(iAmBuyer: true), isTrue);
    expect(ChatFilter.sellers.shows(iAmBuyer: false), isFalse);
  });
}
