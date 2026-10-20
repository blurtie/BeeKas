import 'dart:io';

import 'package:beekas/config/copy.dart';
import 'package:flutter_test/flutter_test.dart';

// #33: the decision email renders reason texts in SQL (public.reason_text); they must match
// the app's rejectReason_* copy.
void main() {
  final sql = File('supabase/migrations/20261022120000_decision_emails.sql')
      .readAsStringSync();

  for (final lang in [Lang.id, Lang.en]) {
    for (final code in ['card', 'selfie', 'data', 'other']) {
      test('$lang $code matches copy.dart', () {
        final text = copy[lang]!['rejectReason_$code']!.replaceAll("'", "''");
        expect(sql, contains("when '$code' then '$text'"));
      });
    }
  }
}
