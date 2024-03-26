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
    const EOverfunded: u64 = 13;
    
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

    /// Manages funds for refunds and records unclaimed refunds.
    ///
    /// Fields:
    /// - `id`: Unique identifier for the pool.
    /// - `unclaimed`: Maps addresses to amounts eligible for refund, ensuring
    /// claims are made by eligible addresses.
    /// - `base_pool`: Holds funds for 100% refunds.
    /// - `booster_pool`: Holds funds for 50% boosted refunds for eligible claims.
    /// - `accounting`: Tracks financial metrics like total refunded, totalboosted,
    /// and liabilities.
    /// - `phase`: Indicates the current process phase (1: Address Addition,
    /// 2: Funding, 3: Claim, 4: Reclaim).
    /// - `timeout_ts`: Timestamp in milliseconds when the pool enters
    /// reclaim phase, allowing funders to reclaim leftover funds.
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
    /// Sets up the refund pool in its initial phase (Address Addition phase)
    /// and transfers ownership from the publisher to the sender.
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

    /// Adds addresses and their corresponding refund amounts to the Refund Pool.
    /// This function is exclusively callable by the owner of the `Publisher` object.
    ///
    /// Usage of this endpoint is restricted to the address addition phase of the refund process.
    /// It ensures that only the Publisher owner can add addresses and amounts,
    /// maintaining the integrity and security of the refund process.
    ///
    /// #### Panics
    ///
    /// - If the `Publisher` is not valid.
    /// - If the lengths of the `addresses` and `amounts` vectors do not match,
    /// indicating a mismatch in address to amount mapping.
    /// - If an address is already present in the refund pool, preventing
    /// duplicate entries.
    /// - If there are duplicated addresses within the `addresses` vector,
    /// ensuring each address is unique and accounted for individually.
    ///
    /// This endpoint must be called by the Publisher owner to maintain controlled
    /// access and update of refundable addresses and their corresponding amounts.
    ///
    /// Parameters:
    /// - `pub`: Reference to the `Publisher`, verifying operation permission.
    /// - `pool`: Mutable reference to the `RefundPool`, where addresses and amounts will be added.
    /// - `addresses`: Vector of addresses eligible for refunds.
    /// - `amounts`: Vector of amounts corresponding to each address in `addresses`.
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

    /// Allows participants to contribute SUI coins to the Refund Pool
    /// during the funding phase. This entrypoint is permissionless.
    /// Contributions are tracked against the sender's address.
    /// If contributions exceed the pool's required funding,
    /// the function asserts to prevent overfunding.
    ///
    /// Panics:
    /// - If the pool is not in the funding phase, ensuring that funds are
    /// collected only during the appropriate phase.
    /// - If the contribution would lead to overfunding, maintaining strict
    /// control over the total amount raised to match the refundable amounts.
    ///
    /// This function also updates the pool's accounting to reflect the
    /// new total raised and adjusts the balance of the pool's base funds accordingly.
    ///
    /// Parameters:
    /// - `pool`: Mutable reference to the Refund Pool to which funds
    /// are being contributed.
    /// - `coin`: The SUI coin being contributed to the pool.
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
        assert!(!is_overfunded, EOverfunded);

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
    /// - If the claimer's address is not found in the `unclaimed` table,
    /// indicating no refund is due.
    /// - If the current phase is not the claim phase, ensuring refunds are 
    /// laimed at the correct time.
    /// - If the current timestamp surpasses the timeout timestamp,
    /// enforcing the timing constraints of the refund process.
    /// - If the pool does not have sufficient funds to cover the
    /// claimed amount, preventing the execution of an invalid claim.
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
    
    /// Initiates the funding phase for the Refund Pool, setting a timeout
    /// for when this **Claiming phase** ends.
    /// This entry point is exclusively accessible by the owner of the `Publisher`
    /// object, ensuring controlled progression to the funding phase.
    ///
    /// Before transitioning to the funding phase, this function validates the
    /// current phase to ensure it's correct for this operation and checks
    /// that the refund pool has at least one address eligible for refunds.
    /// It also validates the provided timeout timestamp against the current
    /// time to ensure it meets the minimum claim period requirement.
    ///
    /// #### Panics
    ///
    /// - If the caller is not the `Publisher` owner.
    /// - If the pool is not in the address addition phase,
    /// ensuring sequential phase progression.
    /// - If the `unclaimed` table within the pool is empty,
    /// indicating there are no addresses to fund.
    /// - If the `timeout_ts` does not meet the minimum duration
    /// from the current timestamp, ensuring there's adequate time for
    /// the funding phase.
    ///
    /// Parameters:
    /// - `pub`: Reference to the `Publisher`, verifying the caller
    /// has authority to initiate the funding phase.
    /// - `pool`: Mutable reference to the `RefundPool` to transition
    /// into the funding phase.
    /// - `timeout_ts`: Timestamp (in milliseconds) specifying when the
    /// claiming phase will end and transition to the reclaim phase.
    /// - `clock`: Reference to a `Clock` for obtaining the current timestamp,
    /// used in validating `timeout_ts`.
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

    /// Initiates the claim phase for the Refund Pool, where eligible addresses
    /// can start claiming their refunds. This transition is allowed only
    /// after the funding phase has concluded and the total funds raised
    /// match the total amount set for refunds.
    ///
    /// Panics:
    /// - If the pool is not in the funding phase, ensuring the transition
    /// to the claim phase follows the correct sequence.
    /// - If the current time has reached the `timeout_ts` set during
    /// the funding phase, ensuring the claim phase is still valid.
    /// - If the total amount raised does not match the total amount set
    /// to be refunded, indicating the pool is underfunded and not ready to
    /// proceed to the claim phase.
    ///
    /// This function checks the pool's funding status against its refund
    /// obligations and moves the pool to the next phase if conditions are met,
    /// allowing refund claims to be processed.
    ///
    /// Parameters:
    /// - `pool`: Mutable reference to the Refund Pool transitioning to the claim phase.
    /// - `clock`: Reference to the system clock for validating the timing condition.
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
    
    /// Initiates the reclaim phase of the Refund Pool, allowing funders to
    /// reclaim their contributions if the fundraising or claim phases did not
    /// fully utilize the collected funds.
    ///
    /// The transition to the reclaim phase is contingent upon the completion
    /// of the preceding phase, whether it be the funding or claim phase,
    /// and the verification that the current time has
    /// surpassed the designated timeout timestamp.
    ///
    /// #### Panics
    ///
    /// - If the current timestamp is before the timeout timestamp set during
    /// the funding phase, ensuring that the reclaim phase does not start prematurely.
    /// - If in the funding phase and the total raised is equal to or greater
    /// than the total amount set for refunds.
    /// - If the pool is not in the correct phase,
    /// ensuring the logical progression of phases.
    ///
    /// This function checks the pool's current phase to determine the
    /// appropriate preconditions for entering the reclaim phase.
    /// If transitioning from the funding phase, it verifies that the funds raised
    /// are less than the total to refund, indicating that the fundaraising did not
    /// achieve its target amount. If transitioning from the claim phase,
    ///  it simply proceeds with the phase transition.
    ///
    /// Parameters:
    /// - `pool`: Mutable reference to the Refund Pool transitioning to the reclaim phase.
    /// - `clock`: Reference to the system clock, used for timestamp verification.
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