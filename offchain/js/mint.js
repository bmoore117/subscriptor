import { Lucid, Blockfrost, Data, mintingPolicyToId, Constr } from "@lucid-evolution/lucid";
import { fromText } from "@lucid-evolution/core-utils"
import plutusJson from '../plutus.json' with {type: 'json'};

let mintingPolicy = {
    type: "PlutusV3",
    script: plutusJson.validators[0].compiledCode,
};
let policyId = mintingPolicyToId(mintingPolicy);

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0; 
const lucid = await Lucid(
  new Blockfrost("https://cardano-preview.blockfrost.io/api/v0", "previewmQLQcBrBQstluIBkoHpB9zH6Wjz0LFhF"),
  "Preview"
);

let now = new Date();
let lower = new Date(now.getTime());
lower.setMinutes(lower.getMinutes() - 2);

let upper = new Date(now.getTime());
upper.setMinutes(upper.getMinutes() + 1);

const SubscriptionDetails = Data.Object({
    lock_until: Data.Integer(),
    billable_amount: Data.Integer(),
    merchant_vk: Data.Bytes()
});

let datum = Data.to(
    // now.getTime() is in milliseconds, so add 5 minutes in millis
    { lock_until: BigInt(now.getTime()) + 300000n, billable_amount: 5000n, merchant_vk: process.argv[2]  }, // merchant vkey hash
    SubscriptionDetails,
);

// user skey in bech32
lucid.selectWallet.fromPrivateKey(process.argv[3]);
const address = await lucid.wallet().address(); // Bech32 address: addr_1
console.log("Using wallet: " + address);

// policy id + CIP64 prefixed asset name
let assetName = policyId + "000643b0" + fromText(process.argv[5]);

let redeemer = Data.to(new Constr(0, []));

let tx = await lucid.newTx().mintAssets({[assetName]: 1n}, redeemer)
.pay.ToAddressWithData(
    process.argv[6], // sc address in bech32 addr_1 form
    {kind: "inline", value: datum},
    {lovelace: 0, [assetName]: 1n},
  )
.validFrom(lower.getTime())
.validTo(upper.getTime())
.addSigner(process.argv[7]) // user vkey in bech32 addr_1 form
.complete();

console.log(tx);

//const signedTx = await tx.sign.withWallet().complete();
//const txHash = await signedTx.submit();
//console.log(txHash);