#[allow(lint(self_transfer))]
module refund::refund {
    use sui::tx_context::{TxContext, sender};
	use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use std::vector;
    use std::option::{Option, some, none};
    use sui::package::{Self, Publisher};
    use sui::sui::SUI;
    
    use refund::math::div;

    const EInvalidPublisher: u64 = 0;
    const EInvalidAddress: u64 = 1;
    const EAddressesAmountsVecLenMismatch: u64 = 2;

    // OTW
    struct REFUND has drop {}

    struct RefundPool has key {
        id: UID,
        unclaimed: Table<address, u64>,
        funds: Balance<SUI>,
        accounting: Accounting,
    }

    struct Accounting has store {
        total_refunded: u64,
        total_boosted: u64,
        current_liability: u64,
    }

    /// Called during contract publishing
    fun init(otw: REFUND, ctx: &mut TxContext) {
        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let sender = sender(ctx);

        let list = RefundPool {
            id: object::new(ctx),
            unclaimed: table::new(ctx),
            funds: balance::zero(),
            accounting: Accounting {
                total_refunded: 0,
                total_boosted: 0,
                current_liability: 0,
            }
        };

        transfer::public_transfer(publisher, sender);
        transfer::share_object(list);
    }

    public entry fun fund(
        pool: &mut RefundPool,
        coin: Coin<SUI>,
    ) {
        balance::join(&mut pool.funds, coin::into_balance(coin)); 
    }

    public entry fun add_addresses(
        pub: &Publisher,
        pool: &mut RefundPool,
        addresses: vector<address>,
        amounts: vector<u64>,
    ) {
        assert!(package::from_module<REFUND>(pub), EInvalidPublisher);
        assert!(vector::length(&addresses) == vector::length(&amounts), EAddressesAmountsVecLenMismatch);
        
        let len = vector::length(&addresses);

        while (len > 0) {
            let amount = vector::pop_back(&mut amounts);

            pool.accounting.current_liability = pool.accounting.current_liability + amount;

            table::add(
                &mut pool.unclaimed,
                vector::pop_back(&mut addresses),
                amount,
            );

            len = len - 1;
        };

        vector::destroy_empty(addresses);
        vector::destroy_empty(amounts);
    }

    public entry fun claim_refund(
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        let sender = sender(ctx);
        assert!(table::contains(&pool.unclaimed, sender), EInvalidAddress);

        let refund_amount = table::remove(&mut pool.unclaimed, sender);
        
        pool.accounting.total_refunded = pool.accounting.total_refunded + refund_amount;
        pool.accounting.current_liability = pool.accounting.current_liability - refund_amount;

        let funds = balance::split(&mut pool.funds, refund_amount);

        transfer::public_transfer(coin::from_balance(funds, ctx), sender);
    }
    
    public entry fun claim_refund_boosted(
        pub: &Publisher,
        pool: &mut RefundPool,
        affected_address: address,
        new_address: address,
        ctx: &mut TxContext,
    ) {
        assert!(package::from_module<REFUND>(pub), EInvalidPublisher);
        assert!(table::contains(&pool.unclaimed, affected_address), EInvalidAddress);

        let refund_amount = table::remove(&mut pool.unclaimed, affected_address);
        let boost = div(refund_amount, 2);
        let boosted_refund_amount = refund_amount + boost;

        pool.accounting.total_refunded = pool.accounting.total_refunded + refund_amount;
        pool.accounting.total_boosted = pool.accounting.total_boosted + boost;
        pool.accounting.current_liability = pool.accounting.current_liability - refund_amount;

        let funds = balance::split(&mut pool.funds, boosted_refund_amount);

        transfer::public_transfer(coin::from_balance(funds, ctx), new_address);
    }

    // === Getters ===

    public fun amount_to_claim(pool: &RefundPool, claimer: address): Option<u64> {
        if (table::contains(&pool.unclaimed, claimer)) {
            some(*table::borrow(&pool.unclaimed, claimer))
        } else {
            none()
        }
    }
    public fun funding(pool: &RefundPool): u64 { balance::value(&pool.funds) }
    public fun total_refunded(pool: &RefundPool): u64 { pool.accounting.total_refunded }
    public fun total_boosted(pool: &RefundPool): u64 { pool.accounting.total_boosted }
    public fun current_liability(pool: &RefundPool): u64 { pool.accounting.current_liability }
    
    public fun current_liability_boosted(pool: &RefundPool): u64 { pool.accounting.current_liability + div(pool.accounting.current_liability, 2) }
    
    public fun unfunded_liability(pool: &RefundPool): u64 {
        let available = balance::value(&pool.funds);
        if (available >= pool.accounting.current_liability) {
            0
        } else {
            pool.accounting.current_liability - available
        }
    }

    public fun unfunded_liability_boosted(pool: &RefundPool): u64 {
        let unfunded_liability = unfunded_liability(pool);
        unfunded_liability + div(unfunded_liability, 2)
    }

    #[test_only]
    public fun get_otw_for_testing(): REFUND {
        REFUND {}
    }
    
    #[test_only]
    public fun init_test(otw: REFUND, ctx: &mut TxContext) {
        init(otw, ctx)
    }
}