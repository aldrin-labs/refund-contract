import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
  validateEnvVariable,
} from "./utils";

// yarn ts-node examples/refund/claim-boosted-refund.ts
(async () => {
  const affectedAddress = process.argv[2]!;
  const newAddress = process.argv[2]!;

  const contractAddress = validateEnvVariable("REFUND_PACKAGE_ADDRESS");
  const poolId = validateEnvVariable("REFUND_POOL_OBJECT_ID");
  const publisher = validateEnvVariable("PUBLISHER_ID");
  const keypairBech32 = validateEnvVariable("KEYPAIR_BECH32");

  const txb = new TransactionBlock();

  txb.moveCall({
    target: `${contractAddress}::booster::allow_boosted_claim`,
    arguments: [
      txb.object(publisher),
      txb.object(poolId),
      txb.pure(affectedAddress),
      txb.pure(newAddress),
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
