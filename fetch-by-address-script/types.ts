import BigNumber from "bignumber.js";

export interface Transaction {
  kind: string;
  inputs: Input[];
  transactions: TransactionDetail[];
}

export interface Input {
  type: string;
  valueType: string;
  value: string;
}

export interface TransactionDetail {
  SplitCoins?: [string, { Input: number }[]];
  TransferObjects?: [{ Result: number }[], { Input: number }];
}

export interface TransactionDataByDigest {
  [key: string]: {
    sender: string;
    digest: string;
    amount: string;
    timestampMs: string;
  };
}

export interface TransactionDataBySender {
  [sender: string]: {
    sender: string;
    txCount: number;
    txDigestList: { digest: string; timestampMs: string; txSender: string }[];
  };
}

export interface ValidationResult {
  isValid: boolean;
  senderAmountExcludingGas?: BigNumber;
  senderAmountIncludingGas?: BigNumber;
}

export interface AggregatedAmount {
  affectedAddress: string;
  amount: string;
}
