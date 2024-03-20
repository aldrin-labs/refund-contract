module refund::sig {
    use std::vector;
    use std::debug::print;
    use sui::object::{Self, ID};
    use sui::address as sui_address;
    use sui::hash::blake2b256;

    // This function converts a public key to a Sui address using BLAKE2b-256 for hashing.
    // The public key is expected to be in the form of a vector<u8> (byte array).
    public fun public_key_to_sui_address(public_key: vector<u8>): address {
        let data_to_hash = vector[];
        
        // Append the Ed25519 signature scheme flag byte (0x00) to the data to hash.
        vector::push_back(&mut data_to_hash, 0x00);
        
        // Append the public key bytes to the data to hash.
        let public_key_len = vector::length(&public_key);
        let i = 0;
        while (i < public_key_len) {
            vector::push_back(&mut data_to_hash, *vector::borrow(&public_key, i));
            i = i + 1;
        };

        print(&data_to_hash);

        // Hash the data using BLAKE2b-256.
        sui_address::from_bytes(blake2b256(&data_to_hash))
    }
    
    // This function converts a public key to a Sui address using BLAKE2b-256 for hashing.
    // The public key is expected to be in the form of a vector<u8> (byte array).
    public fun public_key_to_sui_address_(public_key: vector<u8>): vector<u8> {
        let data_to_hash = vector[];
        
        // Append the Ed25519 signature scheme flag byte (0x00) to the data to hash.
        vector::push_back(&mut data_to_hash, 0x00);
        
        // Append the public key bytes to the data to hash.
        let public_key_len = vector::length(&public_key);
        let i = 0;
        while (i < public_key_len) {
            vector::push_back(&mut data_to_hash, *vector::borrow(&public_key, i));
            i = i + 1;
        };

        print(&data_to_hash);

        // Hash the data using BLAKE2b-256.
        blake2b256(&data_to_hash)
    }

    public fun construct_msg(
        affected_address_bytes: vector<u8>,
        new_address_bytes: vector<u8>,
        nonce: ID,
    ): vector<u8> {
        let msg = vector::empty();
        vector::append(&mut msg, affected_address_bytes);
        vector::append(&mut msg, new_address_bytes);
        vector::append(&mut msg, object::id_to_bytes(&nonce));

        msg
    }

    public fun address_to_bytes(addr: address): vector<u8> {
        object::id_to_bytes(&object::id_from_address(addr))
    }
}