import { blake2b } from "blakejs";
import { publicKeyToSuiAddress } from "../ts/utils";

// Example usage
// Assuming publicKey is provided as a Uint8Array
const publicKey = new Uint8Array([
  255, 206, 247, 194, 64, 18, 163, 39, 136, 125, 219, 7, 142, 250, 232, 151, 9,
  64, 172, 220, 197, 3, 85, 64, 153, 242, 62, 153, 19, 228, 7, 108,
]);
const suiAddress = publicKeyToSuiAddress(publicKey);
console.log(`Sui Address: ${suiAddress}`);
