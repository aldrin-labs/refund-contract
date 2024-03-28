module refund::fuzzy_funding {
    use sui::tx_context::TxContext;
    use sui::table_vec::{Self, TableVec};
    use sui::table::{Self, Table};
    use sui::test_random;
    use sui::address as sui_address;

    public fun funders(
        total_to_raise: u64,
        total_to_raised_boosted: u64,
        ctx: &mut TxContext
    ): (TableVec<address>, Table<address, u64>, Table<address, u64>) {
        let funders = table::new(ctx);
        let funders_boost = table::new(ctx);

        let rand_amt = test_random::new(vector[6, 6, 6, 6]);
        let rand_amt_boost = test_random::new(vector[16, 16, 16, 16]);
        let rand_addr = test_random::new(vector[8, 8, 8, 8]);
        let addr_list: TableVec<address> = table_vec::empty(ctx);
        let funders_list: TableVec<address> = table_vec::empty(ctx);

        while (total_to_raise > 0) {
            let amount = test_random::next_u64_in_range(&mut rand_amt, 999_999_999_999);
            let addr = sui_address::from_u256(test_random::next_u256(&mut rand_addr));

            table_vec::push_back(&mut addr_list, addr);
            table_vec::push_back(&mut funders_list, addr);

            if (amount > total_to_raise) {
                amount = total_to_raise;
            };

            table::add(&mut funders, addr, amount);
            total_to_raise = total_to_raise - amount;
        };

        let len = table_vec::length(&addr_list);

        while (len > 0) {
            if (total_to_raised_boosted == 0) {
                break
            };

            let amount = test_random::next_u64_in_range(&mut rand_amt_boost, 999_999_999_999);

            if (amount > total_to_raised_boosted) {
                amount = total_to_raised_boosted;
            };

            let addr = table_vec::pop_back(&mut addr_list);

            table::add(&mut funders_boost, addr, amount);
            
            total_to_raised_boosted = total_to_raised_boosted - amount;
            len= len - 1;
        };

        table_vec::drop(addr_list);
        
        (funders_list, funders, funders_boost)
    }
}