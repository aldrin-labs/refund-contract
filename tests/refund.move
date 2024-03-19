module refund::refund_tests {
    use sui::transfer;
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::{Self, Publisher};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    
    use refund::refund::{Self, REFUND, RefundPool};

    const ALDRIN: address = @0x0;
    const WALLET_1: address = @0x1;
    const WALLET_2: address = @0x2;
    const WALLET_3: address = @0x3;
    const WALLET_4: address = @0x4;
    const WALLET_5: address = @0x5;
    
    const RINBOT_1: address = @0x10;
    const RINBOT_2: address = @0x20;
    const RINBOT_3: address = @0x30;
    const RINBOT_4: address = @0x40;
    const RINBOT_5: address = @0x50;

    const FAKE_WALLET: address = @0x99;
    const FAKE_ALDRIN: address = @0x0;

    struct FAKE_REFUND has drop {}
    
    #[test]
    fun test_refund_pool() {
        let scenario = ts::begin(ALDRIN);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, ALDRIN);

        let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[WALLET_1, WALLET_2, WALLET_3, WALLET_4, WALLET_5],
            vector[2_000, 2_000, 2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, WALLET_1);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::next_tx(&mut scenario, WALLET_2);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::next_tx(&mut scenario, WALLET_3);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, WALLET_4);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, WALLET_5);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::next_tx(&mut scenario, ALDRIN);
        let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_1);
        let coin_2 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_2);
        let coin_3 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_3);
        let coin_4 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_4);
        let coin_5 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_5);

        assert!(coin::value(&coin_1) == 2_000,0);
        assert!(coin::value(&coin_2) == 2_000,0);
        assert!(coin::value(&coin_3) == 2_000,0);
        assert!(coin::value(&coin_4) == 2_000,0);
        assert!(coin::value(&coin_5) == 2_000,0);
        
        coin::burn_for_testing(coin_1);
        coin::burn_for_testing(coin_2);
        coin::burn_for_testing(coin_3);
        coin::burn_for_testing(coin_4);
        coin::burn_for_testing(coin_5);

        ts::return_shared(refund_pool);
        ts::return_to_address(ALDRIN, pub);
        ts::end(scenario);
    }
    
    #[test]
    fun test_refund_pool_boosted() {
        let scenario = ts::begin(ALDRIN);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, ALDRIN);

        let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(15_000, ctx(&mut scenario)));

        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[WALLET_1, WALLET_2, WALLET_3, WALLET_4, WALLET_5],
            vector[2_000, 2_000, 2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, ALDRIN);
        refund::claim_refund_boosted(&pub, &mut refund_pool, WALLET_1, RINBOT_1, ctx(&mut scenario));
        refund::claim_refund_boosted(&pub, &mut refund_pool, WALLET_2, RINBOT_2, ctx(&mut scenario));
        refund::claim_refund_boosted(&pub, &mut refund_pool, WALLET_3, RINBOT_3, ctx(&mut scenario));
        refund::claim_refund_boosted(&pub, &mut refund_pool, WALLET_4, RINBOT_4, ctx(&mut scenario));
        refund::claim_refund_boosted(&pub, &mut refund_pool, WALLET_5, RINBOT_5, ctx(&mut scenario));

        ts::next_tx(&mut scenario, ALDRIN);
        let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, RINBOT_1);
        let coin_2 = ts::take_from_address<Coin<SUI>>(&scenario, RINBOT_2);
        let coin_3 = ts::take_from_address<Coin<SUI>>(&scenario, RINBOT_3);
        let coin_4 = ts::take_from_address<Coin<SUI>>(&scenario, RINBOT_4);
        let coin_5 = ts::take_from_address<Coin<SUI>>(&scenario, RINBOT_5);

        assert!(coin::value(&coin_1) == 3_000,0);
        assert!(coin::value(&coin_2) == 3_000,0);
        assert!(coin::value(&coin_3) == 3_000,0);
        assert!(coin::value(&coin_4) == 3_000,0);
        assert!(coin::value(&coin_5) == 3_000,0);
        
        coin::burn_for_testing(coin_1);
        coin::burn_for_testing(coin_2);
        coin::burn_for_testing(coin_3);
        coin::burn_for_testing(coin_4);
        coin::burn_for_testing(coin_5);

        ts::return_shared(refund_pool);
        ts::return_to_address(ALDRIN, pub);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidPublisher)]
    fun test_fail_fake_boost() {
        let scenario = ts::begin(ALDRIN);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, ALDRIN);

        let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[WALLET_1, WALLET_2, WALLET_3, WALLET_4, WALLET_5],
            vector[2_000, 2_000, 2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, WALLET_1);

        let fake_pub = package::test_claim<FAKE_REFUND>(FAKE_REFUND {}, ctx(&mut scenario));
        refund::claim_refund_boosted(&fake_pub, &mut refund_pool, WALLET_1, WALLET_1, ctx(&mut scenario));

        ts::next_tx(&mut scenario, ALDRIN);
        let coin_1 = ts::take_from_address<Coin<SUI>>(&scenario, WALLET_1);

        assert!(coin::value(&coin_1) == 3_000,0);
        coin::burn_for_testing(coin_1);

        ts::return_shared(refund_pool);
        ts::return_to_address(ALDRIN, pub);
        transfer::public_transfer(fake_pub, WALLET_1);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidAddress)]
    fun test_fail_fake_wallet() {
        let scenario = ts::begin(ALDRIN);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, ALDRIN);

        let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

        refund::add_addresses(
            &pub,
            &mut refund_pool,
            vector[WALLET_1, WALLET_2, WALLET_3, WALLET_4, WALLET_5],
            vector[2_000, 2_000, 2_000, 2_000, 2_000],
        );

        ts::next_tx(&mut scenario, FAKE_WALLET);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::return_shared(refund_pool);
        ts::return_to_address(ALDRIN, pub);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = refund::refund::EInvalidPublisher)]
    fun test_fail_fake_aldrin() {
        let scenario = ts::begin(ALDRIN);

        // Act: Initialize the refund pool
        let otw = refund::get_otw_for_testing();
        refund::init_test(otw, ctx(&mut scenario));

        // Assert: Verify initialization logic such as checking for a non-empty RefundPool, correct `id`, and initial `accounting` values.
        // This might include checking the `unclaimed` table is empty, `funds` are zero, etc.
        // Assertions here will depend on functions or methods provided by the test framework to inspect the state.
        ts::next_tx(&mut scenario, ALDRIN);

        let pub = ts::take_from_address<Publisher>(&scenario, ALDRIN);
        assert!(package::from_package<REFUND>(&pub), 0);

        let refund_pool = ts::take_shared<RefundPool>(&scenario);

        refund::fund(&mut refund_pool, coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario)));

        ts::return_to_address(ALDRIN, pub);
        ts::next_tx(&mut scenario, FAKE_ALDRIN);
        
        let fake_pub = package::test_claim<FAKE_REFUND>(FAKE_REFUND {}, ctx(&mut scenario));

        refund::add_addresses(
            &fake_pub,
            &mut refund_pool,
            vector[FAKE_WALLET],
            vector[10_000],
        );

        ts::next_tx(&mut scenario, FAKE_WALLET);
        refund::claim_refund(&mut refund_pool, ctx(&mut scenario));

        ts::return_shared(refund_pool);
        transfer::public_transfer(fake_pub, FAKE_ALDRIN);
        ts::end(scenario);
    }
}