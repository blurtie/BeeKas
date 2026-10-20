import 'package:beekas/domain/access.dart';
import 'package:beekas/domain/help.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bantuan mailto: team address, subject, name, email and status', () {
    final uri = helpMailto(
      fullName: 'Budi Santoso & Co',
      email: 'budi@binus.ac.id',
      status: AccountStatus.pending,
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'beekas2026@gmail.com');
    expect(uri.queryParameters['subject'], 'Bantuan BeeKas');
    expect(
      uri.queryParameters['body'],
      'Nama: Budi Santoso & Co\nEmail akun: budi@binus.ac.id\n'
      'Status akun: pending\n\n',
    );
    expect(uri.toString(), isNot(contains('+')));
  });
}
