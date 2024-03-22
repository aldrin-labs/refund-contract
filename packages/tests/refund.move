#[test_only]
module refund::refund_tests {
    // use std::debug::print;
    use sui::transfer;
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::{Self, Publisher};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock;
    use std::option::{some, none};

    use refund::refund::{Self, REFUND, RefundPool};
    use refund::booster;
    use refund::test_utils::{
        Self, publisher,
        wallet_1, rinbot_1,
        wallet_2, rinbot_2,
        wallet_3, rinbot_3,
    };

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
        refund::start_claim_phase(&mut refund_pool);
     
        test_utils::claim(&mut refund_pool, wallet_1(), some(2_000), &mut scenario);
        test_utils::claim(&mut refund_pool, wallet_2(), some(2_000), &mut scenario);
        test_utils::claim(&mut refund_pool, wallet_3(), some(2_000), &mut scenario);

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
        refund::start_claim_phase(&mut refund_pool);
        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_1(),
            rinbot_1(),
            some(3_000),
            &mut scenario,
        );

        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_2(),
            rinbot_2(),
            some(3_000),
            &mut scenario,
        );

        test_utils::claim_boosted(
            &pub,
            &mut refund_pool,
            wallet_3(),
            rinbot_3(),
            some(3_000),
            &mut scenario,
        );

        // TODO: check that base pool is empty, and that reclaimed boosted funds values are correct

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
        refund::start_claim_phase(&mut refund_pool);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));
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
}