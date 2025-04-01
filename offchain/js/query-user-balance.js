import { Lucid, Blockfrost, Data } from "@lucid-evolution/lucid";

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;
 
const lucid = await Lucid(
  new Blockfrost("https://cardano-preview.blockfrost.io/api/v0", "previewmQLQcBrBQstluIBkoHpB9zH6Wjz0LFhF"),
  "Preview"
);

let utxos = await lucid.utxosAt(process.argv[2]);
console.log(utxos);