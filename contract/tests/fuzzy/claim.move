module refund::fuzzy_claim {
    use std::vector;
    use sui::tx_context::TxContext;
    use sui::table_vec::{Self, TableVec};
    use sui::test_random;
    use sui::address as sui_address;

    // Bit flag:
    // 1 --> Normal claim
    // 2 --> Boosted claim
    // 3 --> No claim
    public fun claim_status(ctx: &mut TxContext): TableVec<u8> {
        let claim_status = table_vec::empty(ctx);
        let rand_addr = test_random::new(vector[5, 5, 5, 5]);

        let len = 200;

        while (len > 0) {
            let addr = sui_address::from_u256(test_random::next_u256(&mut rand_addr));

            let address_bytes = sui_address::to_bytes(addr);
            
            // Use the last byte of the address for a simple random number generation
            let last_byte = *vector::borrow(&address_bytes, vector::length(&address_bytes) - 1);
            // Since the range of a byte is 0-255, we map this to 1-3 by taking the remainder when divided by 3, then adding 1
            let remainder = (last_byte % 3) + 1;

            assert!(remainder <= 3 && remainder >= 1, 0);

            table_vec::push_back(&mut claim_status, remainder);

            len = len - 1;
        };

        claim_status
    }
}