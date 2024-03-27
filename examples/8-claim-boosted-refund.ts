import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js/utils";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
  validateEnvVariable,
} from "./utils";

// TODO: add support for rinbot_address field

// yarn ts-node examples/claim-boosted-refund.ts
(async () => {
  const contractAddress = validateEnvVariable("REFUND_PACKAGE_ADDRESS");
  const poolId = validateEnvVariable("REFUND_POOL_OBJECT_ID");
  const keypairBech32 = validateEnvVariable("KEYPAIR_BECH32");
  const boostedCap = validateEnvVariable("BOOST_CAP_ID");

  const txb = new TransactionBlock();

  txb.moveCall({
    target: `${contractAddress}::booster::claim_refund_boosted`,
    arguments: [
      txb.object(boostedCap),
      txb.object(poolId),
      txb.object(SUI_CLOCK_OBJECT_ID),
    ],
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
