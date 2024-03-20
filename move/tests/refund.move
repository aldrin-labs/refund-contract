#[test_only]
module refund::refund_tests {
    use std::debug::print;
    use sui::transfer;
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::{Self, Publisher};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock;
    
    use refund::refund::{Self, REFUND, RefundPool};
    use refund::booster;
    use refund::test_utils::{
        wallet_1, pubkey_1, rinbot_1, sig_1,
        wallet_2, pubkey_2, rinbot_2, sig_2,
        wallet_3, pubkey_3, rinbot_3, sig_3,
    };

    const PUBLISHER: address = @0x1000;

    const FUNDER_1: address = @0x100;
    const FUNDER_2: address = @0x200;
    const FUNDER_3: address = @0x300;

    const FAKE_WALLET: address = @0x99;
    const FAKE_ALDRIN: address = @0x0;

    struct FAKE_REFUND has drop {}
    
    #[test]
    fun test_refund_pool_base() {
        let scenario = ts::begin(PUBLISHER);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, PUBLISHER);

        let pub = ts::take_from_address<Publisher>(&scenario, PUBLISHER);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, PUBLISHER);

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


        ts::next_tx(&mut scenario, wallet_1(), );

        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::next_tx(&mut scenario, wallet_2());
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::next_tx(&mut scenario, wallet_3());
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        // Wrap up testing 
        ts::next_tx(&mut scenario, PUBLISHER);

        let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_1());
        let coin_2 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_2());
        let coin_3 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_3());

        assert!(coin::value(&coin_1) == 2_000,0);
        assert!(coin::value(&coin_2) == 2_000,0);
        assert!(coin::value(&coin_3) == 2_000,0);
        
        coin::burn_for_testing(coin_1);
        coin::burn_for_testing(coin_2);
        coin::burn_for_testing(coin_3);

        ts::return_shared(refund_pool);
        ts::return_to_address(PUBLISHER, pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    fun test_refund_pool_boosted() {
        let scenario = ts::begin(PUBLISHER);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, PUBLISHER);

        let pub = ts::take_from_address<Publisher>(&scenario, PUBLISHER);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        // 1. Phanse 0: Add affected addresses to refund pool
        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[wallet_1(), wallet_2(), wallet_3()],
            vector[2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, PUBLISHER);
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

        ts::next_tx(&mut scenario, PUBLISHER);

        // Permissionless endpoint to transition to claim phase
        refund::start_claim_phase(&mut refund_pool);
        booster::claim_refund_boosted(
            &pub,
            &mut refund_pool,
            wallet_1(),
            pubkey_1(),
            rinbot_1(),
            sig_1(),
            ctx(&mut scenario),
        );

        ts::next_tx(&mut scenario, PUBLISHER);

        // // Permissionless endpoint to transition to claim phase
        // refund::start_claim_phase(&mut refund_pool);
        // booster::claim_refund_boosted(
        //     &pub,
        //     &mut refund_pool,
        //     wallet_2(),
        //     pubkey_2(),
        //     rinbot_2(),
        //     sig_2(),
        //     ctx(&mut scenario),
        // );
        // ts::next_tx(&mut scenario, PUBLISHER);

        // // Permissionless endpoint to transition to claim phase
        // refund::start_claim_phase(&mut refund_pool);
        // booster::claim_refund_boosted(
        //     &pub,
        //     &mut refund_pool,
        //     wallet_3(),
        //     pubkey_3(),
        //     rinbot_3(),
        //     sig_2(),
        //     ctx(&mut scenario),
        // );

        // clock::set_for_testing(&mut clock, 1717196400);
        // booster::reclaim_fund(&mut refund_pool, ctx(&mut scenario));

        // // Wrap up testing

        // ts::next_tx(&mut scenario, PUBLISHER);

        // // TODO: check that base pool is empty, and that reclaimed boosted funds values are correct
        // let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_1());
        // let coin_2 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_2());
        // let coin_3 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_3());

        // assert!(coin::value(&coin_1) == 2_500,0);
        // assert!(coin::value(&coin_2) == 2_500,0);
        // assert!(coin::value(&coin_3) == 2_000,0);
        
        // coin::burn_for_testing(coin_1);
        // coin::burn_for_testing(coin_2);
        // coin::burn_for_testing(coin_3);

        ts::return_shared(refund_pool);
        ts::return_to_address(PUBLISHER, pub);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }


    // #[test]
    // #[expected_failure(abort_code = refund::refund::EInvalidPublisher)]
    // fun test_fail_fake_boost() {
    //     let scenario = ts::begin(ALDRIN);

    //     // Act: Initialize the refund pool
    //     let otw = refund::get_otw_for_testing();
    //     refund::init_test(otw, ctx(&mut scenario));

    //     // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
    //     // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
    //     // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
    //     ts::next_tx(&mut scenario, ALDRIN);

    //     let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
    //     assert!(package::from_package<REFUND>(&pub), 0);

    //     let refund_pool = ts::take_shared<RefundPool>(&scenario);

    //     refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

    //     refund::add_addresses(
    //         &pub,
    //         &mut refund_pool,
    //         vector[wallet_1(), wallet_2(), wallet_3(), WALLET_4, WALLET_5],
    //         vector[2_000, 2_000, 2_000, 2_000, 2_000],
    //     );

    //     ts::next_tx(&mut scenario, wallet_1());

    //     let fake_pub = package::test_claim<FAKE_REFUND>(FAKE_REFUND {}, ctx(&mut scenario));
    //     refund::claim_refund_boosted(&fake_pub, &mut refund_pool, wallet_1(), wallet_1(), ctx(&mut scenario));

    //     ts::next_tx(&mut scenario, ALDRIN);
    //     let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, wallet_1());

    //     assert!(coin::value(&coin_1) == 3_000,0);
    //     coin::burn_for_testing(coin_1);

    //     ts::return_shared(refund_pool);
    //     ts::return_to_address(ALDRIN, pub);
    //     transfer::public_transfer(fake_pub, wallet_1());
    //     ts::end(scenario);
    // }
    
    // #[test]
    // #[expected_failure(abort_code = refund::refund::EInvalidAddress)]
    // fun test_fail_fake_wallet() {
    //     let scenario = ts::begin(ALDRIN);

    //     // Act: Initialize the refund pool
    //     let otw = refund::get_otw_for_testing();
    //     refund::init_test(otw, ctx(&mut scenario));

    //     // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
    //     // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
    //     // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
    //     ts::next_tx(&mut scenario, ALDRIN);

    //     let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
    //     assert!(package::from_package<REFUND>(&pub), 0);

    //     let refund_pool = ts::take_shared<RefundPool>(&scenario);

    //     refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

    //     refund::add_addresses(
    //         &pub,
    //         &mut refund_pool,
    //         vector[wallet_1(), wallet_2(), wallet_3(), WALLET_4, WALLET_5],
    //         vector[2_000, 2_000, 2_000, 2_000, 2_000],
    //     );

    //     ts::next_tx(&mut scenario, FAKE_WALLET);
    //     refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

    //     ts::return_shared(refund_pool);
    //     ts::return_to_address(ALDRIN, pub);
    //     ts::end(scenario);
    // }
    
    // #[test]
    // #[expected_failure(abort_code = refund::refund::EInvalidPublisher)]
    // fun test_fail_fake_aldrin() {
    //     let scenario = ts::begin(ALDRIN);

    //     // Act: Initialize the refund pool
    //     let otw = refund::get_otw_for_testing();
    //     refund::init_test(otw, ctx(&mut scenario));

    //     // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
    //     // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
    //     // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
    //     ts::next_tx(&mut scenario, ALDRIN);

    //     let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
    //     assert!(package::from_package<REFUND>(&pub), 0);

    //     let refund_pool = ts::take_shared<RefundPool>(&scenario);

    //     refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

    //     ts::return_to_address(ALDRIN, pub);
    //     ts::next_tx(&mut scenario, FAKE_ALDRIN);
        
    //     let fake_pub = package::test_claim<FAKE_REFUND>(FAKE_REFUND {}, ctx(&mut scenario));

    //     refund::add_addresses(
    //         &fake_pub,
    //         &mut refund_pool,
    //         vector[FAKE_WALLET],
    //         vector[10_000],
    //     );

    //     ts::next_tx(&mut scenario, FAKE_WALLET);
    //     refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

    //     ts::return_shared(refund_pool);
    //     transfer::public_transfer(fake_pub, FAKE_ALDRIN);
    //     ts::end(scenario);
    // }
}