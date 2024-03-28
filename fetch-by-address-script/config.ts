import { SUI_DECIMALS } from "@mysten/sui.js/utils";

export const SUI_DENOMINATOR = 10 ** SUI_DECIMALS;

export const MAX_TX_PER_CALL_LIMIT = 50;
export const TARGET_ADDRESS = "0x444ea5358d83d13c837e2dc7d4caa563cb764f514a86999cf5330abc2f4ca466";

export const RPC_URL_FOR_TRANSACTIONS_FETCHING = "https://mainnet.suiet.app";

export const getRequestBodyForFetchingTransactionsByAddress = (address: string) => ({
  jsonrpc: "2.0",
  id: "2",
  method: "suix_queryTransactionBlocks",
  params: [
    {
      filter: { ToAddress: address },
      options: { showBalanceChanges: true, showEffects: true, showEvents: true, showInput: true },
    },
    null,
    MAX_TX_PER_CALL_LIMIT,
    true,
  ],
});