import * as nacl from "tweetnacl";
import { base64ToByteArray, byteArrayToBase64 } from "./utils";

function main() {
  const msg: Uint8Array = base64ToByteArray(process.argv[1]);
  const privateKey64 = base64ToByteArray(process.argv[2]);

  const signedMsg = nacl.sign(msg, privateKey64);

  console.log(`Signature (Base64): ${byteArrayToBase64(signedMsg)}`);
}

main();
