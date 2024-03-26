module refund::booster {
    use sui::tx_context::{TxContext, sender};
	use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::balance;
    use sui::table;
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::package::Publisher;
    use sui::sui::SUI;
    use sui::clock::Clock;
    
    use refund::refund::{
        Self, RefundPool, claim_refund_,
        accounting, unclaimed, uid_mut,
        accounting_mut, booster_pool_mut
    };
    use refund::accounting::{
        total_raised_for_boost, total_raised_for_boost_mut,
        current_liabilities, total_boosted_mut, total_unclaimed_boosted
    };
    use refund::math::div;
    use refund::table::{Self as refund_table};
    use refund::pool::{funders_mut, funds, funds_mut};

    const EAddressRetrievedBoostCap: u64 = 0;
    const EInsufficientFunds: u64 = 1;
    const ERinbotAddressMismatch: u64 = 2;

    struct BoostedCapDfKey has copy, store, drop { affected_address: address }

    struct BoostedClaimCap has key {
        id: UID,
        new_address: address
    }

    // === Phase 2: Funding ===

    /// Allows participants to contribute SUI coins to the Refund Booster Pool
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
        refund::assert_funding_phase(pool);
        
        let amount = coin::value(&coin);
        let total_raised_for_boost = total_raised_for_boost_mut(accounting_mut(pool));
        *total_raised_for_boost = *total_raised_for_boost + amount;

        let booster = booster_pool_mut(pool);
        refund_table::insert_or_add(funders_mut(booster), sender(ctx), amount);
        balance::join(funds_mut(booster), coin::into_balance(coin)); 
    }

    // === Phase 3: Claim Refund ===

    /// Enables the association between a user's affected wallet address
    /// and their Rinbot-associated backend wallet address for claiming
    /// boosted refunds. This function is called by the Rinbot backend
    /// service to grant users the ability to claim an additional 50%
    /// on their refunds through the Rinbot platform. 
    /// 
    /// #### Panics
    ///
    /// - If the caller is not the publisher, ensuring only authorized
    /// entities can initiate this action.
    /// - If the pool is not in the claim phase, restricting this operation to
    /// the correct phase of the refund process.
    /// - If the affected_address is not found in the pool, ensuring only
    /// eligible addresses can be granted a boost.
    /// - If a BoostedClaimCap already exists for the affected_address,
    /// preventing duplicate claims.
    /// 
    /// Parameters:
    /// - `pub`: Reference to the `Publisher`, confirming the authority of the caller.
    /// - `pool`: Mutable reference to the Refund Pool where the claim is being allowed.
    /// - `affected_address`: The primary wallet address of the user eligible
    /// for the boosted refund.
    /// - `new_address`: The Rinbot-associated backend wallet address where
    /// the boosted refund will be transferred.
    public fun allow_boosted_claim(
        pub: &Publisher,
        pool: &mut RefundPool,
        affected_address: address,
        new_address: address,
        ctx: &mut TxContext
    ) {
        refund::assert_publisher(pub);
        refund::assert_claim_phase(pool);
        refund::assert_address(pool, affected_address);
        assert!(!df::exists_(uid_mut(pool), BoostedCapDfKey { affected_address }), EAddressRetrievedBoostCap);

        let boosted_claim_cap = BoostedClaimCap {
            id: object::new(ctx),
            new_address,
        };

        df::add(uid_mut(pool), BoostedCapDfKey { affected_address }, true);
        transfer::transfer(boosted_claim_cap, affected_address);
    }

    /// Claims a boosted refund for users to their associated Rinbot backedn wallet,
    /// thus making them eligible for a 50% bonus on their refund amount.
    /// This entrypoint requires the `BoostedClaimCap` capability, which links
    /// the user's primary address to their Rinbot-associated backend wallet
    /// address.
    /// 
    /// The function calculates and transfers the standard refund plus
    /// the 50% boost to the Rinbot wallet.
    /// 
    /// Before a user claims their boosted refund, they are required to
    /// explicitly confirm their Rinbot-associated address. This confirmed
    /// address is then checked against the `new_address` recorded in the
    /// `BoostedClaimCap`.
    /// 
    /// #### Panics
    ///
    /// - If the calling address does not match the affected address eligible
    /// for the refund, ensuring that only authorized users can claim their refund.
    /// - If the booster pool lacks sufficient funds to cover the boosted
    /// portion of the refund (should not occur).
    /// - If the claim is attempted outside of the designated claim phase.
    public entry fun claim_refund_boosted(
        cap: BoostedClaimCap,
        pool: &mut RefundPool,
        user_rinbot_address: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let affected_address = sender(ctx);
        refund::assert_address(pool, affected_address);

        let BoostedClaimCap { id, new_address } = cap;
        
        assert!(user_rinbot_address == new_address, ERinbotAddressMismatch);
        object::delete(id);
        
        let refund_amount = *table::borrow(unclaimed(pool), affected_address);

        // Base Refund
        let refund = claim_refund_(pool, affected_address, clock, ctx);

        // Booster Refund
        let boost = div(refund_amount, 2);

        let total_boosted = total_boosted_mut(accounting_mut(pool));
        *total_boosted = *total_boosted + boost;

        let booster = booster_pool_mut(pool);
        assert!(balance::value(funds(booster)) >= boost, EInsufficientFunds);
        let boosted_funds = balance::split(funds_mut(booster), boost);


        balance::join(coin::balance_mut(&mut refund), boosted_funds);

        transfer::public_transfer(refund, new_address);
    }

    /// Burns the `BoostedClaimCap`, effectively resetting the capability for a
    /// user to claim a boosted refund. This endpoint is essential for
    /// preventing misuse by unauthorized entities attempting to divert funds
    /// through spoofing.
    /// 
    /// By allowing users to burn their existing `BoostedClaimCap`,
    /// they can safeguard against scams where their legitimate address
    /// might have been targeted to redirect boosted refunds to a scammer's
    /// Rinbot account.
    /// 
    /// Before a user claims their boosted refund, they are required to
    /// explicitly confirm their Rinbot-associated address. This confirmed
    /// address is then checked against the `new_address` recorded in the
    /// `BoostedClaimCap`.
    /// 
    /// If there's a mismatch indicating potential fraud or error, the
    /// `BoostedClaimCap` ought to be returned, and the process is restarted to
    /// ensure that refunds are securely and accurately disbursed.
    public fun return_booster_cap(
        cap: BoostedClaimCap,
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        let affected_address = sender(ctx);
        refund::assert_claim_phase(pool);
        refund::assert_address(pool, affected_address);

        let BoostedClaimCap { id, new_address: _ } = cap;

        object::delete(id);

        let _: bool = df::remove(uid_mut(pool), BoostedCapDfKey { affected_address });
    }

    // === Phase 4: Reclaim Fund ===

    public entry fun reclaim_funds(
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        refund::assert_reclaim_phase(pool);

        let total_raised = total_raised_for_boost(accounting(pool));
        let total_unclaimed = total_unclaimed_boosted(accounting(pool));
        let booster_pool = booster_pool_mut(pool);

        refund::reclaim_funds_(
            booster_pool,
            total_raised,
            total_unclaimed,
            ctx
        );
    }

    // === Gettes and Utils ===

    /// Calculates the current liability of the RefundPool, considering the boosted refund scenario.
    ///
    /// This function computes the total current liability of the pool and then adds an additional 50% to model
    /// the scenario where all outstanding refunds are claimed with a 150% boost. This is useful for assessing
    /// the potential maximum liability under boosted refund conditions.
    public fun current_liability_boosted(pool: &RefundPool): u64 {
        let current_liabilities = current_liabilities(accounting(pool));
        current_liabilities + div(current_liabilities, 2)
    }

    // === Test Utils ===
    
    #[test_only]
    public fun new_for_testing(
        addr: address,
        ctx: &mut TxContext,
    ): BoostedClaimCap {
        BoostedClaimCap {
            id: object::new(ctx),
            new_address: addr
        }
    }
    
}