#[test_only]
module refund::refund_tests {
    use std::vector;
    use std::option;
    use sui::test_scenario::{Self as ts, ctx};
    use sui::transfer;
    use sui::balance;
    use sui::table;
    use sui::package::{Self, Publisher};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock;
    use std::option::{some, none};
    use sui::table_vec;
    
    use refund::math::div;
    use refund::accounting::{Self, total_claimed, total_boosted, total_raised, total_raised_for_boost};
    use refund::pool::{Self, funds};
    use refund::refund::{Self, REFUND, RefundPool, accounting, base_pool, booster_pool};
    use refund::booster;
    use refund::test_utils::{
        Self, publisher,
        wallet_1, rinbot_1,
        wallet_2, rinbot_2,
        wallet_3, rinbot_3,
    };
    use refund::fuzzy_unclaimed::{Self, addr, amt};
    use refund::fuzzy_funding;
    use refund::fuzzy_claim;
    

    const FUNDER_1: address = @0x100;
    const FUNDER_2: address = @0x200;
    const FUNDER_3: address = @0x300;

    const FAKE_WALLET: address = @0x99;

    struct FAKE_REFUND has drop {}

    #[test]
    fun test_refund_pool_base() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());

        let clock = clock::create_for_testing(ctx(&mut scenario));
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_2);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_3);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(3_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, wallet_1());
        
        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);
     
        test_utils::claim(&mut refund_pool, wallet_1(), some(2_000), &clock, &mut scenario);
        test_utils::claim(&mut refund_pool, wallet_2(), some(2_000), &clock, &mut scenario);
        test_utils::claim(&mut refund_pool, wallet_3(), some(2_000), &clock, &mut scenario);

        test_utils::destroy_and_check(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    fun test_refund_pool_boosted() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(4_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        booster::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        ts::next_tx(&mut scenario, FUNDER_2);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        booster::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, publisher());

        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);
        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_1(),
            rinbot_1(),
            some(3_000),
            &clock,
            &mut scenario,
        );

        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_2(),
            rinbot_2(),
            some(3_000),
            &clock,
            &mut scenario,
        );

        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_3(),
            rinbot_3(),
            some(3_000),
            &clock,
            &mut scenario,
        );

        test_utils::destroy_and_check(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::booster::EAddressRetrievedBoostCap)]
    fun test_fail_issue_multiple_boost_caps() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(4_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        booster::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        ts::next_tx(&mut scenario, FUNDER_2);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        booster::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, publisher());

        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);
        
        ts::next_tx(&mut scenario, publisher());

        booster::allow_boosted_claim(
            &pub,
            &mut refund_pool,
            wallet_1(),
            rinbot_1(),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, publisher());

        booster::allow_boosted_claim(
            &pub,
            &mut refund_pool,
            wallet_1(),
            FAKE_WALLET,
            ctx(&mut scenario),
        );

        test_utils::destroy_and_check(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidPublisher)]
    fun test_fail_fake_pub_boost() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );
        
        ts::next_tx(&mut scenario, FUNDER_1);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(6_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        booster::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(3_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        ts::next_tx(&mut scenario, wallet_1());

        let fake_pub = package::test_claim<FAKE_REFUND>(FAKE_REFUND {}, ctx(&mut scenario));

        test_utils::claim_boosted(
            &fake_pub,
            &mut refund_pool,
            wallet_1(),
            rinbot_1(),
            none(),
            &clock,
            &mut scenario,
        );

        test_utils::destroy_and_check(refund_pool);
        ts::return_to_address(publisher(), pub);
        transfer::public_transfer(fake_pub, wallet_1());
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidAddress)]
    fun test_fail_fake_wallet() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());

        let clock = clock::create_for_testing(ctx(&mut scenario));
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        ts::next_tx(&mut scenario, FUNDER_2);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );
        
        ts::next_tx(&mut scenario, FUNDER_3);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(3_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );


        ts::next_tx(&mut scenario, FAKE_WALLET);

        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);
        refund::claim_refund(&mut refund_pool, &clock, ctx(&mut scenario));
        // Wrap up testing 
        ts::next_tx(&mut scenario, publisher());

        let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_1());

        assert!(coin::value(&coin_1) == 2_000,0);
        
        coin::burn_for_testing(coin_1);

        test_utils::destroy_and_check(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidTimeoutTimestamp)]
    fun test_fail_start_funding_phase_invalid_timeout() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());

        let clock = clock::create_for_testing(ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1717196401);
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::destroy_for_testing(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ECurrentTimeBeforeTimeout)]
    fun test_fail_start_reclaim_before_timeout() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            3,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);
        clock::set_for_testing(&mut clock, 1706745600);

        refund::start_reclaim_phase(&mut refund_pool, &clock);

        test_utils::destroy_and_check(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::EAddressesAmountsVecLenMismatch)]
    fun test_fail_add_addresses_if_vec_lens_mismatch() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000],
        );

        ts::return_shared(refund_pool);
        ts::return_to_address(publisher(), pub);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidFunder)]
    fun test_fail_start_reclaim_invalid_funder() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            3,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FAKE_WALLET);

        clock::set_for_testing(&mut clock, 1706745601);
        refund::start_reclaim_phase(&mut refund_pool, &clock);

        refund::reclaim_funds(&mut refund_pool, ctx(&mut scenario));

        ts::return_shared(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotFundingPhase)]
    fun test_fail_to_fund_if_add_addresses_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            1,
            none(), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotFundingPhase)]
    fun test_fail_to_fund_if_claim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            3,
            none(), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotFundingPhase)]
    fun test_fail_to_fund_if_reclaim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            4,
            none(), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ERefundPoolHasZeroAddresses)]
    fun test_fail_start_funding_phase_without_addresses() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        let (pub, refund_pool) = refund::empty_for_testing(ctx(&mut scenario));

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        transfer::public_transfer(pub, publisher());
        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotAddressAdditionPhase)]
    fun test_fail_start_funding_phase_if_already_in_claim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        let (pub, refund_pool) = refund::empty_for_testing(ctx(&mut scenario));
        let (
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            _phase,
            timeout_ts,
        ) = refund::destruct_for_testing(refund_pool);

        let refund_pool = refund::new_for_testing(
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            3,
            timeout_ts,
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        transfer::public_transfer(pub, publisher());
        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotAddressAdditionPhase)]
    fun test_fail_start_funding_phase_if_already_in_reclaim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        let (pub, refund_pool) = refund::empty_for_testing(ctx(&mut scenario));
        let (
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            _phase,
            timeout_ts,
        ) = refund::destruct_for_testing(refund_pool);

        let refund_pool = refund::new_for_testing(
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            4,
            timeout_ts,
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            1717196400, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        transfer::public_transfer(pub, publisher());
        refund::destroy_for_testing(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotFundingPhase)]
    fun test_fail_start_claim_phase_if_already_in_reclaim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            4,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);
        clock::set_for_testing(&mut clock, 1706745600);

        refund::start_claim_phase(&mut refund_pool, &clock);

        test_utils::destroy_and_check(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::ENotReclaimPhase)]
    fun test_fail_delete_if_not_reclaim_phase() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            3,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::delete(refund_pool);

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::refund::EPoolFundsNotEmpty)]
    fun test_fails_to_delete_if_funds_not_empty() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));
        
        let refund_pool = refund::new_for_testing(
            test_utils::default_unclaimed(ctx(&mut scenario)),
            test_utils::default_base_pool(ctx(&mut scenario)),
            test_utils::default_boost_pool(ctx(&mut scenario)),
            test_utils::default_accounting(),
            4,
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::delete(refund_pool);

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    fun it_deletes_in_reclaim_phase_and_funds_empty() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        let refund_pool = refund::new_for_testing(
            table::new(ctx(&mut scenario)),
            pool::new_for_testing(balance::zero(), table::new(ctx(&mut scenario))),
            pool::new_for_testing(balance::zero(), table::new(ctx(&mut scenario))),
            accounting::new_for_testing(0, 0, 0, 0, 0),
            4,
            some(2_000),
            ctx(&mut scenario)
        );

        ts::next_tx(&mut scenario, FUNDER_1);

        refund::delete(refund_pool);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    fun fuzzy_test() {
        let scenario = ts::begin(publisher());
        let clock = clock::create_for_testing(ctx(&mut scenario));

        let (unclaimed_vec, unclaimed, total_to_refund_expected) = fuzzy_unclaimed::unclaimed(ctx(&mut scenario));
        let total_raised_expected = total_to_refund_expected;
        let total_raised_boosted_expected = div(total_raised_expected, 2);

        let (funders_vec, funders, funders_boost) = fuzzy_funding::funders(
            total_raised_expected,
            total_raised_boosted_expected,
            ctx(&mut scenario)
        );
        
        let base_pool = pool::new_for_testing(
            balance::create_for_testing(total_raised_expected),
            funders
        );
        
        let boost_pool = pool::new_for_testing(
            balance::create_for_testing(total_raised_boosted_expected),
            funders_boost
        );

        // Act: Initialize the refund pool
        let refund_pool = refund::new_for_testing(
            unclaimed,
            base_pool,
            boost_pool,
            accounting::new_for_testing(
                total_to_refund_expected,
                total_raised_expected,
                0,
                total_raised_boosted_expected,
                0,
            ),
            3, // Claim phase
            some(1706745601), // Thu Feb 01 2024 00:00:01 GMT+0000
            ctx(&mut scenario)
        );

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let claim_status = fuzzy_claim::claim_status(ctx(&mut scenario));
        let claims_len = table_vec::length(&unclaimed_vec);

        while (claims_len > 0) {
            let claim = table_vec::pop_back(&mut unclaimed_vec);
            let status = table_vec::pop_back(&mut claim_status);
            let sender = addr(&claim);

            ts::next_tx(&mut scenario, sender);
            let actual_claim_amount = 0;

            if (status == 1) {
                actual_claim_amount = amt(&claim);
                refund::claim_refund(&mut refund_pool, &clock, ctx(&mut scenario));
            } else if (status == 2) {
                actual_claim_amount = amt(&claim) + div(amt(&claim), 2);
                let cap = booster::new_for_testing(sender, ctx(&mut scenario));

                booster::claim_refund_boosted(cap, &mut refund_pool, sender, &clock, ctx(&mut scenario));
            };

            if (status != 3) {
                ts::next_tx(&mut scenario, sender);
                let funds = ts::take_from_address<Coin<SUI>>(&scenario, sender);
                assert!(coin::value(&funds) == actual_claim_amount, 0);
                ts::return_to_address(sender, funds);
            };

            let remaining_balance = balance::value(funds(base_pool(&refund_pool)));
            let remaining_balance_boost = balance::value(funds(booster_pool(&refund_pool)));

            assert!(total_raised(accounting(&refund_pool)) - total_claimed(accounting(&refund_pool)) == remaining_balance, 0);
            assert!(total_raised_for_boost(accounting(&refund_pool)) - total_boosted(accounting(&refund_pool)) == remaining_balance_boost, 0);

            claims_len = claims_len - 1;
        };

        let remaining_balance = balance::value(funds(base_pool(&refund_pool)));
        let remaining_balance_boost = balance::value(funds(booster_pool(&refund_pool)));

        assert!(remaining_balance == total_raised(accounting(&refund_pool)) - total_claimed(accounting(&refund_pool)), 0);
        assert!(remaining_balance_boost == total_raised_for_boost(accounting(&refund_pool)) - total_boosted(accounting(&refund_pool)), 0);
        assert!(total_claimed(accounting(&refund_pool)) == 6_270_131_423_872, 0);
        assert!(total_boosted(accounting(&refund_pool)) == 1_824_928_799_201, 0);
        assert!(remaining_balance == 4_215_654_554_741, 0);
        assert!(remaining_balance_boost == 3_417_964_190_105, 0);

        // === Reclaiming ===

        clock::set_for_testing(&mut clock, 1706745602);
        refund::start_reclaim_phase(&mut refund_pool, &clock);

        let amounts_to_reclaim = vector[
            182942720828 + 11, // 11 => cumulative rounding error
            21985282120,
            351941327035,
            77885747801,
            46573617051,
            352621509278,
            88053607368,
            209662329842,
            102348830120,
            380035667132,
            215609219698,
            224824821516,
            239065676148,
            373185244269,
            329507530061,
            257138914837,
            5793897510,
            59555184660,
            133566432536,
            265519808774,
            19673198200,
            278163987946,
        ];
        
        let amounts_to_reclaim_boosted = vector[
            267071514862 + 7, // 7 => cumulative rounding error
            170147089332,
            67416403760,
            390140539463,
            10808654707,
            518278712072,
            400343787877,
            491970035970,
            18140699738,
            317886346788,
            282672986623,
            436809771179,
            46277647734,
        ];

        ts::next_tx(&mut scenario, publisher());

        let funders_len = table_vec::length(&funders_vec);

        while (funders_len > 0) {
            let funder = table_vec::pop_back(&mut funders_vec);
            let expected_amount_to_reclaim = vector::pop_back(&mut amounts_to_reclaim);
            ts::next_tx(&mut scenario, funder);

            refund::reclaim_funds(&mut refund_pool, ctx(&mut scenario));
            ts::next_tx(&mut scenario, funder);
            let funds = ts::take_from_address<Coin<SUI>>(&scenario, funder);
            assert!(coin::value(&funds) == expected_amount_to_reclaim, 0);
            coin::burn_for_testing(funds);
            
            // Boost
            if (vector::length(&amounts_to_reclaim_boosted) > 0) {
                let expected_amount_to_reclaim_boosted = vector::pop_back(&mut amounts_to_reclaim_boosted);

                booster::reclaim_funds(&mut refund_pool, ctx(&mut scenario));
                ts::next_tx(&mut scenario, funder);
                let funds = ts::take_from_address<Coin<SUI>>(&scenario, funder);
                assert!(expected_amount_to_reclaim_boosted - coin::value(&funds) <= 1, 0); // 1 ==> rounding error margin
                coin::burn_for_testing(funds);
            };

            funders_len = funders_len - 1;
        };

        table_vec::drop(funders_vec);
        table_vec::drop(claim_status);
        table_vec::drop(unclaimed_vec);
        refund::destroy_for_testing(refund_pool); // todo: checks
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_it_updates_timeout_if_below_minimum_claim_period() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());

        let clock = clock::create_for_testing(ctx(&mut scenario));

        let initial_timeout = 1717196400;
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            initial_timeout, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_2);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_3);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(3_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, wallet_1());


        // initial timeout = 1717196400
        let current_time = 1457996401; // <=> 1717196400 - 259_200_000 + 1
        let new_timeout = current_time + 259_200_000; // <=> current time + 3 days
        clock::set_for_testing(&mut clock, current_time);
        
        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);

        let timeout = *option::borrow(&refund::timeout_ts(&refund_pool));
        assert!(timeout == new_timeout, 0);
     
        refund::destroy_for_testing(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    fun test_it_does_not_update_timeout_if_within_minimum_claim_period_bound() {
        let scenario = ts::begin(publisher());

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, publisher());

        let pub = ts::take_from_address<Publisher>(&scenario, publisher());
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, publisher());

        let clock = clock::create_for_testing(ctx(&mut scenario));

        let initial_timeout = 1717196400;
    
        // The community agrees on a timeout timestamp, which reflects the point
        // from which the funders can recoup the unclaim funds. Sufficient time
        // must pass to allow all affected wallets to claim their refund.
        // Once the community has spent enought time verifying the addresses
        // and we have the OK from the community, the publisher will call:
        refund::start_funding_phase(
            &pub,
            &mut refund_pool,
            initial_timeout, // Fri May 31 2024 23:00:00 GMT+0000
            &clock
        );

        ts::next_tx(&mut scenario, FUNDER_1);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(2_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_2);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(1_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, FUNDER_3);
        refund::fund(
            &mut refund_pool,
            coin::mint_for_testing<SUI>(3_000,ctx(&mut scenario)),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, wallet_1());


        // initial timeout = 1717196400
        let current_time = 1717196400 - 259_200_000 - 1;
        clock::set_for_testing(&mut clock, current_time);
        
        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool, &clock);

        let timeout = *option::borrow(&refund::timeout_ts(&refund_pool));
        assert!(initial_timeout == timeout, 0);
     
        refund::destroy_for_testing(refund_pool);
        ts::return_to_address(publisher(), pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}