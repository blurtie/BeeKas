import '../config/help.dart';
import 'access.dart';

/// The Bantuan mailto (D-14). The body is for the team, so it is always in
/// Indonesian. Encoded by hand: Uri.queryParameters turns spaces into `+`,
/// which mail apps show literally.
Uri helpMailto({
  required String fullName,
  required String email,
  required AccountStatus status,
}) {
  final body =
      'Nama: $fullName\nEmail akun: $email\nStatus akun: ${status.name}\n\n';
  return Uri.parse(
    'mailto:$helpEmail'
    '?subject=${Uri.encodeComponent('Bantuan BeeKas')}'
    '&body=${Uri.encodeComponent(body)}',
  );
}
