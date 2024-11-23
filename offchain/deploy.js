import { Lucid, Blockfrost, Data, Constr, CML } from "@lucid-evolution/lucid";
import plutusJson from './subscriptor.subscriptor.spend.json' with {type: "json"}

let validator = {
  type: plutusJson.type,
  script: plutusJson.cborHex
};
let unitDatum = Data.to(new Constr(0, []));
console.log(unitDatum);

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;
 
const lucid = await Lucid(
  new Blockfrost("https://cardano-preview.blockfrost.io/api/v0", "previewmQLQcBrBQstluIBkoHpB9zH6Wjz0LFhF"),
  "Preview"
);

lucid.selectWallet.fromPrivateKey(process.argv[2]);
const address = await lucid.wallet().address(); // Bech32 address
console.log("Using wallet: " + address);

console.log(process.argv[3]);

let tx = await lucid.newTx().pay.ToAddressWithData(
  process.argv[3],
  {kind: "asHash", value: unitDatum},
  {lovelace: 0},
  null,
  validator
).complete();

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log(txHash);