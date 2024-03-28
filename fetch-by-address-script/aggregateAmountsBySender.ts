import BigNumber from "bignumber.js";
import { TransactionDataByDigest, AggregatedAmount } from "./types";

/**
 * Aggregates the amounts for each sender in the provided transaction data.
 * @param {TransactionDataByDigest} transactionData The transaction data by digest.
 * @returns {Array<AggregatedAmount>} An array of objects containing the sender's address and the aggregated amount.
 */
export function aggregateAmountsBySender(transactionData: TransactionDataByDigest): AggregatedAmount[] {
    const aggregatedAmounts: { [sender: string]: BigNumber } = {};

    // Iterate over each entry (digest and data) in the transaction data
    for (const [digest, { sender, amount }] of Object.entries(transactionData)) {
        // Initialize sender's aggregated amount if not present
        if (!aggregatedAmounts[sender]) {
            aggregatedAmounts[sender] = new BigNumber(0);
        }
        // Add current amount to sender's aggregated amount
        aggregatedAmounts[sender] = aggregatedAmounts[sender].plus(new BigNumber(amount));
    }

    // Format the aggregated amounts into the desired output format
    const result: AggregatedAmount[] = Object.entries(aggregatedAmounts).map(([sender, amount]) => ({
        affectedAddress: sender,
        amount: amount.toString()
    }));

    return result;
}