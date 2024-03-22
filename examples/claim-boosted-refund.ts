import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
} from "./utils";

const REFUND_PACKAGE_ADDRESS =
  "0xd5bf5b4dda39f394a82590d23259c26dd4b570a2b0584d6d73b0599a9f525fac";
const REFUND_POOL_OBJECT_ID =
  "0xf8f7e8e3c4a4c08e5a334c45ed0b3c669b3b86098e7fc1ff9cfe062105c1f74e";

// yarn ts-node examples/refund/claim-boosted-refund.ts
(async () => {
  const keypairBech32 = process.env.KEYPAIR_BECH32;
  const boostedCap = process.env.BOOST_CAP_ID;

  if (keypairBech32 === undefined) {
    throw new Error(
      "Unable to find keypair variable `KEYPAIR_BECH32` in .env file."
    );
  }
  if (boostedCap === undefined) {
    throw new Error(
      "Unable to find keypair variable `BOOST_CAP_ID` in .env file."
    );
  }

  const txb = new TransactionBlock();

  txb.moveCall({
    target: `${REFUND_PACKAGE_ADDRESS}::booster::claim_refund_boosted`,
    arguments: [txb.object(boostedCap), txb.object(REFUND_POOL_OBJECT_ID)],
  });

  // const res = await provider.devInspectTransactionBlock({
  //   sender: user,
  //   transactionBlock: txData.tx,
  // });

  const keypair = Ed25519Keypair.fromSecretKey(
    hexStringToUint8Array(bech32ToHex(keypairBech32))
  );

  const res = await signAndExecuteTransaction(txb, keypair);

  console.debug("res: ", res);
})();
