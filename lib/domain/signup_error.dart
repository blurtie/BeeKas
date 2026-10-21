/// Why the backend refused a sign-up. Messages and constraint names must match
/// handle_new_user, set_phone and the profiles table in supabase/migrations;
/// [copyKey] points into lib/config/copy.dart. The phone errors come from
/// set_phone after OTP (#27); GoTrue hides trigger errors from the app.
enum SignupError {
  invalidEmailDomain('errorInvalidEmailDomain'),
  accountTypeNotAllowed('errorAccountTypeNotAllowed'),
  accountTypeRequired('errorAccountTypeRequired'),
  fullNameRequired('fullNameRequired'),
  invalidCampus('errorInvalidCampus'),
  invalidPhone('errorInvalidPhone'),
  phoneTaken('errorPhoneTaken'),
  // From submit_for_review: card or selfie not uploaded since the last
  // rejection.
  photosMissing('errorPhotosMissing'),
  // submit_for_review refused because the status is no longer incomplete or
  // rejected; PhotoSubmission re-reads it. pending counts as sent.
  illegalTransition('errorSendFailed'),
  alreadyApproved('errorAlreadyApproved'),
  statusRejected('errorStatusRejected'),
  statusIncomplete('errorStatusIncomplete'),
  // From GoTrue (OTP and password steps).
  invalidCode('errorInvalidCode'),
  tooSoon('errorTooSoon'),
  weakPassword('errorWeakPassword'),
  invalidCredentials('errorInvalidCredentials'),
  // Too many requests from this device (GoTrue's per-IP limit, D-04). Lupa
  // password shows it, so only codes that never depend on the email may map
  // here; the per-email resend limit is tooSoon.
  rateLimited('errorRateLimited'),
  // From approve_verification: decided by another admin meanwhile.
  notPending('errorNotPending'),
  // From reject_verification: rule 9; the form checks it first.
  reasonMissing('errorReasonMissing'),
  // From release_phone: the form checks the note first.
  noteMissing('errorNoteMissing'),
  // From release_phone: the note holds a phone number (D-26) or is too long;
  // the form checks both first.
  noteHasPhone('errorNoteHasPhone'),
  noteTooLong('errorNoteTooLong'),
  // From release_phone: released by another admin meanwhile.
  noPhone('errorNoPhone'),
  // From the review functions: the account is not an admin.
  notAdmin('errorNotAdmin'),
  // From create_listing: the balance ran out meanwhile, or the account is
  // no longer approved or is frozen (the app cannot see freezes).
  noQuota('errorNoQuota'),
  notAllowed('errorNotAllowedToList'),
  // From confirm_payment: the form checks it first.
  invalidAmount('errorInvalidAmount'),
  // From submit_payment, or its unique index when two submits race (D-43).
  paymentPending('errorPaymentPending'),
  // From the order functions (#85).
  listingUnavailable('errorListingUnavailable'),
  ownListing('errorOwnListing'),
  soldOut('errorSoldOut'),
  alreadyOrdered('errorAlreadyOrdered'),
  donationLimit('errorDonationLimit'),
  // Changed by the other party or the timers meanwhile.
  orderTransition('errorOrderTransition'),
  notParty('errorNotParty'),
  codTimeMissing('errorCodTimeMissing'),
  unknown('errorSignupUnknown');

  const SignupError(this.copyKey);

  final String copyKey;
}

/// [code] is the Postgres SQLSTATE or the GoTrue error code, [message] its
/// message.
SignupError signupErrorFrom(String? code, String message) {
  return switch ((code, message)) {
    ('23514', 'invalid_email_domain') => SignupError.invalidEmailDomain,
    ('23514', 'account_type_not_allowed') => SignupError.accountTypeNotAllowed,
    ('23514', 'account_type_required') => SignupError.accountTypeRequired,
    ('23502', 'full_name_required') => SignupError.fullNameRequired,
    ('23514', 'invalid_campus') => SignupError.invalidCampus,
    ('23514', _) when message.contains('profiles_phone_check') =>
      SignupError.invalidPhone,
    ('23505', _) when message.contains('profiles_phone_key') =>
      SignupError.phoneTaken,
    ('23514', 'photos_missing') => SignupError.photosMissing,
    ('23514', 'illegal_status_transition') => SignupError.illegalTransition,
    ('otp_expired', _) => SignupError.invalidCode,
    ('over_email_send_rate_limit', _) => SignupError.tooSoon,
    ('weak_password', _) => SignupError.weakPassword,
    ('invalid_credentials', _) => SignupError.invalidCredentials,
    ('over_request_rate_limit', _) => SignupError.rateLimited,
    ('23514', 'not_pending') => SignupError.notPending,
    ('23514', 'reason_missing') => SignupError.reasonMissing,
    ('23514', 'invalid_amount') => SignupError.invalidAmount,
    ('23514', 'payment_pending') => SignupError.paymentPending,
    ('23505', _) when message.contains('payments_one_pending') =>
      SignupError.paymentPending,
    ('23514', 'note_missing') => SignupError.noteMissing,
    ('23514', 'no_phone') => SignupError.noPhone,
    ('23514', 'note_has_phone') => SignupError.noteHasPhone,
    ('23514', 'note_too_long') => SignupError.noteTooLong,
    ('42501', 'not_admin') => SignupError.notAdmin,
    ('23514', 'no_quota') => SignupError.noQuota,
    ('42501', 'not_allowed') => SignupError.notAllowed,
    ('23514', 'listing_unavailable') => SignupError.listingUnavailable,
    ('23514', 'own_listing') => SignupError.ownListing,
    ('23514', 'sold_out') => SignupError.soldOut,
    ('23514', 'already_ordered') => SignupError.alreadyOrdered,
    ('23505', _) when message.contains('orders_one_running') =>
      SignupError.alreadyOrdered,
    ('23514', 'donation_limit') => SignupError.donationLimit,
    ('23514', 'order_transition') => SignupError.orderTransition,
    ('42501', 'not_party') => SignupError.notParty,
    ('23514', 'cod_time_missing') => SignupError.codTimeMissing,
    _ => SignupError.unknown,
  };
}

/// The wait in GoTrue's "…only request this after N seconds." message.
int? retryAfterSeconds(String message) {
  final match = RegExp(r'after (\d+) seconds?').firstMatch(message);
  return match == null ? null : int.parse(match[1]!);
}
