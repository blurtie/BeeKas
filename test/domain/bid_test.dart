import 'package:beekas/domain/bid.dart';
import 'package:flutter_test/flutter_test.dart';

BidSummary _summary({
  int bidders = 0,
  List<int> top = const [],
  int? mine,
  int? rank,
  int stock = 1,
}) => (
  endsAt: null,
  bidders: bidders,
  topAmounts: top,
  myAmount: mine,
  myRank: rank,
  stockLeft: stock,
);

void main() {
  group('bidProblem (D-46)', () {
    test('a bid is at least 1 token', () {
      expect(bidProblem(amount: null, current: null, balance: 5), BidProblem.tooLow);
      expect(bidProblem(amount: 0, current: null, balance: 5), BidProblem.tooLow);
      expect(bidProblem(amount: 1, current: null, balance: 5), isNull);
    });

    test('bids only go up', () {
      expect(bidProblem(amount: 3, current: 3, balance: 5), BidProblem.notRaised);
      expect(bidProblem(amount: 2, current: 3, balance: 5), BidProblem.notRaised);
      expect(bidProblem(amount: 4, current: 3, balance: 5), isNull);
    });

    test('raising needs only the difference in tokens', () {
      expect(bidProblem(amount: 6, current: 3, balance: 3), isNull);
      expect(bidProblem(amount: 7, current: 3, balance: 3), BidProblem.notEnoughTokens);
      expect(bidProblem(amount: 4, current: null, balance: 3), BidProblem.notEnoughTokens);
      expect(tokensToHold(6, 3), 3);
      expect(tokensToHold(2, null), 2);
    });
  });

  group('winning', () {
    test('the top bids up to the units left win', () {
      expect(isWinning(1, 1), isTrue);
      expect(isWinning(2, 1), isFalse);
      expect(isWinning(2, 2), isTrue);
      expect(isWinning(null, 3), isFalse);
    });

    test('suggested bid', () {
      expect(suggestedBid(_summary()), 1, reason: 'nobody bid yet');
      expect(suggestedBid(_summary(bidders: 1, top: [5])), 6, reason: 'beat the top');
      expect(suggestedBid(_summary(bidders: 1, top: [5], stock: 2)), 1,
          reason: 'a unit is still free');
      expect(suggestedBid(_summary(bidders: 2, top: [5, 3], mine: 3, rank: 2)), 6,
          reason: 'beat the one ahead');
      expect(suggestedBid(_summary(bidders: 2, top: [5, 3], mine: 5, rank: 1)), 6,
          reason: 'already winning: only a raise');
      expect(suggestedBid(_summary(bidders: 3, top: [9, 5, 2], stock: 2)), 6);
    });
  });

  test('the window counts down to zero', () {
    final end = DateTime.utc(2026, 11, 24, 9);
    expect(remainingBidWindow(end, DateTime.utc(2026, 11, 24, 8)), const Duration(hours: 1));
    expect(remainingBidWindow(end, DateTime.utc(2026, 11, 24, 10)), Duration.zero);
    expect(isBiddingOver(null, DateTime.utc(2030)), isFalse);
    expect(isBiddingOver(end, end), isTrue);
  });
}
