import {
  RPC_URL_FOR_TRANSACTIONS_FETCHING,
  TARGET_ADDRESS,
  getRequestBodyForFetchingTransactionsByAddress,
} from "./config";
import { fetchTransactions } from "./fetchTransactions";

// yarn ts-node fetch-by-address-script/fetch-transaction-by-address.ts > fetch-txs-to-romas-address.txt 2>&1
export const fetchTransactionsByAddress = async () => {
  try {
    const transactionsSentToAddress = await fetchTransactions({
      url: RPC_URL_FOR_TRANSACTIONS_FETCHING,
      requestBody: getRequestBodyForFetchingTransactionsByAddress(TARGET_ADDRESS),
    });

    console.debug("Finished saving transacion details of senders.");
  } catch (error) {
    if (error instanceof Error) {
      console.error("Error [fetchTransactionsByAddress]:", error.message);
    } else {
      console.error("Error [fetchTransactionsByAddress]:", error);
    }
  }
};

fetchTransactionsByAddress();
