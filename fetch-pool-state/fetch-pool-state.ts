import {
  compareStructures,
  getJsonBodyToFetchPoolState,
  isPoolObject,
} from "./utils";
import { fetchDynamicFields } from "./fetchDynamicFields";
import { fetchTransactions } from "../fetch-by-address-script/fetchTransactions";
import {
  RPC_URL_FOR_TRANSACTIONS_FETCHING,
  TARGET_ADDRESS,
  getRequestBodyForFetchingTransactionsByAddress,
} from "../fetch-by-address-script/config";

export const RPC_URL_FOR_TRANSACTIONS_POOL_STATE = "https://mainnet.suiet.app";
export const TARGET_POOL_OBJECT_ID =
  "0x82544a2f83c6ed1c1092d4b0e92837e2c3bd983228dd6529da632070b6657a97";

// yarn ts-node fetch-pool-state/fetch-pool-state.ts > fetch-pool-state.txt 2>&1
export const fetchPoolState = async () => {
  const requestBody = getJsonBodyToFetchPoolState(TARGET_POOL_OBJECT_ID);
  const response = await fetch(RPC_URL_FOR_TRANSACTIONS_POOL_STATE, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(requestBody),
  });

  const data = await response.json();
  const objectData = data.result.data as unknown;

  if (!isPoolObject(objectData)) {
    throw new Error("Not valid pool object");
  }

  const unclaimedTableId = objectData?.content.fields.unclaimed.fields.id.id;
  // console.debug("unclaimedTableId: ", unclaimedTableId)

  const addresses = await fetchDynamicFields(unclaimedTableId);
  // console.debug("addresses.length: ", addresses.length)
  console.dir(addresses, { maxArrayLength: null });

  const { aggreatedAmountsBySenderList } = await fetchTransactions({
    url: RPC_URL_FOR_TRANSACTIONS_FETCHING,
    requestBody: getRequestBodyForFetchingTransactionsByAddress(TARGET_ADDRESS),
  });

  const isEqualStructuresAndValues = compareStructures(
    aggreatedAmountsBySenderList,
    addresses
  );
  // console.debug("isEqualStructuresAndValues: ", isEqualStructuresAndValues)

  if (!isEqualStructuresAndValues) {
    throw new Error(
      "Addresses in Pool State is not equal to the addresses fetched by script"
    );
  }
};

fetchPoolState();
