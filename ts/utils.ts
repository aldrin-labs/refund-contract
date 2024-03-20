import * as nacl from "tweetnacl";
import { decodeUTF8, encodeUTF8 } from "tweetnacl-util";
import { blake2b } from "blakejs";

export function base64ToByteArray(base64String: string) {
  const binaryString = window.atob(base64String);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

export function byteArrayToBase64(byteArray: Uint8Array): string {
  return Buffer.from(byteArray).toString("base64");
}

/**
 * Converts a hexadecimal string to a Uint8Array.
 *
 * @param {string} hexString - The hexadecimal string to convert.
 * @return {Uint8Array} - The resulting byte array.
 */
export function hexStringToByteArray(hexString: string): Uint8Array {
  // Remove the "0x" prefix if present
  const normalizedHexString = hexString.startsWith("0x")
    ? hexString.substring(2)
    : hexString;

  const byteArray = new Uint8Array(normalizedHexString.length / 2);
  for (let i = 0; i < normalizedHexString.length; i += 2) {
    byteArray[i / 2] = parseInt(normalizedHexString.substring(i, i + 2), 16);
  }
  return byteArray;
}

/**
 * Converts a Uint8Array to a hexadecimal string.
 *
 * @param byteArray The byte array to convert.
 * @returns The hexadecimal string representation of the byte array.
 */
export function byteArrayToHexString(byteArray: Uint8Array): string {
  return Array.from(byteArray, (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

/**
 * Converts a public key to a Sui address using BLAKE2b-256 for hashing,
 * and returns the address in hexadecimal format.
 *
 * @param publicKey - The public key as a Uint8Array.
 * @returns The Sui address as a hexadecimal string.
 */
export function publicKeyToSuiAddress(publicKey: Uint8Array): string {
  // Prepare the data to hash: 0x00 for Ed25519 + publicKey
  const dataToHash = new Uint8Array(1 + publicKey.length);
  dataToHash.set([0x00]); // Ed25519 signature scheme flag byte
  dataToHash.set(publicKey, 1); // Append publicKey

  // Hash the data using BLAKE2b-256
  const addressBytes = blake2b(dataToHash, undefined, 32); // 32 bytes = 256 bits

  // Convert the hashed address to a hex string
  const addressHex = Buffer.from(addressBytes).toString("hex");

  return addressHex;
}

export function generateSuiEd25519KeyPairAndAddress() {
  // Generate a new Ed25519 key pair
  const keyPair = nacl.sign.keyPair();

  // Prepare the data to hash: 0x00 for Ed25519 + publicKey
  const dataToHash = new Uint8Array(1 + keyPair.publicKey.length);
  dataToHash.set([0x00]); // Ed25519 flag byte
  dataToHash.set(keyPair.publicKey, 1); // Append publicKey

  // Hash the data using BLAKE2b
  const addressBytes = blake2b(dataToHash, undefined, 32); // 32 bytes = 256 bits

  // Convert the hashed address to a hex string (or other preferred format)
  const addressHex = Buffer.from(addressBytes).toString("hex");

  return {
    keyPair: keyPair,
    address: addressHex,
  };
}
