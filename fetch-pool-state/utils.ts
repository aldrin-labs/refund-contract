import { AggregatedAmount } from "../fetch-by-address-script/types";
import { PoolObject } from "./types";

export function isPoolObject(obj: unknown): obj is PoolObject {
  if (typeof obj !== "object" || obj === null) return false;
  const { content } = obj as PoolObject;
  if (!content || typeof content !== "object") return false;

  const { fields } = content;
  if (!fields || typeof fields !== "object") return false;

  const { unclaimed } = fields;

  return (
    typeof unclaimed === "object" &&
    unclaimed !== null && // unclaimed should not be null
    typeof unclaimed.type === "string" &&
    typeof unclaimed.fields === "object" &&
    typeof unclaimed.fields.id === "object" &&
    typeof unclaimed.fields.id.id === "string" &&
    typeof unclaimed.fields.size === "string"
  );
}

export const getJsonBodyToFetchPoolState = (refundPoolId: string) => {
  const body = {
    id: 1,
    method: "sui_getObject",
    jsonrpc: "2.0",
    params: [
      refundPoolId,
      {
        showType: true,
        showOwner: true,
        showPreviousTransaction: true,
        showDisplay: true,
        showContent: true,
        showBcs: true,
        showStorageRebate: true,
      },
    ],
  };

  return body;
};

/**
 * Compare two structures: an array of AggregatedAmount objects and an array of addresses.
 * Checks if each address in the addresses array is present in the AggregatedAmount objects,
 * and vice versa. Also ensures that both arrays are of equal size.
 * @param {AggregatedAmount[]} aggregatedAmounts - The array of AggregatedAmount objects.
 * @param {string[]} addresses - The array of addresses.
 * @returns {boolean} - True if the structures match, false otherwise.
 */
export function compareStructures(
  aggregatedAmounts: AggregatedAmount[],
  addresses: string[]
): boolean {
  // Check if lengths are equal
  if (aggregatedAmounts.length !== addresses.length) {
    return false;
  }

  const addressSet = new Set(addresses);
  const foundAddresses = new Set<string>();

  // Check if each address in AggregatedAmounts is present in addresses
  for (const aggregatedAmount of aggregatedAmounts) {
    const address = aggregatedAmount.affectedAddress;
    if (!addressSet.has(address)) {
      return false;
    }
    foundAddresses.add(address);
  }

  // Check if each address in addresses is present in AggregatedAmounts
  for (const address of addresses) {
    if (!foundAddresses.has(address)) {
      return false;
    }
  }

  // If all checks pass, return true
  return true;
}
