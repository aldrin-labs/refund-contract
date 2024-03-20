// To create an example run:
// npx ts-node examples/signMessageForTesting.ts
#[test_only]
module refund::test_utils {
    use std::vector;
    use refund::sig;

    // === Addresses ===

    public fun wallet_1(): address { @0x470a964de814fec28fa62b3c84114d50811f1f29980cec9a4785342be2a4ce75 }
    public fun wallet_2(): address { @0x0bcc9c49c4ff59aabc2f2e5067f025564897ae680e8abdadfd16943b68959353 }
    public fun wallet_3(): address { @0xccbf9ffda2a74047719f5aec75d56223f4699e5d6f7ac2161df1b9329e6b75f2 }

    public fun rinbot_1(): address { @0x4bd52e3d5397988891c56106769785c8d5eda6bd28d103c98a6ecad0a87b0255 }
    public fun rinbot_2(): address { @0xaf6d95bb9793f7e1ab8d1816c490ac78217e2865221704db490527b81948fe58 }
    public fun rinbot_3(): address { @0x33e2879fae9780b52ec5c279d905a7ab721173de3eb215b82527c9a3d9ded527 }
    
    public fun sig_1(): vector<u8> {
        sig_(
            @0xa3eebfae620ef34bc23bf25150eefae94262e4522869afca062551609cfa271a,
            @0x931f3211e6d88ae4e0703028f1368405100b0ded5b27a0f7b9b779565a25e904,
        )
    }
    public fun sig_2(): vector<u8> {
        sig_(
            @0x2afe5ab9d2425a6971f4b42e702d98a65ebdd14529fce4a37eb4eb2123fa6f7d,
            @0x4726487ef0c1adec6cae1c55e0e13bb2af8790a14a81bb1cc99aec3062c7b408,
        )
    }
    public fun sig_3(): vector<u8> {
        sig_(
            @0x1577a9571c5169aeade5c0f74d65aecb6f0fb094c006a9bb2aacd26826816ba4,
            @0xc5251bb59a98c30fe186ad0f88eaf7cfeaabd7c45fc7667d2be87a84f3a36f07,
        )
    }


    fun sig_(p1: address, p2: address): vector<u8> {
        let signature = vector::empty();

        vector::append(&mut signature, sig::address_to_bytes(p1));
        vector::append(&mut signature, sig::address_to_bytes(p2));

        signature
    }

    // === Pubkeys ===

    public fun pubkey_1(): vector<u8> {
        vector[
      195,  71, 107, 109,  45,  84, 115,  41,
       82,  81, 110, 249, 215, 173, 108, 179,
       71, 237,   0, 250, 134,  76, 213,  17,
       62,   6, 169, 177, 206, 105, 251, 177
    ]
    }
    public fun pubkey_2(): vector<u8> {
        vector[
      127, 142, 166, 236,  42,  51, 148, 150,
        2, 179, 111, 246,  17,  24, 171,  59,
      225, 183, 248, 104, 240, 251,  63,  20,
      249,  58, 199,  21, 190, 144,  12, 222
    ]
    }
    public fun pubkey_3(): vector<u8> {
        vector[
          205,  97, 223, 102, 130,   7, 136,
          171, 120, 152, 186, 160, 104, 217,
          159, 196, 143, 223, 224, 242, 146,
           69, 113,  28,  57,  28, 216, 187,
          154, 221, 114, 224
        ]
    }
}

