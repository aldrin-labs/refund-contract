module refund::fuzzy_unclaimed {
    use sui::tx_context::TxContext;
    use sui::table::{Self, Table};
    use sui::table_vec::{Self, TableVec};
    use sui::test_random;
    use sui::address as sui_address;

    struct Claim has copy, store, drop {
        addr: address,
        amount: u64,
    }

    public fun addr(claim: &Claim): address { claim.addr}
    public fun amt(claim: &Claim): u64 { claim.amount}

    public fun unclaimed(ctx: &mut TxContext): (TableVec<Claim>, Table<address, u64>, u64) {
        let unclaimed_vec = table_vec::empty(ctx);
        let unclaimed = table::new(ctx);
        let total_to_raise = 0;

        let rand_amt = test_random::new(vector[1, 1, 1, 1]);
        let rand_addr = test_random::new(vector[0, 0, 0, 0]);

        let len = 200;

        while (len > 0) {

            let amount = test_random::next_u64_in_range(&mut rand_amt, 99_999_999_999);            
            let addr = sui_address::from_u256(test_random::next_u256(&mut rand_addr));

            total_to_raise = total_to_raise + amount;
            table::add(&mut unclaimed, addr, amount);
            table_vec::push_back(&mut unclaimed_vec, Claim { addr, amount });

            len = len - 1;
        };
        
        (unclaimed_vec, unclaimed, total_to_raise)
    }
}