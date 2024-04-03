import "dotenv/config";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  ExecuteTransactionBlockParams,
  SuiClient,
  SuiTransactionBlockResponse,
} from "@mysten/sui.js/client";
const GAS_BUDGET = 50_000_000;
import { bech32 } from "bech32";

export const signAndExecuteTransaction = async (
  transactionBlock: TransactionBlock,
  signer: Ed25519Keypair,
  input: Omit<
    ExecuteTransactionBlockParams,
    "transactionBlock" | "signature"
  > = { options: { showEffects: true } }
): Promise<SuiTransactionBlockResponse> => {
  const suiProviderUrl = "https://sui-rpc.publicnode.com";
  const provider = new SuiClient({ url: suiProviderUrl });

  transactionBlock.setGasBudget(GAS_BUDGET);

  const transactionResponse: SuiTransactionBlockResponse =
    await provider.signAndExecuteTransactionBlock({
      transactionBlock,
      signer,
      ...input,
    });

  return transactionResponse;
};

export function hexStringToUint8Array(hexStr: string) {
  if (hexStr.length % 2 !== 0) {
    throw new Error("Invalid hex string length.");
  }

  const byteValues: number[] = [];

  for (let i = 0; i < hexStr.length; i += 2) {
    const byte: number = parseInt(hexStr.slice(i, i + 2), 16);

    if (Number.isNaN(byte)) {
      throw new Error(
        `Invalid hex value at position ${i}: ${hexStr.slice(i, i + 2)}`
      );
    }

    byteValues.push(byte);
  }

  return new Uint8Array(byteValues);
}

export function bech32ToHex(bech32Address: string): string {
  try {
    // Decode the Bech32 address to obtain the words (data part)
    const decoded = bech32.decode(bech32Address);

    // Convert the words to a Buffer
    const buffer = Buffer.from(bech32.fromWords(decoded.words));

    // Convert to hexadecimal
    let hex = buffer.toString("hex");

    // Remove the first two '00's from the prefix if present
    if (hex.startsWith("00")) {
      hex = hex.substring(2);
    }

    // Convert the Buffer to a hex string
    return hex;
  } catch (error) {
    console.error("Error converting Bech32 address to hex:", error);
    return "";
  }
}

// A function to parse a comma-separated string into an array of numbers
export function parseArrayFromStringAsNumbers(input: string): number[] {
  return input.split(",").map(Number);
}

// A function to parse a comma-separated string into an array of numbers
export function parseArrayFromString(input: string): string[] {
  return input.split(",").map(String);
}

// A function to add two arrays of numbers. It returns a new array with the summed elements.
export function addArrays(array1: number[], array2: number[]): number[] {
  const maxLength = Math.max(array1.length, array2.length);
  const result: number[] = [];

  for (let i = 0; i < maxLength; i++) {
    const val1 = array1[i] || 0; // Use 0 if the array doesn't have an element at this index
    const val2 = array2[i] || 0;
    result.push(val1 + val2);
  }

  return result;
}

// Function to validate that an environment variable is not undefined
export function validateEnvVariable(name: string): string {
  const value = process.env[name];
  if (value === undefined) {
    throw new Error(`Environment variable \`${name}\` is not set.`);
  }
  return value;
}
