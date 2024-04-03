import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
  validateEnvVariable,
} from "./utils";

// yarn ts-node examples/4-fund-boosted.ts
(async () => {
  const contractAddress = validateEnvVariable("REFUND_PACKAGE_ADDRESS");
  const poolId = validateEnvVariable("REFUND_POOL_OBJECT_ID");
  const keypairBech32 = validateEnvVariable("KEYPAIR_BECH32");
  const keypair = Ed25519Keypair.fromSecretKey(
    hexStringToUint8Array(bech32ToHex(keypairBech32))
  );

  const txb = new TransactionBlock();
  const [coin] = txb.splitCoins(txb.gas, [txb.pure(98800370941221, "u64")]);

  txb.moveCall({
    target: `${contractAddress}::booster::fund`,
    arguments: [txb.object(poolId), coin],
  });

  // const res = await provider.devInspectTransactionBlock({
  //   sender: user,
  //   transactionBlock: txData.tx,
  // });

  const res = await signAndExecuteTransaction(txb, keypair);

  console.debug("res: ", res);
})();
