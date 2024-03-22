module refund::accounting {
    friend refund::refund;
    friend refund::booster;

    /// Contains accounting details relevant to the management of the RefundPool.
    ///
    /// Fields:
    /// - `total_refunded`: The cumulative amount of funds that have been refunded to users. This includes both standard and boosted refunds.
    /// - `total_boosted`: The total amount of funds provided as part of boosted refunds. This figure helps track the additional funds given out as part of special refund conditions, such as the 150% refund scenario.
    /// - `current_liability`: Represents the total amount of funds that the RefundPool is currently obligated to pay out. This includes all unclaimed refunds and is used to manage the financial health and obligations of the pool.
    struct Accounting has store {
        total_to_refund: u64,
        total_raised: u64,
        total_refunded: u64,
        total_raised_for_boost: u64,
        total_boosted: u64,
    }

    public(friend) fun new(): Accounting {
        Accounting {
            total_to_refund: 0,
            total_raised: 0,
            total_refunded: 0,
            total_raised_for_boost: 0,
            total_boosted: 0,
        }
    }

    // === Getters ===
    
    public fun total_to_refund(acc: &Accounting): u64 { acc.total_to_refund }
    public fun total_raised(acc: &Accounting): u64 { acc.total_raised }
    public fun total_refunded(acc: &Accounting): u64 { acc.total_refunded }
    public fun total_raised_for_boost(acc: &Accounting): u64 { acc.total_raised_for_boost }
    public fun total_boosted(acc: &Accounting): u64 { acc.total_boosted }
    public fun current_liabilities(acc: &Accounting): u64 { acc.total_to_refund - acc.total_refunded }

    // === Mutators (Friends) ===

    public(friend) fun total_to_refund_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_to_refund }
    public(friend) fun total_raised_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_raised }
    public(friend) fun total_refunded_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_refunded }
    public(friend) fun total_raised_for_boost_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_raised_for_boost }
    public(friend) fun total_boosted_mut(acc: &mut Accounting): &mut u64 { &mut acc.total_boosted }

    // === Test Functions ===

    #[test_only]
    public fun destroy_for_testing(pool: Accounting): (u64, u64, u64, u64, u64) {
        let Accounting {
            total_to_refund,
            total_raised,
            total_refunded,
            total_raised_for_boost,
            total_boosted,
        } = pool;

        (
            total_to_refund,
            total_raised,
            total_refunded,
            total_raised_for_boost,
            total_boosted,
        )
    }
}