import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
  validateEnvVariable,
} from "./utils";

// yarn ts-node examples/claim-boosted-refund.ts
(async () => {
  const contractAddress = validateEnvVariable("REFUND_PACKAGE_ADDRESS");
  const poolId = validateEnvVariable("REFUND_POOL_OBJECT_ID");
  const keypairBech32 = validateEnvVariable("KEYPAIR_BECH32");

  const txb = new TransactionBlock();

  txb.moveCall({
    target: `${contractAddress}::refund::delete`,
    arguments: [txb.object(poolId)],
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
