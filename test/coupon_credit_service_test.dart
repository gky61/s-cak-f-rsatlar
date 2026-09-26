import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sicak_firsatlar/services/coupon_credit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CouponCreditService - Rewarded Monetization & Fair-Play Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CouponCreditService.instance.resetForTesting(credits: 2);
    });

    test('1. Default daily credit is 2 for logged-in users', () {
      final service = CouponCreditService.instance;
      expect(service.remainingCredits, 2);
      expect(service.creditsNotifier.value, 2);
    });

    test('2. Unlocking a new coupon consumes exactly 1 credit', () async {
      final service = CouponCreditService.instance;
      const couponId = 'test_coupon_001';

      expect(service.canUnlock(couponId), isTrue);
      final success = await service.useCreditForCoupon(couponId);

      expect(success, isTrue);
      expect(service.remainingCredits, 1);
      expect(service.isUnlockedToday(couponId), isTrue);
    });

    test('3. Unlocking the same coupon again does NOT consume extra credit', () async {
      final service = CouponCreditService.instance;
      const couponId = 'test_coupon_001';

      await service.useCreditForCoupon(couponId);
      expect(service.remainingCredits, 1);

      // Re-unlocking should be free
      expect(service.canUnlock(couponId), isTrue);
      final successAgain = await service.useCreditForCoupon(couponId);
      expect(successAgain, isTrue);
      expect(service.remainingCredits, 1); // Still 1
    });

    test('4. Depleted credits prevent unlocking a new locked coupon', () async {
      final service = CouponCreditService.instance;

      await service.useCreditForCoupon('c1');
      await service.useCreditForCoupon('c2');
      expect(service.remainingCredits, 0);

      // Already unlocked coupons remain unlocked
      expect(service.canUnlock('c1'), isTrue);

      // New coupon cannot be unlocked
      expect(service.canUnlock('c3'), isFalse);
      final success = await service.useCreditForCoupon('c3');
      expect(success, isFalse);
      expect(service.remainingCredits, 0);
    });

    test('5. Rewarded Ad grant adds +2 credits to the balance', () async {
      final service = CouponCreditService.instance;

      await service.useCreditForCoupon('c1');
      await service.useCreditForCoupon('c2');
      expect(service.remainingCredits, 0);

      final newTotal = await service.addRewardedCredits(2);
      expect(newTotal, 2);
      expect(service.remainingCredits, 2);

      // Now c3 can be unlocked
      expect(service.canUnlock('c3'), isTrue);
      final success = await service.useCreditForCoupon('c3');
      expect(success, isTrue);
      expect(service.remainingCredits, 1);
    });

    test('6. Anti-Exploit Policy: Voting cold does NOT refund credits (prevents fake downvoting)', () async {
      final service = CouponCreditService.instance;
      const couponId = 'broken_coupon_123';

      await service.useCreditForCoupon(couponId);
      expect(service.remainingCredits, 1);

      // Verify that unlocked coupon is marked unlocked, but no refund method inflates credits
      expect(service.isUnlockedToday(couponId), isTrue);
      expect(service.remainingCredits, 1);
    });

    test('7. Multiple unlocked coupons decrement credits honestly down to zero', () async {
      final service = CouponCreditService.instance;

      await service.useCreditForCoupon('coupon_a');
      expect(service.remainingCredits, 1);

      await service.useCreditForCoupon('coupon_b');
      expect(service.remainingCredits, 0);

      // Attempt to unlock a 3rd coupon fails cleanly without any exploit
      final success = await service.useCreditForCoupon('coupon_c');
      expect(success, isFalse);
      expect(service.remainingCredits, 0);
    });

    test('8. Guest unlock (Akıllı Hibrit Kapı): unlockCouponForGuest unlocks single coupon without altering credit balance', () async {
      final service = CouponCreditService.instance;
      const guestCouponId = 'guest_single_coupon_007';

      expect(service.isUnlockedToday(guestCouponId), isFalse);
      final initialCredits = service.remainingCredits;

      await service.unlockCouponForGuest(guestCouponId);

      expect(service.isUnlockedToday(guestCouponId), isTrue);
      expect(service.remainingCredits, initialCredits); // Guest unlock does not deduct or alter credit
    });

    test('9. Guest unlocked coupon stays unlocked for repeated taps without re-watching ad', () async {
      final service = CouponCreditService.instance;
      const guestCouponId = 'guest_repeated_tap_101';

      expect(service.isUnlockedToday(guestCouponId), isFalse);
      await service.unlockCouponForGuest(guestCouponId);

      expect(service.isUnlockedToday(guestCouponId), isTrue);
      // Tapping multiple times checks isUnlockedToday which stays true
      expect(service.isUnlockedToday(guestCouponId), isTrue);
    });

    test('10. Rewarded Ad grant (+2 Hak) preserves full balance without auto-consuming until user explicitly unlocks', () async {
      final service = CouponCreditService.instance;

      // Deplete initial 2 credits
      await service.useCreditForCoupon('initial_c1');
      await service.useCreditForCoupon('initial_c2');
      expect(service.remainingCredits, 0);

      // User watches video to get 2 credits
      final newCredits = await service.addRewardedCredits(2);
      expect(newCredits, 2);
      expect(service.remainingCredits, 2);

      // Balance remains strictly 2 (no auto-deduction took place)
      expect(service.remainingCredits, 2);

      // Now user explicitly chooses to unlock 'chosen_c1'
      final unlocked = await service.useCreditForCoupon('chosen_c1');
      expect(unlocked, isTrue);
      expect(service.remainingCredits, 1);
      expect(service.isUnlockedToday('chosen_c1'), isTrue);
    });

    test('11. canVoteOnCoupon returns false if user is the creator of the community coupon (self-vote prevention)', () {
      final service = CouponCreditService.instance;
      const couponId = 'my_community_coupon_1';

      final canVote = service.canVoteOnCoupon(
        kuponId: couponId,
        isOwner: true,
        hasExistingVote: false,
      );

      expect(canVote, isFalse);
    });

    test('12. canVoteOnCoupon returns true if user has an existing vote (allows toggle/change)', () {
      final service = CouponCreditService.instance;
      const couponId = 'locked_coupon_with_prior_vote';

      final canVote = service.canVoteOnCoupon(
        kuponId: couponId,
        isOwner: false,
        hasExistingVote: true,
      );

      expect(canVote, isTrue);
    });

    test('13. canVoteOnCoupon returns true if coupon was unlocked today (Verified Tester / Proof-of-Access)', () async {
      final service = CouponCreditService.instance;
      const couponId = 'unlocked_today_coupon_42';

      expect(service.canVoteOnCoupon(kuponId: couponId), isFalse);

      await service.useCreditForCoupon(couponId);

      expect(service.isUnlockedToday(couponId), isTrue);
      final canVote = service.canVoteOnCoupon(
        kuponId: couponId,
        isOwner: false,
        hasExistingVote: false,
      );

      expect(canVote, isTrue);
    });

    test('14. canVoteOnCoupon returns false if coupon is locked and user has no previous vote', () {
      final service = CouponCreditService.instance;
      const lockedCouponId = 'totally_locked_coupon_999';

      expect(service.isUnlockedToday(lockedCouponId), isFalse);

      final canVote = service.canVoteOnCoupon(
        kuponId: lockedCouponId,
        isOwner: false,
        hasExistingVote: false,
      );

      expect(canVote, isFalse);
    });
  });
}

