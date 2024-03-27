import { TransactionBlock } from "@mysten/sui.js/transactions";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import {
  signAndExecuteTransaction,
  hexStringToUint8Array,
  bech32ToHex,
  parseArrayFromString,
  parseArrayFromStringAsNumbers,
  validateEnvVariable,
} from "./utils";

// yarn ts-node examples/refund/claim-boosted-refund.ts
(async () => {
  const addressesString: string = process.argv[2];
  const amountsString: string = process.argv[3];

  const addresses: string[] = parseArrayFromString(addressesString);
  const amounts: number[] = parseArrayFromStringAsNumbers(amountsString);

  const contractAddress: string = validateEnvVariable("REFUND_PACKAGE_ADDRESS");
  const publisher: string = validateEnvVariable("PUBLISHER_ID");
  const poolId: string = validateEnvVariable("REFUND_POOL_OBJECT_ID");
  const keypairBech32: string = validateEnvVariable("KEYPAIR_BECH32");

  const txb = new TransactionBlock();

  txb.moveCall({
    target: `${contractAddress}::refund::add_addresses`,
    typeArguments: [],
    arguments: [
      txb.object(publisher),
      txb.object(poolId),
      txb.pure(addresses),
      txb.pure(amounts),
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
