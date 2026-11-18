/// D-46: donations go to the highest token bids. A token is one unit of the
/// listing quota balance. The backend enforces the same in place_bid and
/// close_donation_bids.
library;

/// The fewest tokens a bid may hold.
const minBid = 1;

/// The first bid on a donation opens a window this long.
const bidWindow = Duration(hours: 24);

/// What listing_bids answers. [topAmounts] holds up to 5 amounts, highest
/// first, without names. [myRank] is 1-based, null without a bid.
/// [endsAt] is null until someone bids.
typedef BidSummary = ({
  DateTime? endsAt,
  int bidders,
  List<int> topAmounts,
  int? myAmount,
  int? myRank,
  int stockLeft,
});

enum BidProblem {
  /// Under [minBid].
  tooLow,

  /// Not above the member's own bid: bids only go up.
  notRaised,

  /// The extra tokens are more than the balance.
  notEnoughTokens,
}

/// Why a bid of [amount] tokens in total cannot be sent, or null when it
/// can. [current] is the member's bid so far; raising holds only the
/// difference.
BidProblem? bidProblem({
  required int? amount,
  required int? current,
  required int balance,
}) {
  if (amount == null || amount < minBid) return BidProblem.tooLow;
  final extra = tokensToHold(amount, current);
  if (extra < 1) return BidProblem.notRaised;
  if (extra > balance) return BidProblem.notEnoughTokens;
  return null;
}

/// The tokens a bid of [amount] in total takes from the balance now.
int tokensToHold(int amount, int? current) => amount - (current ?? 0);

/// Whether a bid at [rank] would get a unit if the window closed now.
bool isWinning(int? rank, int units) => rank != null && rank <= units;

/// The least total that would win now (ties go to the earlier bid, so one
/// more than the last winning amount), never below [minBid] or the
/// member's own bid + 1.
int suggestedBid(BidSummary s) {
  final floor = (s.myAmount ?? 0) + 1;
  if (isWinning(s.myRank, s.stockLeft)) return floor;
  final units = s.stockLeft < 1 ? 1 : s.stockLeft;
  final others = s.bidders - (s.myRank == null ? 0 : 1);
  if (others < units) return floor < minBid ? minBid : floor;
  // The amount at the last winning place, among the ones listed.
  final i = units - 1;
  final line = i < s.topAmounts.length ? s.topAmounts[i] : s.topAmounts.last;
  return line + 1 > floor ? line + 1 : floor;
}

Duration remainingBidWindow(DateTime endsAt, DateTime now) {
  final left = endsAt.difference(now);
  return left.isNegative ? Duration.zero : left;
}

bool isBiddingOver(DateTime? endsAt, DateTime now) =>
    endsAt != null && !now.isBefore(endsAt);
