import { Lucid, Blockfrost, Data, Constr } from "@lucid-evolution/lucid";
import plutusJson from '../subscriptor.subscriptor.spend.json' with {type: "json"}

let validator = {
  type: plutusJson.type.replace("Script", ""),
  script: plutusJson.cborHex
};
let unitDatum = Data.to(new Constr(0, []));

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;
 
const lucid = await Lucid(
  new Blockfrost("https://cardano-preview.blockfrost.io/api/v0", "previewmQLQcBrBQstluIBkoHpB9zH6Wjz0LFhF"),
  "Preview"
);

lucid.selectWallet.fromPrivateKey(process.argv[2]);
const address = await lucid.wallet().address(); // Bech32 address
console.log("Using wallet: " + address);

var tx;
if (process.argv[3] === "0") {
  tx = await lucid.newTx().pay.ToAddressWithData(
    process.argv[4],
    {kind: "asHash", value: unitDatum},
    {lovelace: 0},
    validator
  )
  .complete();
} else {
  tx = await lucid.newTx().pay.ToAddressWithData(
    process.argv[6],
    {kind: "inline", value: unitDatum},
    {lovelace: BigInt(process.argv[7])}
  )
  .complete();
}

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log("Tx hash: " + txHash);