// A module for managing a refund process, including a mechanism for boosting refunds.
// This module includes functionalities for funding a refund pool, adding addresses for refunds,
// claiming refunds and boosted refunds, and various getters for information about the pool and refunds.
#[allow(lint(self_transfer))]
module refund::refund {
    use sui::tx_context::{TxContext, sender};
	use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::balance;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use std::vector;
    use sui::package::{Self, Publisher};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option, some, none};
    
    use refund::math::{div, mul_div};
    use refund::pool::{Self, Pool, funds, funders_mut, funds_mut};
    use refund::table::{Self as refund_table};
    use refund::accounting::{
        Self, Accounting, total_unclaimed,
        total_to_refund, total_raised, total_claimed, total_boosted,
        total_to_refund_mut, total_raised_mut, total_claimed_mut
    };

    const EInvalidPublisher: u64 = 0;
    const EInvalidAddress: u64 = 1;
    const EAddressesAmountsVecLenMismatch: u64 = 2;
    const EPoolUnderfunded: u64 = 3;
    const EInvalidTimeoutTimestamp: u64 = 4;
    const ECurrentTimeBeforeTimeout: u64 = 6;
    const EInvalidFunder: u64 = 7;
    const ERefundPoolHasZeroAddresses: u64 = 8;
    const EPoolFundsNotEmpty: u64 = 9;
    const EPoolBoosterFundsNotEmpty: u64 = 10;
    const EInsufficientFunds: u64 = 11;
    const EClaimPhaseExpired: u64 = 12;
    
    const ENotAddressAdditionPhase: u64 = 101;
    const ENotFundingPhase: u64 = 102;
    const ENotClaimPhase: u64 = 103;
    const ENotReclaimPhase: u64 = 104;

    /// Minimum claim period in milliseconds
    /// corresponding to 3 days
    const MIN_CLAIM_PERIOD_MS: u64 = 259_200_000;

    friend refund::booster;

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
        base_pool: Pool,
        booster_pool: Pool,
        accounting: Accounting,
        // u8 bit flag corresponding to the state of the refun process
        // 1 --> Address addition phase
        // 2 --> Funding phase
        // 3 --> Claim phase
        // 4 --> Reclaim phase
        phase: u8,
        timeout_ts: Option<u64>,
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
            base_pool: pool::new(ctx),
            booster_pool: pool::new(ctx),
            accounting: accounting::new(),
            phase: 1,
            timeout_ts: none()
        };

        transfer::public_transfer(publisher, sender);
        transfer::share_object(list);
    }

    // === Phase 1: Setup ===

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
        assert_address_addition_phase(pool);
        assert_publisher(pub);
        assert!(vector::length(&addresses) == vector::length(&amounts), EAddressesAmountsVecLenMismatch);
        
        let len = vector::length(&addresses);

        while (len > 0) {
            let amount = vector::pop_back(&mut amounts);
            
            let total_to_refund = total_to_refund_mut(&mut pool.accounting);
            *total_to_refund = *total_to_refund + amount;

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

    // === Phase 2: Funding ===

    /// Permissionless endpoint for funding the fund pool with the given SUI coin.
    public entry fun fund(
        pool: &mut RefundPool,
        coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert_funding_phase(pool);

        let amount = coin::value(&coin);
        refund_table::insert_or_add(funders_mut(&mut pool.base_pool), sender(ctx), amount);

        // If overfunded then return the excess
        let total_to_refund = total_to_refund(&pool.accounting);
        let total_raised = total_raised_mut(&mut pool.accounting);

        let is_overfunded = *total_raised + amount > total_to_refund;
        assert!(!is_overfunded, 0);

        *total_raised = *total_raised + amount;
        balance::join(funds_mut(&mut pool.base_pool), coin::into_balance(coin)); 
    }

    // === Phase 3: Claim Refund ===

    /// Allows a claimer to claim their refund from the pool. This endpoint
    /// should be called by the address registered in the `unclaimed` table.
    /// Transfers the claimed amount back to the claimer.
    /// 
    /// #### Panics
    /// 
    /// - If the claimer's address is not in the list of unclaimed refunds.
    public entry fun claim_refund(
        pool: &mut RefundPool,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = sender(ctx);
        assert_address(pool, sender);

        transfer::public_transfer(claim_refund_(pool, sender, clock, ctx), sender);
    }
    
    public(friend) fun claim_refund_(
        pool: &mut RefundPool,
        original_address: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        let timeout_ts = *option::borrow(&pool.timeout_ts);
        assert_claim_phase_time(timeout_ts, clock);
        assert_claim_phase(pool);

        let refund_amount = table::remove(&mut pool.unclaimed, original_address);
        let total_claimed = total_claimed_mut(&mut pool.accounting);
        *total_claimed = *total_claimed + refund_amount;

        assert!(balance::value(funds(&pool.base_pool)) >= refund_amount, EInsufficientFunds);
        let funds = balance::split(funds_mut(&mut pool.base_pool), refund_amount);

        coin::from_balance(funds, ctx)
    }

    // === Phase 4: Reclaim Fund ===

    public entry fun reclaim_funds(
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        assert_reclaim_phase(pool);
        let total_raised = total_raised(&pool.accounting);

        reclaim_funds_(
            &mut pool.base_pool,
            total_raised,
            total_unclaimed(&pool.accounting),
            ctx
        );
    }

    // === Delete ===

    public entry fun delete(
        pool: RefundPool,
    ) {
        assert_reclaim_phase(&pool);
        assert!(balance::value(funds(&pool.base_pool)) == 0, EPoolFundsNotEmpty);
        assert!(balance::value(funds(&pool.booster_pool)) == 0, EPoolBoosterFundsNotEmpty);

        let RefundPool {
            id, // : UID,
            unclaimed, // : Table<address, u64>,
            base_pool, // : Pool,
            booster_pool, // : Pool,
            accounting, // : Accounting,
            phase: _, // : u8,
            timeout_ts, // : Option<u64>,
        } = pool;

        object::delete(id);
        table::drop(unclaimed);
        pool::delete(base_pool);
        pool::delete(booster_pool);
        accounting::drop(accounting);
        option::destroy_some(timeout_ts);

    }
    
    // === Getters ===

    public fun unclaimed(pool: &RefundPool): &Table<address, u64> { &pool.unclaimed }
    public fun base_pool(pool: &RefundPool): &Pool { &pool.base_pool}
    public fun booster_pool(pool: &RefundPool): &Pool { &pool.booster_pool }
    public fun accounting(pool: &RefundPool): &Accounting { &pool.accounting }
    public fun phase(pool: &RefundPool): u8 { pool.phase }
    public fun timeout_ts(pool: &RefundPool): Option<u64> { pool.timeout_ts }

    public fun amount_to_claim(pool: &RefundPool, claimer: address): Option<u64> {
        if (table::contains(&pool.unclaimed, claimer)) {
            some(*table::borrow(&pool.unclaimed, claimer))
        } else {
            none()
        }
    }
    
    public fun amount_to_claim_boosted(pool: &RefundPool, claimer: address): Option<u64> {
        if (table::contains(&pool.unclaimed, claimer)) {
            let claim_amount = *table::borrow(&pool.unclaimed, claimer);
            some(claim_amount + div(claim_amount, 2))
        } else {
            none()
        }
    }
    
    public fun get_total_to_refund(pool: &RefundPool): u64 { total_to_refund(&pool.accounting) }
    public fun get_total_raised(pool: &RefundPool): u64 { total_raised(&pool.accounting) }
    public fun get_total_claimed(pool: &RefundPool): u64 { total_claimed(&pool.accounting) }
    public fun get_total_boosted(pool: &RefundPool): u64 { total_boosted(&pool.accounting) }
    public fun base_funds(pool: &RefundPool): u64 { balance::value(funds(&pool.base_pool)) }
    public fun booster_funds(pool: &RefundPool): u64 { balance::value(funds(&pool.booster_pool)) }
    public fun current_liabilities(pool: &RefundPool): u64 { accounting::current_liabilities(&pool.accounting) }

    // === Friends ===

    public(friend) fun uid_mut(pool: &mut RefundPool): &mut UID { &mut pool.id }
    public(friend) fun unclaimed_mut(pool: &mut RefundPool): &mut Table<address, u64> { &mut pool.unclaimed }
    public(friend) fun accounting_mut(pool: &mut RefundPool): &mut Accounting { &mut pool.accounting }
    public(friend) fun booster_pool_mut(pool: &mut RefundPool): &mut Pool { &mut pool.booster_pool }

    public(friend) fun reclaim_funds_(
        inner_pool: &mut Pool,
        total_raised: u64,
        total_unclaimed: u64,
        ctx: &mut TxContext,
    ) {
        let funders = funders_mut(inner_pool);
        assert!(table::contains(funders, sender(ctx)), EInvalidFunder);
        let funding_amount = table::remove(funders, sender(ctx));

        let is_last = table::is_empty(funders);
        let funds = funds_mut(inner_pool);
        
        let reclaim_amount = if (is_last) {
            balance::value(funds)
        } else {
            // ReclaimAmount = Leftovers * % Share <=>
            // ReclaimAmount = Leftovers * FundingAmount/TotalRaised
            // 
            // We first upscale then downscale
            mul_div(funding_amount, total_unclaimed, total_raised)

        };

        let reclaim_funds = coin::from_balance(balance::split(funds, reclaim_amount), ctx);
        transfer::public_transfer(reclaim_funds, sender(ctx));
    }

    // === Phase Transitions ===
    
    public entry fun start_funding_phase(
        pub: &Publisher,
        pool: &mut RefundPool,
        timeout_ts: u64,
        clock: &Clock,
    ) {
        assert_publisher(pub);
        assert_address_addition_phase(pool);
        assert!(!table::is_empty(&pool.unclaimed), ERefundPoolHasZeroAddresses);
        
        assert!(timeout_ts >= clock::timestamp_ms(clock) + MIN_CLAIM_PERIOD_MS, EInvalidTimeoutTimestamp);
        option::fill(&mut pool.timeout_ts, timeout_ts);

        next_phase(pool)
    }

    public entry fun start_claim_phase(
        pool: &mut RefundPool,
        clock: &Clock,
    ) {
        assert_funding_phase(pool);
        let timeout_ts = *option::borrow(&pool.timeout_ts);
        assert_claim_phase_time(timeout_ts, clock);

        let total_to_refund = total_to_refund(&pool.accounting);
        let total_raised = total_raised(&pool.accounting);
        assert!(total_to_refund == total_raised, EPoolUnderfunded);

        next_phase(pool)
    }
    
    public entry fun start_reclaim_phase(
        pool: &mut RefundPool,
        clock: &Clock,
    ) {
        let timeout_ts = option::borrow(&pool.timeout_ts);
        assert!(clock::timestamp_ms(clock) >= *timeout_ts, ECurrentTimeBeforeTimeout);

        if (is_funding_phase(pool)) {
            let total_to_refund = total_to_refund(&pool.accounting);
            let total_raised = total_raised(&pool.accounting);
            assert!(total_raised < total_to_refund, 0);
            
        } else {
            assert_claim_phase(pool);
        };

        next_phase(pool);
    }

    fun next_phase(pool: &mut RefundPool) {
        pool.phase = pool.phase + 1;
    }

    // === Assertions ===

    public fun assert_publisher(pub: &Publisher) {
        assert!(package::from_module<REFUND>(pub), EInvalidPublisher);
    }
    
    fun assert_address_addition_phase(pool: &RefundPool) {
        assert!(is_address_addition_phase(pool), ENotAddressAdditionPhase);
    }
    
    public(friend) fun assert_funding_phase(pool: &RefundPool) {
        assert!(is_funding_phase(pool), ENotFundingPhase);
    }
    
    public(friend) fun assert_claim_phase(pool: &RefundPool) {
        assert!(is_claim_phase(pool), ENotClaimPhase);
    }
    
    public(friend) fun assert_reclaim_phase(pool: &RefundPool) {
        assert!(is_reclaim_phase(pool), ENotReclaimPhase);
    }
    
    public(friend) fun assert_address(pool: &RefundPool, sender: address) {
        assert!(table::contains(&pool.unclaimed, sender), EInvalidAddress);
    }
    
    fun assert_claim_phase_time(timeout_ts: u64, clock: &Clock) {
        assert!(clock::timestamp_ms(clock) < timeout_ts, EClaimPhaseExpired);
    }
    
    fun is_address_addition_phase(pool: &RefundPool): bool {
        pool.phase == 1
    }
    fun is_funding_phase(pool: &RefundPool): bool {
        pool.phase == 2
    }
    fun is_claim_phase(pool: &RefundPool): bool {
        pool.phase == 3
    }
    fun is_reclaim_phase(pool: &RefundPool): bool {
        pool.phase == 4
    }

    // === Test Functions ===

    #[test_only]
    public fun new_for_testing(
        unclaimed: Table<address, u64>,
        base_pool: Pool,
        booster_pool: Pool,
        accounting: Accounting,
        phase: u8,
        timeout_ts: Option<u64>,
        ctx: &mut TxContext
    ): RefundPool {
        RefundPool {
            id: object::new(ctx),
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            phase,
            timeout_ts,
        }
    }

    #[test_only]
    public fun get_otw_for_testing(): REFUND {
        REFUND {}
    }
    
    #[test_only]
    public fun destroy_for_testing(pool: RefundPool) {
        let RefundPool {
            id,
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            phase: _,
            timeout_ts,
        } = pool;

        object::delete(id);

        table::drop(unclaimed);
        pool::destroy_for_testing(base_pool);
        pool::destroy_for_testing(booster_pool);
        accounting::destroy_for_testing(accounting);
        
        if (option::is_some(&timeout_ts)) {
            option::destroy_some(timeout_ts);
        } else {
            option::destroy_none(timeout_ts);
        };
    }
    
    #[test_only]
    public fun destruct_for_testing(pool: RefundPool): (
        Table<address, u64>, Pool, Pool, Accounting, u8, Option<u64>
    ) {
        let RefundPool {
            id,
            unclaimed,
            base_pool,
            booster_pool,
            accounting,
            phase,
            timeout_ts,
        } = pool;

        object::delete(id);

        (unclaimed, base_pool, booster_pool, accounting, phase, timeout_ts)
    }

    #[test_only]
    /// Initializes the refund module during contract publishing.
    /// Sets up the refund pool and transfers ownership from the publisher to the sender.
    public fun init_test(otw: REFUND, ctx: &mut TxContext) {
        // Init Publisher
        let publisher = sui::package::claim(otw, ctx);
        let sender = sender(ctx);

        let list = RefundPool {
            id: object::new(ctx),
            unclaimed: table::new(ctx),
            base_pool: pool::new(ctx),
            booster_pool: pool::new(ctx),
            accounting: accounting::new(),
            phase: 1,
            timeout_ts: none()
        };

        transfer::public_transfer(publisher, sender);
        transfer::share_object(list);
    }
    
    #[test_only]
    public fun empty_for_testing(ctx: &mut TxContext): (Publisher, RefundPool) {
        // Init Publisher
        let publisher = sui::package::claim(REFUND {}, ctx);

        let list = RefundPool {
            id: object::new(ctx),
            unclaimed: table::new(ctx),
            base_pool: pool::new(ctx),
            booster_pool: pool::new(ctx),
            accounting: accounting::new(),
            phase: 1,
            timeout_ts: none()
        };

        (publisher, list)
    }
}