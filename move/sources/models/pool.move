module refund::pool {
    use sui::tx_context::TxContext;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::sui::SUI;

    friend refund::refund;
    friend refund::booster;

    struct Pool has store {
        funds: Balance<SUI>,
        funders: Table<address, u64>,
    }

    public(friend) fun new(ctx: &mut TxContext): Pool {
        Pool {
            funds: balance::zero(),
            funders: table::new(ctx),
        }
    }

    // === Getters ===
    
    public fun funds(pool: &Pool): &Balance<SUI> { &pool.funds }
    public fun funders(pool: &Pool): &Table<address, u64> { &pool.funders }

    // === Mutators (Friends) ===
    
    public(friend) fun funds_mut(pool: &mut Pool): &mut Balance<SUI> { &mut pool.funds }
    public(friend) fun funders_mut(pool: &mut Pool): &mut Table<address, u64> { &mut pool.funders }
}