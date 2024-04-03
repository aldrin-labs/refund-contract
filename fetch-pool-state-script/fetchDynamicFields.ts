import { PaginatedDynamicFieldInfos } from "@mysten/sui.js/client";
import { RPC_URL_FOR_TRANSACTIONS_POOL_STATE } from "./fetch-pool-state";

export const fetchDynamicFields = async (unclaimedTableId: string) => {
  let hasNextPage = true;
  let cursor: string | null | undefined = null;
  let addressesList: string[] = [];

  while (hasNextPage) {
    // eslint-disable-next-line no-await-in-loop
    const response = await fetch(RPC_URL_FOR_TRANSACTIONS_POOL_STATE, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        id: 1,
        method: "suix_getDynamicFields",
        jsonrpc: "2.0",
        params: [unclaimedTableId, cursor, null],
      }),
    });

    // eslint-disable-next-line no-await-in-loop
    const data: { result: PaginatedDynamicFieldInfos } = await response.json();
    const dynamicFieldsInfo: PaginatedDynamicFieldInfos = data.result;
    const dynamicFieldsList = dynamicFieldsInfo.data;

    const addressesListChunk = dynamicFieldsList.map(
      (el) => el.name.value as string
    );
    addressesList = [...addressesList, ...addressesListChunk];

    hasNextPage = data.result.hasNextPage;

    if (hasNextPage) {
      const { nextCursor } = data.result;
      cursor = nextCursor; // Update the request with the nextCursor value
    }
  }

  return addressesList;
};
