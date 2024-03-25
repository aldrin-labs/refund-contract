#[test_only]
module refund::test_utils {
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::Publisher;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::option::{Self, Option, is_some, borrow, some};
    use sui::table::{Self, Table};
    use sui::balance;
    use sui::tx_context::TxContext;
    use std::vector;

    use refund::pool::{Self, Pool};
    use refund::accounting::{Self, Accounting};
    use refund::refund::{Self, RefundPool};
    use refund::booster::{Self, BoostedClaimCap};

    const FUNDER_1: address = @0x100;
    const FUNDER_2: address = @0x200;
    const FUNDER_3: address = @0x300;

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
        ) = refund::destruct_for_testing(pool);

        let (base_funds, base_funders) = pool::destruct_for_testing(base_pool);
        let (boost_funds, boost_funders) = pool::destruct_for_testing(booster_pool);
        let (
            total_to_refund,
            total_raised,
            total_refunded,
            total_raised_for_boost,
            total_boosted,
        ) = accounting::destruct_for_testing(accounting);

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

    public fun create_default_phase_4(
        ctx: &mut TxContext
    ): RefundPool {
        refund::new_for_testing(
            default_unclaimed(ctx),
            default_base_pool(ctx),
            default_boost_pool(ctx),
            default_accounting(),
            4,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx
        )
    }

    public fun default_accounting(): Accounting {
        accounting::new_for_testing(
            6_000, // total_to_refund
            6_000, // total_raised
            3_000, // total_claimed
            3_000, // total_raised_for_boost
            1_500, // total_boosted
        )
    }

    public fun default_unclaimed(ctx: &mut TxContext): Table<address, u64> {
        let addresses = vector[wallet_1(), wallet_2(), wallet_3()];
        let amounts = vector[2_000, 2_000, 2_000];

        new_table(addresses, amounts, ctx)
    }
    
    public fun default_base_pool(ctx: &mut TxContext): Pool {
        let addresses = vector[FUNDER_1, FUNDER_2, FUNDER_3];
        let amounts = vector[2_000, 1_000, 3_000];

        let funders = new_table(addresses, amounts, ctx);

        pool::new_for_testing(
            balance::create_for_testing<SUI>(3_000), funders
        )
    }
    
    public fun default_boost_pool(ctx: &mut TxContext): Pool {
        let addresses = vector[FUNDER_1, FUNDER_2, FUNDER_3];
        let amounts = vector[1_000, 500, 1_500];

        let funders = new_table(addresses, amounts, ctx);

        pool::new_for_testing(
            balance::create_for_testing<SUI>(1_500), funders
        )
    }
    
    public fun new_table(
        addresses: vector<address>,
        amounts: vector<u64>,
        ctx: &mut TxContext
    ): Table<address, u64> {
        let table_ = table::new(ctx);

        let len = vector::length(&addresses);

        while (len > 0) {
            let amount = vector::pop_back(&mut amounts);

            table::add(
                &mut table_,
                vector::pop_back(&mut addresses),
                amount,
            );

            len = len - 1;
        };

        vector::destroy_empty(addresses);
        vector::destroy_empty(amounts);

        table_
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
