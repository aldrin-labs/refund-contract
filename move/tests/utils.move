#[test_only]
module refund::test_utils {
    use sui::test_scenario::{Self as ts, ctx};
    use sui::package::Publisher;

    use refund::refund::RefundPool;
    use refund::booster::{Self, BoostedClaimCap};

    public fun claim_boosted(
        pub: &Publisher,
        pool: &mut RefundPool,
        affected_address: address,
        new_address: address,
        scenario: &mut ts::Scenario,
    ) {
        ts::next_tx(scenario, publisher());

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

