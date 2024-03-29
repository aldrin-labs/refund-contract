module refund::accounting {
    friend refund::refund;
    friend refund::booster;

    /// Tracks financial metrics related to fundraising and refunds.
    ///
    /// Fields:
    /// - `total_to_refund`: The total amount of funds designated for refunds.
    /// - `total_raised`: The total amount of funds raised, including both
    /// standard and boosted fund contributions.
    /// - `total_claimed`: The total amount of funds that have been claimed
    /// as refunds by eligible addresses.
    /// - `total_raised_for_boost`: The total amount of funds raised specifically
    /// for the purpose of providing boosted refunds.
    /// - `total_boosted`: The total amount of funds that have been distributed
    /// as boosted refunds.
    struct Accounting has store {
        total_to_refund: u64,
        total_raised: u64,
        total_claimed: u64,
        total_raised_for_boost: u64,
        total_boosted: u64,
    }

    public(friend) fun new(): Accounting {
        Accounting {
            total_to_refund: 0,
            total_raised: 0,
            total_claimed: 0,
            total_raised_for_boost: 0,
            total_boosted: 0,
        }
    }
    
    public(friend) fun drop(acc: Accounting) {
        let Accounting {
            total_to_refund: _,
            total_raised: _,
            total_claimed: _,
            total_raised_for_boost: _,
            total_boosted: _,
        } = acc;
    }

    // === Getters ===
    
    public fun total_to_refund(acc: &Accounting): u64 { acc.total_to_refund }
    public fun total_raised(acc: &Accounting): u64 { acc.total_raised }
    public fun total_claimed(acc: &Accounting): u64 { acc.total_claimed }
    public fun total_raised_for_boost(acc: &Accounting): u64 { acc.total_raised_for_boost }
    public fun total_boosted(acc: &Accounting): u64 { acc.total_boosted }
    public fun current_liabilities(acc: &Accounting): u64 { acc.total_to_refund - acc.total_claimed }
    public fun total_unclaimed(acc: &Accounting): u64 { acc.total_raised - acc.total_claimed }
    public fun total_unclaimed_boosted(acc: &Accounting): u64 { acc.total_raised_for_boost - acc.total_boosted }

    // === Mutators (Friends) ===

    public(friend) fun total_to_refund_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_to_refund }
    public(friend) fun total_raised_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_raised }
    public(friend) fun total_claimed_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_claimed }
    public(friend) fun total_raised_for_boost_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_raised_for_boost }
    public(friend) fun total_boosted_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_boosted }

    // === Test Functions ===

    #[test_only]
    public fun new_for_testing(
        total_to_refund: u64,
        total_raised: u64,
        total_claimed: u64,
        total_raised_for_boost: u64,
        total_boosted: u64,
    ): Accounting {
        Accounting {
            total_to_refund,
            total_raised,
            total_claimed,
            total_raised_for_boost,
            total_boosted,
        }
    }

    #[test_only]
    public fun destroy_for_testing(pool: Accounting) {
        let Accounting {
            total_to_refund: _,
            total_raised: _,
            total_claimed: _,
            total_raised_for_boost: _,
            total_boosted: _,
        } = pool;
    }
    
    #[test_only]
    public fun destruct_for_testing(pool: Accounting): (u64, u64, u64, u64, u64) {
        let Accounting {
            total_to_refund,
            total_raised,
            total_claimed,
            total_raised_for_boost,
            total_boosted,
        } = pool;

        (
            total_to_refund,
            total_raised,
            total_claimed,
            total_raised_for_boost,
            total_boosted,
        )
    }
}