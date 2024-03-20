import { generateSuiEd25519KeyPairAndAddress } from "../ts/utils";

// Usage
const { keyPair, address } = generateSuiEd25519KeyPairAndAddress();

// // Convert the public and private keys to hex strings for display/output
// // Adjust here to slice the first 32 bytes of the secretKey for the private key
// const publicKeyHex = Buffer.from(keyPair.publicKey).toString("hex");
// const privateKeyHex = Buffer.from(keyPair.secretKey.slice(0, 32)).toString(
//   "hex"
// );

console.log(`Pubkey Key Bytes: `, keyPair.publicKey);
// console.log(`Private Key Bytes (extended): `, keyPair.secretKey);
console.log(`Private Key Bytes (short): `, keyPair.secretKey.slice(0, 32));
console.log(`Sui Address: ${address}`);
