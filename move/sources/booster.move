module refund::booster {
    // use std::debug::print;
    use sui::tx_context::{TxContext, sender};
	use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::balance;
    use sui::table;
    use sui::package::Publisher;
    use sui::sui::SUI;
    use sui::ed25519;
    
    use refund::refund::{
        Self, RefundPool, claim_refund_,
        accounting, unclaimed, 
        accounting_mut, booster_pool_mut
    };
    use refund::sig;
    use refund::accounting::{total_raised_for_boost, total_raised_for_boost_mut, current_liabilities, total_boosted_mut};
    use refund::math::{mul, div};
    use refund::table::{Self as refund_table};
    use refund::pool::{funders_mut, funds_mut};

    const EIncorrectSignature: u64 = 0;
    const EInvalidAddress: u64 = 1;

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
        affected_address_pubkey: vector<u8>,
        new_address: address,
        signature: vector<u8>,
        ctx: &mut TxContext,
    ) {
        refund::assert_publisher(pub);
        assert!(table::contains(unclaimed(pool), affected_address), EInvalidAddress); // TODO: get from assert function
        // refund::assert_claim_phase(pool);
        
        // Reconstruct message
        assert!(
            sig::public_key_to_sui_address(affected_address_pubkey) == affected_address,
            0
        );

        let msg = sig::construct_msg(
            sig::address_to_bytes(affected_address),
            sig::address_to_bytes(new_address),
            refund::nonce(pool),
        );

        assert!(
            ed25519::ed25519_verify(&signature, &affected_address_pubkey, &msg),
            EIncorrectSignature
        );
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

    // TODO: Encapsulate logic in shared function with refund::reclaim_fund
    public entry fun reclaim_fund(
        pool: &mut RefundPool,
        ctx: &mut TxContext,
    ) {
        refund::assert_reclaim_phase(pool);
        let total_raised = total_raised_for_boost(accounting(pool));

        let booster = booster_pool_mut(pool);

        let funders = funders_mut(booster);
        assert!(table::contains(funders, sender(ctx)), 0); // TODO: err code
        let funding_amount = table::remove(funders, sender(ctx));

        let is_last = table::is_empty(funders);
        let funds = funds_mut(booster);
        
        let reclaim_amount = if (is_last) {
            balance::value(funds)
        } else {
            let leftovers = balance::value(funds);

            // ReclaimAmount = Leftovers * % Share <=>
            // ReclaimAmount = Leftovers * FundingAmount/TotalRaised
            // 
            // We first upscale then downscale
            div(
                mul(leftovers, funding_amount),
                total_raised
            )
        };

        let reclaim_funds = coin::from_balance(balance::split(funds, reclaim_amount), ctx);
        transfer::public_transfer(reclaim_funds, sender(ctx));
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