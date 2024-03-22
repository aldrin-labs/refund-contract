module refund::booster {
    // use std::debug::print;
    use sui::tx_context::{TxContext, sender};
	use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::balance;
    use sui::table;
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::package::Publisher;
    use sui::sui::SUI;
    
    use refund::refund::{
        Self, RefundPool, claim_refund_,
        accounting, unclaimed, uid_mut,
        accounting_mut, booster_pool_mut
    };
    use refund::accounting::{
        total_raised_for_boost, total_raised_for_boost_mut,
        current_liabilities, total_boosted_mut
    };
    use refund::math::div;
    use refund::table::{Self as refund_table};
    use refund::pool::{funders_mut, funds_mut};

    const EAddressRetrievedBoostCap: u64 = 0;

    struct BoostedCapDfKey has copy, store, drop { affected_address: address }

    struct BoostedClaimCap has key {
        id: UID,
        new_address: address
    }

    // === Phase 2: Funding ===

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

    public entry fun withdraw_funds(
        pool: &mut RefundPool,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        refund::assert_funding_phase(pool);

        let total_raised_for_boost = total_raised_for_boost_mut(accounting_mut(pool));
        *total_raised_for_boost = *total_raised_for_boost - amount;

        let booster = booster_pool_mut(pool);
        refund_table::remove_or_subtract(funders_mut(booster), sender(ctx), amount);
        let funds = coin::from_balance(balance::split(funds_mut(booster), amount) , ctx);
        transfer::public_transfer(funds, sender(ctx));
    }

    // === Phase 3: Claim Refund ===

    // called via tx sent from Rinbot address
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

    public entry fun claim_refund_boosted(
        cap: BoostedClaimCap,
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        let affected_address = sender(ctx);
        refund::assert_address(pool, affected_address);

        let BoostedClaimCap { id, new_address } = cap;
        object::delete(id);
        
        let refund_amount = *table::borrow(unclaimed(pool), affected_address);

        // Base Refund
        let refund = claim_refund_(pool, affected_address, ctx);

        // Booster Refund
        let boost = div(refund_amount, 2);

        let total_boosted = total_boosted_mut(accounting_mut(pool));
        *total_boosted = *total_boosted + boost;

        let booster = booster_pool_mut(pool);
        let boosted_funds = balance::split(funds_mut(booster), boost);

        balance::join(coin::balance_mut(&mut refund), boosted_funds);

        transfer::public_transfer(refund, new_address);
    }

    // === Phase 4: Reclaim Fund ===

    public entry fun reclaim_fund(
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        refund::assert_reclaim_phase(pool);

        let total_raised = total_raised_for_boost(accounting(pool));
        let booster = booster_pool_mut(pool);

        refund::reclaim_funds_(booster, total_raised, ctx);
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
}