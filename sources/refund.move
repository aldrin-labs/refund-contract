// A module for managing a refund process, including a mechanism for boosting refunds.
// This module includes functionalities for funding a refund pool, adding addresses for refunds,
// claiming refunds and boosted refunds, and various getters for information about the pool and refunds.
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

    /// Represents a pool of funds allocated for refunds, along with a record of unclaimed refunds.
    /// 
    /// Fields:
    /// - `id`: A unique identifier for the RefundPool, used to track and manage the pool within the system.
    /// - `unclaimed`: A table mapping addresses to the amount of funds they are eligible to claim as a refund. This ensures only eligible addresses can claim their specified amounts.
    /// - `funds`: The total balance of SUI coins held in the refund pool. This balance is used to fulfill refund claims made by eligible addresses.
    /// - `accounting`: A record of accounting metrics related to the refund process, including the total amount refunded, the total amount boosted (for eligible claims made through specific channels like Rinbot), and the current liabilities of the refund pool.
    struct RefundPool has key {
        id: UID,
        unclaimed: Table<address, u64>,
        funds: Balance<SUI>,
        accounting: Accounting,
    }

    /// Contains accounting details relevant to the management of the RefundPool.
    ///
    /// Fields:
    /// - `total_refunded`: The cumulative amount of funds that have been refunded to users. This includes both standard and boosted refunds.
    /// - `total_boosted`: The total amount of funds provided as part of boosted refunds. This figure helps track the additional funds given out as part of special refund conditions, such as the 150% refund scenario.
    /// - `current_liability`: Represents the total amount of funds that the RefundPool is currently obligated to pay out. This includes all unclaimed refunds and is used to manage the financial health and obligations of the pool.
    struct Accounting has store {
        total_refunded: u64,
        total_boosted: u64,
        current_liability: u64,
    }

    /// Initializes the refund module during contract publishing.
    /// Sets up the refund pool and transfers ownership from the publisher to the sender.
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

    /// Permissionless endpoint for funding therefund pool with the given SUI coin.
    public entry fun fund(
        pool: &mut RefundPool,
        coin: Coin<SUI>,
    ) {
        balance::join(&mut pool.funds, coin::into_balance(coin)); 
    }

    /// Adds addresses and corresponding amounts to the refund pool. This endpoint
    /// is reserved to Aldrin, i.e the owner of the `Publisher` object
    /// 
    /// #### Panics
    /// 
    /// - If the publisher is not valid.
    /// - If the lengths of the addresses and amounts vectors do not match.
    /// - If a given address already exists in the refund pool
    /// - If there are duplicated addresses in the `adresses` vector
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

    /// Allows a claimer to claim their refund from the pool. This endpoint
    /// should be called by the address registered in the `unclaimed` table.
    /// Transfers the claimed amount back to the claimer.
    /// 
    /// #### Panics
    /// 
    /// - If the claimer's address is not in the list of unclaimed refunds.
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
    
    /// Allows an affected address to claim a boosted refund to a new address.
    /// The refund amount is increased by a boost calculated as half of the
    /// original refund amount. The resulting total refund corresponds to 1.5x
    /// the actual amount lost in the loss envent.
    /// 
    /// This endpoint is reserved to Aldrin, i.e. the owner of the `Publisher` object.
    /// The refund boost is limited to user who refund via the Rinbot account.
    /// When a user claims the refund with 1.5x boost, Aldrin will call
    /// `claim_refund_boosted` with the `affected_address` being the user address
    /// original affected by the loss event, and `new_address` being the associated
    /// Rinbot account address.
    /// 
    /// #### Panics
    /// - If the publisher is not valid.
    /// - If the affected address does not exist in the unclaimed refunds list.
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
    
    /// Calculates the current liability of the RefundPool, considering the boosted refund scenario.
    ///
    /// This function computes the total current liability of the pool and then adds an additional 50% to model
    /// the scenario where all outstanding refunds are claimed with a 150% boost. This is useful for assessing
    /// the potential maximum liability under boosted refund conditions.
    public fun current_liability_boosted(pool: &RefundPool): u64 { pool.accounting.current_liability + div(pool.accounting.current_liability, 2) }
    
    /// Calculates the unfunded liability of the RefundPool.
    ///
    /// This function determines the difference between the current liabilities (the total amount the pool
    /// needs to refund) and the available funds in the pool. If the available funds are sufficient to cover
    /// all liabilities, the unfunded liability is zero. Otherwise, it represents the shortfall that must be
    /// addressed to fully fund all refund claims.
    public fun unfunded_liability(pool: &RefundPool): u64 {
        let available = balance::value(&pool.funds);
        if (available >= pool.accounting.current_liability) {
            0
        } else {
            pool.accounting.current_liability - available
        }
    }

    /// Calculates the unfunded liability of the RefundPool under boosted refund conditions.
    ///
    /// Similar to `unfunded_liability`, but considers the scenario where all refunds are boosted by 50%.
    /// This function first calculates the standard unfunded liability, then adds 50% of that liability to
    /// model the additional funds that would be required if all refunds were claimed with a 150% boost.
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