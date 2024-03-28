import * as fs from "fs";

import { SuiTransactionBlockResponse } from "@mysten/sui.js/client";
import BigNumber from "bignumber.js";
import { TransactionDataByDigest, Transaction, ValidationResult } from "./types";
import { TARGET_ADDRESS } from "./config";

/**
 * Filters transactions that fall within the specified time range.
 * @param {TransactionDataByDigest} obj The object containing transactions.
 * @param {number} startTime The start time of the time range in milliseconds.
 * @param {number} endTime The end time of the time range in milliseconds.
 * @return {TransactionDataByDigest}
 * Returns the filtered object containing transactions within the specified time range.
 */
export function filterTransactionsByTimeRange(
  obj: TransactionDataByDigest,
  startTime?: number,
  endTime?: number,
): TransactionDataByDigest {
  const filteredObj: TransactionDataByDigest = {};

  const keys = Object.keys(obj);
  for (const key of keys) {
    const transaction = obj[key];
    const transactionTime = parseInt(transaction.timestampMs);

    if (
      (startTime === undefined || transactionTime >= startTime) &&
      (endTime === undefined || transactionTime <= endTime)
    ) {
      filteredObj[key] = transaction;
    }
  }

  return filteredObj;
}

/**
 * Sorts the given object by timestampMs.
 * @param {TransactionDataByDigest} obj The object to sort.
 * @return {TransactionDataByDigest} Returns the sorted object by timestampMs.
 */
export function sortByTimestamp(obj: TransactionDataByDigest): TransactionDataByDigest {
  const sortedObj: TransactionDataByDigest = {};
  const keys = Object.keys(obj);

  keys.sort((a, b) => {
    return parseInt(obj[a].timestampMs) - parseInt(obj[b].timestampMs);
  });

  keys.forEach((key) => {
    sortedObj[key] = obj[key];
  });

  return sortedObj;
}

/**
 * Sorts the given object by amount using BigNumber.
 * @param {TransactionDataByDigest} obj The object to sort.
 * @return {TransactionDataByDigest} Returns the sorted object by amount.
 */
export function sortByAmount(obj: TransactionDataByDigest): TransactionDataByDigest {
  const sortedObj: TransactionDataByDigest = {};
  const keys = Object.keys(obj);

  keys.sort((a, b) => {
    const amountA = new BigNumber(obj[a].amount);
    const amountB = new BigNumber(obj[b].amount);
    return amountB.comparedTo(amountA);
  });

  keys.forEach((key) => {
    sortedObj[key] = obj[key];
  });

  return sortedObj;
}

/**
 * Validates the structure of a transaction.
 * @param {unknown} data The transaction data to validate.
 * @return {boolean} Returns true if the data is valid, otherwise false.
 */
export function validateTransaction(data: unknown): boolean {
  if (typeof data !== "object" || data === null) {
    return false;
  }

  const transaction = data as Transaction;

  return (
    transaction.kind === "ProgrammableTransaction" &&
    Array.isArray(transaction.inputs) &&
    transaction.inputs.every(
      (input) =>
        typeof input === "object" &&
        input !== null &&
        input.type === "pure" &&
        (input.valueType === "u64" || input.valueType === "address") &&
        typeof input.value === "string",
    )
  );
}

/**
 * Checks if the specified address is present in the inputs array of the transaction data.
 * @param {unknown} data The transaction data.
 * @param {string} address The address to check for presence.
 * @return {boolean} Returns true if the address is present, otherwise false.
 */
export function checkAddressPresence(data: unknown, address: string): boolean {
  if (typeof data !== "object" || data === null) {
    return false;
  }

  const transaction = data as Transaction;

  return transaction.inputs.some((input) => input.valueType === "address" && input.value === address);
}

/**
 * Checks if the 'sender' field is unique across all objects.
 * @param {Record<string, { sender: string, digest: string, amount: string }>} obj The object to check.
 */
export function checkSenderUniqueness(obj: Record<string, { sender: string; digest: string; amount: string }>) {
  const sendersSet = new Set<string>();

  Object.keys(obj).forEach((key) => {
    const sender = obj[key].sender;
    const digest = obj[key].digest;
    if (sendersSet.has(sender)) {
      console.log(`Duplicate sender found: ${sender}, digest: ${digest}`);
    } else {
      sendersSet.add(sender);
    }
  });
}

/**
 * Checks that sender of transaction is not target address
 * @param {string} sender The sender of transaction
 * @return {boolean}
 */
export function checkThatSenderIsTargetAddress(sender: string): boolean {
  return sender === TARGET_ADDRESS;
}

/**
 * Checks if a transaction has a success status based on the status in the given transaction block response.
 * @param {SuiTransactionBlockResponse} transaction The transaction block response to check.
 * @return {boolean} Returns true if the transaction has a success status, otherwise false.
 */
export function checkIsTransactionHasSuccessStatus(transaction: SuiTransactionBlockResponse): boolean {
  return transaction.effects?.status.status === "success";
}

/**
 * Calculates the total amount of funds collected by summing the 'amount' values in the given object.
 * @param {Record<string, { sender: string, digest: string, amount: string }>} obj
 * The object containing the transactions.
 * @return {BigNumber} The total amount of funds collected.
 */
export function calculateTotalFunds(
  obj: Record<string, { sender: string; digest: string; amount: string }>,
): BigNumber {
  let totalAmount = new BigNumber(0);

  Object.values(obj).forEach((transaction) => {
    totalAmount = totalAmount.plus(new BigNumber(transaction.amount));
  });

  return totalAmount;
}

/**
 * Validates balance changes and returns the sender's amount excluding and including gas if valid.
 * @param {unknown} obj The object to validate.
 * @param {string} sender The sender's address.
 * @param {string} target The target's address.
 * @param {BigNumber} totalGasFee The total gas fee.
 * @return {ValidationResult} Returns an object containing a boolean indicating whether the balance changes are valid,
 * the sender's amount excluding gas, and the sender's amount including gas if valid.
 */
export function validateBalanceChanges(
  obj: unknown,
  sender: string,
  target: string,
  totalGasFee: BigNumber,
): ValidationResult {
  if (typeof obj !== "object" || obj === null) {
    return { isValid: false };
  }

  if (!("balanceChanges" in obj)) {
    return { isValid: false };
  }

  const balanceChanges = obj["balanceChanges"] as unknown[];
  if (!Array.isArray(balanceChanges) || balanceChanges.length !== 2) {
    return { isValid: false };
  }

  const firstChange = balanceChanges[0] as { owner: { AddressOwner: string }; coinType: string; amount: string };
  const secondChange = balanceChanges[1] as { owner: { AddressOwner: string }; coinType: string; amount: string };

  // Check that both amounts are in SUI
  if (firstChange.coinType !== "0x2::sui::SUI" || secondChange.coinType !== "0x2::sui::SUI") {
    return { isValid: false };
  }

  // Finding sender and target
  const senderChange =
    sender === firstChange.owner.AddressOwner
      ? firstChange
      : sender === secondChange.owner.AddressOwner
        ? secondChange
        : null;

  const targetChange =
    target === firstChange.owner.AddressOwner
      ? firstChange
      : target === secondChange.owner.AddressOwner
        ? secondChange
        : null;

  if (senderChange === null || targetChange === null) {
    return { isValid: false };
  }

  // Check if the sender has a negative amount and the target has a positive amount
  if (new BigNumber(senderChange.amount).isPositive() || new BigNumber(targetChange.amount).isNegative()) {
    return { isValid: false };
  }

  const senderAmount = new BigNumber(senderChange.amount);
  const targetAmount = new BigNumber(targetChange.amount);

  // Check that amounts are equal by absolute value
  if (!senderAmount.absoluteValue().minus(totalGasFee).isEqualTo(targetAmount.absoluteValue())) {
    return { isValid: false };
  }

  // Check if the sender's address matches the sender of the senderChange
  if (senderChange.owner.AddressOwner !== sender) {
    return { isValid: false };
  }

  // Check if the target's address matches the sender of the targetChange
  if (targetChange.owner.AddressOwner !== target) {
    return { isValid: false };
  }

  const senderAmountExcludingGas = senderAmount.absoluteValue().minus(totalGasFee);
  const senderAmountIncludingGas = senderAmount.absoluteValue();

  return { isValid: true, senderAmountExcludingGas, senderAmountIncludingGas };
}


/**
 * Save data to a JSON file with formatted content.
 *
 * @async
 * @function
 * @param {object | object[]} data - The data to be saved to the JSON file.
 * @param {string} filename - The name of the JSON file (excluding the file extension).
 * @return {Promise<void>} A Promise that resolves when the data is successfully saved.
 * @throws {Error} Throws an error if there is an issue saving the data to the file.
 *
 * @example
 * // Assuming retrievelAllPools returns an object or array of data
 * const cetusPools = await retrievelAllPools();
 * await saveDataToJsonFile(cetusPools, 'cetusPools');
 */
export async function saveDataToJsonFile(data: object | object[], filename: string): Promise<void> {
  try {
    const jsonData: string = JSON.stringify(data, null, 2);
    const filePath = `${__dirname}/${filename}.json`;

    await fs.promises.writeFile(filePath, jsonData);

    console.log(`Data has been saved to ${filename}.json`);
  } catch (error) {
    console.error("Error saving data to file:", error);
  }
}
