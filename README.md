# Refund Contract

Refund Pool: `0x82544a2f83c6ed1c1092d4b0e92837e2c3bd983228dd6529da632070b6657a97`
Refund Package: `0x2843d7add326ac31e71c75954b79a059aa13456946d26422a9fd20f75e06b468`


### Context
This contract relates to refunding effort following the PIKKA SUI memecoin rugpull that took place on the 18th March 2024. For more context:

- https://x.com/thebryanjun/status/1769760272951005647?s=20
- https://x.com/CussySSS/status/1769775910100828176?s=20
- https://x.com/BL0CKRUNNER/status/1769655895833670052?s=20

### Overview
The Refund Module is a smart contract that facilitates the management of refunds concerning the PIKKA SUI memecoin rugpull, including a unique feature to boost refunds under certain conditions. It provides a structured way to fund a refund pool, add addresses eligible for refunds, and claim refunds.

Users who have lost funds in the rugpull event have two refund options:
1. 100% Refund: Users who lost money in the scam can claim a full refund. Only those affected are eligible.
2. 150% Refund: Users claiming their refund through Rinbot receive an additional 50% of the amount lost. Funds will be available for buying and selling NFTs and Tokens on Rinbot.

The workflow works as follows:

1. Aldrin publishes package on-chain, thus initializing the `RefundPool` and receiving a `Publisher` object
2. Aldrin and partners fund the pool via permissionless endpoint `refund::fund`
3. Aldrin adds list of affected addresses and respective amounts lost to the `RefundPool`.
4. Users can freely claim 100% of their funds back via `refund::claim_refund`, or
5. Users can use Rinbot to claim 150% of their funds back, via `refund::claim_refund_boosted`


### Funding process
1. Clone the repo
2. Install dependencies by running `npm install`
3. Create `.env` in the root of the repo directory
4. Set up `REFUND_PACKAGE_ADDRESS`, `REFUND_POOL_OBJECT_ID` and `KEYPAIR_BECH32` variables. The `REFUND_PACKAGE_ADDRESS` and `REFUND_POOL_OBJECT_ID` should correspond to the production version of Refund Contract. The `KEYPAIR_BECH32` variable should represent the keypair of an account that will fund the Refund Pool.
5. Run the `examples/5-start-claim-phase.ts` by executing `yarn ts-node examples/fund.ts`.
