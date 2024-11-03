import { Lucid, Blockfrost } from "@lucid-evolution/lucid";

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;
 
const lucid = await Lucid(
  new Blockfrost("https://cardano-preview.blockfrost.io/api/v0", "previewmQLQcBrBQstluIBkoHpB9zH6Wjz0LFhF"),
  "Preview"
);

let contractAddress = "addr_test1wplrkhtkrj988yjvgt85e7uv77mlxe09s6pwrx9vjv5rs3q788u5p";
let assetName = "000643b0" + Buffer.from("TestSub").toString('hex');
let policyId = "7e3b5d761c8a73924c42cf4cfb8cf7b7f365e58682e198ac93283844";

let utxos = await lucid.utxosAtWithUnit(contractAddress, policyId + assetName);
let more = await lucid.utxoByUnit(policyId + assetName);

console.log(utxos);
console.log(more);
