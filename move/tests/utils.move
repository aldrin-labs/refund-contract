#[test_only]
module refund::test_utils {
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::Publisher;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::option::{Self, Option, is_some, borrow};
    use sui::table;
    use sui::balance;

    use refund::pool;
    use refund::accounting;
    use refund::refund::{Self, RefundPool};
    use refund::booster::{Self, BoostedClaimCap};

    public fun claim_boosted(
        pub: &Publisher,
        pool: &mut RefundPool,
        affected_address: address,
        new_address: address,
        amt_check: Option<u64>,
        scenario: &mut ts::Scenario,
    ) {
        ts::next_tx(scenario, publisher());
        let amt = refund::amount_to_claim_boosted(pool, affected_address);

        if (is_some(&amt_check)) {
            assert!(amt_check == amt, 0);
        };

        booster::allow_boosted_claim(
            pub,
            pool,
            affected_address,
            new_address,
            ctx(scenario),
        );

        ts::next_tx(scenario, affected_address);
        let boost_cap = ts::take_from_address<BoostedClaimCap>(scenario, affected_address);

        booster::claim_refund_boosted(
            boost_cap,
            pool,
            ctx(scenario),
        );

        ts::next_tx(scenario, new_address);
        let funds = ts::take_from_address<Coin<SUI>>(scenario, new_address);
        assert!(coin::value(&funds) == *borrow(&amt), 0);

        ts::return_to_address(new_address, funds);
    }
    
    public fun claim(
        pool: &mut RefundPool,
        affected_address: address,
        amt_check: Option<u64>,
        scenario: &mut ts::Scenario,
    ) {
        ts::next_tx(scenario, affected_address);
        let amt = refund::amount_to_claim(pool, affected_address);

        if (is_some(&amt_check)) {
            assert!(amt_check == amt, 0);
        };

        refund::claim_refund(
            pool,
            ctx(scenario),
        );

        ts::next_tx(scenario, affected_address);
        let funds = ts::take_from_address<Coin<SUI>>(scenario, affected_address);
        assert!(coin::value(&funds) == *borrow(&amt), 0);

        ts::return_to_address(affected_address, funds);
    }

    public fun destroy_and_check(pool: RefundPool) {
        let (
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            phase,
            timeout_ts,
        ) = refund::destroy_for_testing(pool);

        let (base_funds, base_funders) = pool::destroy_for_testing(base_pool);
        let (boost_funds, boost_funders) = pool::destroy_for_testing(booster_pool);
        let (
            total_to_refund,
            total_raised,
            total_refunded,
            total_raised_for_boost,
            total_boosted,
        ) = accounting::destroy_for_testing(accounting);

        option::destroy_some(timeout_ts);
        table::drop(base_funders);
        table::drop(boost_funders);

        assert!(table::is_empty(&unclaimed), 0);
        assert!(balance::value(&base_funds) == 0, 0);
        assert!(balance::value(&boost_funds) == 0, 0);
        assert!(total_to_refund == total_raised, 0);
        assert!(total_refunded == total_raised, 0);
        assert!(total_raised_for_boost == total_boosted, 0);
        assert!((phase == 4 || phase == 3), 0);

        table::drop(unclaimed);
        balance::destroy_for_testing(base_funds);
        balance::destroy_for_testing(boost_funds);
    }

    // === Addresses ===

    public fun publisher(): address { @0x1000 }
    public fun wallet_1(): address { @0x470a964de814fec28fa62b3c84114d50811f1f29980cec9a4785342be2a4ce75 }
    public fun wallet_2(): address { @0x0bcc9c49c4ff59aabc2f2e5067f025564897ae680e8abdadfd16943b68959353 }
    public fun wallet_3(): address { @0xccbf9ffda2a74047719f5aec75d56223f4699e5d6f7ac2161df1b9329e6b75f2 }
    public fun rinbot_1(): address { @0x4bd52e3d5397988891c56106769785c8d5eda6bd28d103c98a6ecad0a87b0255 }
    public fun rinbot_2(): address { @0xaf6d95bb9793f7e1ab8d1816c490ac78217e2865221704db490527b81948fe58 }
    public fun rinbot_3(): address { @0x33e2879fae9780b52ec5c279d905a7ab721173de3eb215b82527c9a3d9ded527 }
}

