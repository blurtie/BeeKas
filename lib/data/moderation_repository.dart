import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/moderation.dart';
import 'signup_repository.dart';

/// One reported object in K19: a listing, or a member reported from chat.
/// [reportId] is any open report on it; acting on it closes them all.
typedef ReportGroup = ({
  String reportId,
  String? listingId,
  String? listingTitle,
  String? memberName,
  int reporters,
  List<ReportReason> reasons,
  List<String> notes,
  DateTime firstAt,
});

/// Reports (#87). Members report; admins see and decide (the backend
/// refuses non-admins). Failures are [SignupException]s.
abstract interface class ModerationRepository {
  Future<void> reportListing(
    String listingId,
    ReportReason reason,
    String note,
  );

  /// The other party of [conversationId].
  Future<void> reportChat(
    String conversationId,
    ReportReason reason,
    String note,
  );

  /// Oldest first.
  Future<List<ReportGroup>> openReports();

  /// Turunkan: cancels its running orders and refunds its bids.
  Future<void> removeListing(String listingId, String reason);

  /// Abaikan.
  Future<void> dismiss(String reportId);
}

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);
  final SupabaseClient _client;

  Future<void> _report(
    ReportReason reason,
    String note, {
    String? listing,
    String? conversation,
  }) => guardBackend(
    () => _client.rpc<void>(
      'submit_report',
      params: {
        'p_reason': reason.code,
        'p_note': note.trim().isEmpty ? null : note.trim(),
        'p_listing': listing,
        'p_conversation': conversation,
      },
    ),
  );

  @override
  Future<void> reportListing(
    String listingId,
    ReportReason reason,
    String note,
  ) => _report(reason, note, listing: listingId);

  @override
  Future<void> reportChat(
    String conversationId,
    ReportReason reason,
    String note,
  ) => _report(reason, note, conversation: conversationId);

  @override
  Future<List<ReportGroup>> openReports() => guardBackend(() async {
    final rows = await _client.rpc<List<dynamic>>('admin_open_reports');
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          reportId: row['report_id'] as String,
          listingId: row['listing_id'] as String?,
          listingTitle: row['listing_title'] as String?,
          memberName: row['reported_name'] as String?,
          reporters: row['reporters'] as int,
          reasons: [
            for (final r in row['reasons'] as List)
              ReportReason.fromCode(r as String),
          ],
          notes: (row['notes'] as List).cast<String>(),
          firstAt: DateTime.parse(row['first_at'] as String).toLocal(),
        ),
    ];
  });

  @override
  Future<void> removeListing(String listingId, String reason) => guardBackend(
    () => _client.rpc<void>(
      'remove_listing',
      params: {'p_listing': listingId, 'p_reason': reason.trim()},
    ),
  );

  @override
  Future<void> dismiss(String reportId) => guardBackend(
    () => _client.rpc<void>('dismiss_report', params: {'p_report': reportId}),
  );
}
