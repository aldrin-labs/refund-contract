#[test_only]
module refund::sig_test {
    use sui::object::{Self, ID};
    use refund::sig;
    use refund::test_utils::{
        wallet_1, pubkey_1, rinbot_1, sig_1,
        wallet_2, pubkey_2, rinbot_2, sig_2,
        wallet_3, pubkey_3, rinbot_3, sig_3,
    };

    fun create_msg_and_sign(
        affected_address: address,
        new_address: address,
        pool_id: ID,
    ): vector<u8> {
        sig::construct_msg(
            sig::address_to_bytes(affected_address),
            sig::address_to_bytes(new_address),
            pool_id,
        )
    }

    #[test]
    fun test_create_msg_and_sign() {
        let msg = create_msg_and_sign(
            wallet_1(),
            rinbot_1(),
            object::id_from_address(@0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
        );

        // Sanity check
        assert!(sui::ed25519::ed25519_verify(&sig_1(), &pubkey_1(), &msg),0);
        
        let msg = create_msg_and_sign(
            wallet_2(),
            rinbot_2(),
            object::id_from_address(@0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
        );

        // Sanity check
        assert!(sui::ed25519::ed25519_verify(&sig_2(), &pubkey_2(), &msg),0);
        
        let msg = create_msg_and_sign(
            wallet_3(),
            rinbot_3(),
            object::id_from_address(@0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
        );

        // Sanity check
        assert!(sui::ed25519::ed25519_verify(&sig_3(), &pubkey_3(), &msg),0);
    }

    #[test]
    fun test_public_key_to_sui_address() {
        let addr = sig::public_key_to_sui_address(pubkey_1());
        assert!(addr == wallet_1(), 0);
        let addr = sig::public_key_to_sui_address(pubkey_2());
        assert!(addr == wallet_2(), 0);
        let addr = sig::public_key_to_sui_address(pubkey_3());
        assert!(addr == wallet_3(), 0);
    }

    // /// Generate a message and valid signature for key returned by
    // /// `key_ed25519`
    // fun sig_ed25519(): (vector<u8>, vector<u8>) {
    //     let (pub, _) = key_ed25519();

    //     // Just construct a fake message from any byte data we can get
    //     //
    //     // Simulate this being a P2P authorization request
    //     // `address` | `nonce`

    //     // Number 1 in hexadecimal format (as an addresss type)
    //     // let counter = booster::address_to_bytes(@0x000000000000000000000000000000000000000000000000000000000000000A);

        
    //     let msg = booster::construct_msg(
    //         address_to_bytes(affected_address),
    //     );

    //     let msg = vector::empty();
    //     // The sender address is @0xef20b433672911dbcc20c2a28b8175774209b250948a4f10dc92e952225e8025
    //     vector::append(&mut msg, booster::address_to_bytes(@0xef20b433672911dbcc20c2a28b8175774209b250948a4f10dc92e952225e8025));
    //     // Simulate the nonce
    //     vector::append(&mut msg, counter);

    //     let p1 = @0x70E7F8F502AE2EDA298E50ADAAC05E49DC683FA2A2AD210B26851362483E4711;
    //     let p2 = @0x577A448C24E4E943ADABE2AC90A1800789C5D0B66F699FD4C11702E16B9C7E08;

    //     let sig = vector::empty();
    //     vector::append(&mut sig, launchpad_auth::address_to_bytes(p1));
    //     vector::append(&mut sig, launchpad_auth::address_to_bytes(p2));

    //     // Sanity check
    //     assert!(sui::ed25519::ed25519_verify(&sig, &pub, &msg), 0);

    //     (msg, sig)
    // }
}

