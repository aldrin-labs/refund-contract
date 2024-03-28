module refund::table {
    use sui::table::{Self, Table};

    const EAmountTooBig: u64 = 0;

    public fun insert_or_add(table: &mut Table<address, u64>, addr: address, amount: u64) {
        if (table::contains(table, addr)) {
            let current_amount = table::borrow_mut(table, addr);
            *current_amount = *current_amount + amount;
        } else {
            table::add(table, addr, amount);
        }
    }
    
    public fun remove_or_subtract(table: &mut Table<address, u64>, addr: address, amount: u64) {
        let current_amount = table::borrow_mut(table, addr);

        if (amount < *current_amount) {
            *current_amount = *current_amount - amount;
            return
        };

        if (amount == *current_amount) {
            table::remove(table, addr);
            return
        };

        abort(EAmountTooBig)
    }

    // === Tests ===

    #[test_only]
    use sui::test_scenario::{Self as ts, ctx};

    #[test]
    fun test_insert_or_add() {
        let scenario = ts::begin(@0x0);

        // Create a mock table to simulate the refund table
        let refund_table: Table<address, u64> = table::new(ctx(&mut scenario));

        // Define addresses for testing
        let address1 = @0x1;
        let address2 = @0x2;

        // Insert initial amounts for each address
        refund::table::insert_or_add(&mut refund_table, address1, 100);
        refund::table::insert_or_add(&mut refund_table, address2, 200);

        // Verify initial insertions
        assert!(table::contains(&refund_table, address1), 0);
        assert!(table::contains(&refund_table, address2), 0);
        assert!(*table::borrow(&refund_table, address1) == 100, 0);
        assert!(*table::borrow(&refund_table, address2) == 200, 0);

        // Insert additional amount for address1 and a new amount for a new address (address3)
        refund::table::insert_or_add(&mut refund_table, address1, 50); // This should update address1's amount to 150
        let address3 = @0x3;
        refund::table::insert_or_add(&mut refund_table, address3, 300); // New entry

        // Verify updates
        assert!(*table::borrow(&refund_table, address1) == 150, 0);
        assert!(table::contains(&refund_table, address3), 0);
        assert!(*table::borrow(&refund_table, address3) == 300, 0);

        table::drop(refund_table);
        ts::end(scenario);
    }
}