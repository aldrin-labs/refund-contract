import { SuiTransactionBlockResponse, GasCostSummary } from "@mysten/sui.js/client";
import BigNumber from "bignumber.js";
import { SUI_DENOMINATOR } from "./config";
import { saveDataToJsonFile } from "./utils";
import { TARGET_ADDRESS } from "./config";
import {
  checkIsTransactionHasSuccessStatus,
  checkThatSenderIsTargetAddress,
  validateTransaction,
  checkAddressPresence,
  validateBalanceChanges,
  filterTransactionsByTimeRange,
  checkSenderUniqueness,
  calculateTotalFunds,
  sortByTimestamp,
  sortByAmount,
  calculateTotalFundsFromAggregatedAmounts,
} from "./utils";
import { aggregateAmountsBySender } from "./aggregateAmountsBySender";

export const fetchTransactions = async ({
  url,
  requestBody,
}: {
  url: string;
  requestBody: { jsonrpc: string; id: string; method: string; params: unknown[] };
}) => {
  let hasNextPage = true;
  const senderAndAmountObj: {
    [sender: string]: { sender: string; digest: string; amount: string; amountFormatted: string; timestampMs: string };
  } = {};

  while (hasNextPage) {
    // eslint-disable-next-line no-await-in-loop
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    // eslint-disable-next-line no-await-in-loop
    const data = await response.json();
    const txData: SuiTransactionBlockResponse[] = data.result.data;

    // Process each transaction digest
    // eslint-disable-next-line no-restricted-syntax
    for (const transaction of txData) {
      if (!transaction.transaction) {
        throw new Error("Empty outer transaction");
      }

      if (!transaction.transaction.data.sender) {
        throw new Error("Empty sender");
      }

      if (!transaction.balanceChanges) {
        throw new Error("Empty balanceChanges");
      }

      if (!transaction.transaction?.data.transaction) {
        throw new Error("Empty inner transaction");
      }

      if (!transaction.effects) {
        throw new Error("Empty transaction effects");
      }

      if (!transaction.timestampMs) {
        throw new Error("No timestamp for tx present");
      }

      const isSuccessfulTransaction = checkIsTransactionHasSuccessStatus(transaction);
      if (!isSuccessfulTransaction) {
        console.log(transaction.digest, "isFailedTransaction");
        continue;
      }

      const isSenderIsTargetAddress = checkThatSenderIsTargetAddress(transaction.transaction.data.sender);
      if (isSenderIsTargetAddress) {
        console.log(transaction.digest, "isSenderIsTargetAddress");
        continue;
      }

      const isTransactionValid = validateTransaction(transaction.transaction.data.transaction);
      if (!isTransactionValid) {
        console.log(transaction.digest, "isTransactionValid");

        continue;
      }

      const isTransactionIsSendSuiToTargetAddress = checkAddressPresence(
        transaction.transaction.data.transaction,
        TARGET_ADDRESS,
      );
      if (!isTransactionIsSendSuiToTargetAddress) {
        console.log(transaction.digest, "isTransactionIsSendSuiToTargetAddress");

        continue;
      }

      const { computationCost, storageCost, storageRebate }: GasCostSummary = transaction.effects.gasUsed;
      const totalGasFee = new BigNumber(computationCost).plus(storageCost).minus(storageRebate);

      const { isValid: isBalanceChangesIsValid, senderAmountExcludingGas } = validateBalanceChanges(
        transaction,
        transaction.transaction.data.sender,
        TARGET_ADDRESS,
        totalGasFee,
      );
      if (!isBalanceChangesIsValid) {
        console.log(transaction.digest, "isBalanceChangesIsValid");

        continue;
      }

      const valueAmount = senderAmountExcludingGas?.toString();
      if (!valueAmount) {
        console.log(transaction.digest, "valueAmount");
        continue;
      }

      const digest = transaction.digest;
      const sender = transaction.transaction.data.sender;
      const amount = valueAmount;
      const timestampMs = transaction.timestampMs;
      const amountFormatted = new BigNumber(amount).div(SUI_DENOMINATOR).toString();

      senderAndAmountObj[digest] = { sender, digest, amount, amountFormatted, timestampMs };
    }

    hasNextPage = data.result.hasNextPage;

    if (hasNextPage) {
      const { nextCursor } = data.result;
      requestBody.params[1] = nextCursor; // Update the request with the nextCursor value
    }
  }

  // const filtredOutTransactionData = filterTransactionsByTimeRange(senderAndAmountObj, 1710759792941, 1710833073914);
  const filtredOutTransactionData = filterTransactionsByTimeRange(senderAndAmountObj);

  checkSenderUniqueness(filtredOutTransactionData);

  const totalFunds = calculateTotalFunds(filtredOutTransactionData);
  console.log("Total funds collected (not aggregated) (raw, in MIST): ", totalFunds.toString());
  console.log("Total funds collected (not aggregated) (in SUI): ", totalFunds.div(SUI_DENOMINATOR).toString());

  // Aggreated amounts by sender
  const aggreatedAmountsBySenderList = aggregateAmountsBySender(filtredOutTransactionData);
  const totalFundsByAggregatedResult = calculateTotalFundsFromAggregatedAmounts(aggreatedAmountsBySenderList)
  console.log("Total funds collected (aggregated) (raw, in MIST): ", totalFundsByAggregatedResult.toString());
  console.log("Total funds collected (aggregated) (in SUI): ", totalFundsByAggregatedResult.div(SUI_DENOMINATOR).toString());
  saveDataToJsonFile(aggreatedAmountsBySenderList, "fetched-txs-to-romas-address-aggregated");

  saveDataToJsonFile(filtredOutTransactionData, "fetched-txs-to-romas-address");
  saveDataToJsonFile(sortByTimestamp(filtredOutTransactionData), "fetched-txs-to-romas-address-order-by-timestamp");
  saveDataToJsonFile(sortByAmount(filtredOutTransactionData), "fetched-txs-to-romas-address-order-by-amount");

  // Just for output values which should be used in examples/3-fund.ts
  const baseAmountInMist = totalFundsByAggregatedResult.toString()
  const baseAmountInSui = new BigNumber(baseAmountInMist).div(SUI_DENOMINATOR).toString();

  const boostedAmountInMist = new BigNumber(baseAmountInMist).div(2).toString();
  const boostedAmountInSui = new BigNumber(boostedAmountInMist).div(SUI_DENOMINATOR).toString();

  const totalAmountInMist = new BigNumber(baseAmountInMist).plus(boostedAmountInMist).toString();
  const totalAmountInSui = new BigNumber(totalAmountInMist).div(SUI_DENOMINATOR).toString();

  console.log("BASE AMOUNT FOR ALL WALLETS (MIST): ", baseAmountInMist);
  console.log("BASE AMOUNT FOR ALL WALLETS (SUI): ", baseAmountInSui);
  console.log("BOOSTED AMOUNT FOR ALL WALLETS (MIST): ", boostedAmountInMist);
  console.log("BOOSTED AMOUNT FOR ALL WALLETS (SUI): ", boostedAmountInSui);
  console.log("TOTAL AMOUNT FOR ALL WALLETS (MIST): ", totalAmountInMist);
  console.log("TOTAL AMOUNT FOR ALL WALLETS (SUI): ", totalAmountInSui);


  console.debug("Finished retrieving transactions.");

  return filtredOutTransactionData;
};
