/// Rules 10-11: chat messages (D-31, D-37, PRD-katalog 5.8). The backend
/// enforces the length in the messages table and send_message.
library;

/// K-21, in characters (code points, like Postgres char_length).
const maxMessageLength = 1000;

enum MessageError { empty, tooLong }

/// The trimmed text is what gets sent.
MessageError? validateMessage(String text) {
  final length = text.trim().runes.length;
  if (length == 0) return MessageError.empty;
  return length > maxMessageLength ? MessageError.tooLong : null;
}

// Every word pattern has word boundaries (K-20), so "online", "deadline",
// "big" and prices such as "1.500.000" pass.
final _contact = RegExp(
  [
    // 08…, +62… or 62…, 9+ digits, spaces or dashes between them.
    r'(?<![\d+])(?:\+?62|08)(?:[\s-]?\d){7,}',
    r'\b(?:wa|t)\.me\b',
    // Not an email: nothing word-like right before the @.
    r'(?<![\w.])@\w{2,}',
    r'\b(?:wa|whatsapp|line|ig|telegram)\b',
  ].join('|'),
  caseSensitive: false,
);

/// Shows the safety warning before sending; the member may still send.
bool looksLikeContact(String text) => _contact.hasMatch(text);

/// K14 chips. "Penjual" = chats where I am the buyer (5.8).
enum ChatFilter {
  all,
  sellers;

  bool shows({required bool iAmBuyer}) => this == all || iAmBuyer;
}
