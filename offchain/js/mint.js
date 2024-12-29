import { Lucid, Blockfrost, Data, mintingPolicyToId, Constr, Kupmios } from "@lucid-evolution/lucid";
import { fromText } from "@lucid-evolution/core-utils"

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0; 
const lucid = await Lucid(
  new Kupmios(
    process.env.KUPO_ENDPOINT_PREVIEW,
    process.env.OGMIOS_ENDPOINT_PREVIEW
  ),    
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

const PlatformDetails = Data.Object({
  fee_percentage_basis_points: Data.Integer(),
  platform_vk: Data.Bytes(),
  min_utxo_cost_lovelace: Data.Integer()
});

let datum = Data.to(
    // now.getTime() is in milliseconds, so add 5 minutes in millis
    { lock_until: BigInt(upper.getTime()) + 300000n, billable_amount: 5000n, merchant_vk: process.argv[2]  }, // merchant vkey hash
    SubscriptionDetails,
);

console.log("Using datum: " + datum);

// user skey in bech32
lucid.selectWallet.fromPrivateKey(process.argv[3]);
const address = await lucid.wallet().address(); // Bech32 address: addr_1
console.log("Using wallet: " + address);

// policy id + CIP64 prefixed asset name
let assetName = process.argv[4] + "000643b0" + fromText(process.argv[5]);

let redeemer = Data.to(new Constr(0, []));

let contractUtxos = await lucid.utxosAt(process.argv[6]);

// unit datum hash
let deployedContract = contractUtxos.filter(function(utxo) { return utxo.datumHash === "923918e403bf43c34b4ef6b48eb2ee04babed17320d8d1b9ff9ad086e86f44ec"});

// "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
let platformUtxos = await lucid.utxosAtWithUnit(process.argv[7], process.argv[8] + "000643b0506c6174666f726d4665655363686564756c65");
let converted = Data.from(platformUtxos[0].datum, PlatformDetails);

let tx = await lucid.newTx()
.readFrom(deployedContract)
.mintAssets({[assetName]: 1n}, redeemer)
.pay.ToAddressWithData(
    process.argv[6], // sc address in bech32 addr_1 form
    {kind: "inline", value: datum},
    {[assetName]: 1n, lovelace: 4n*converted.min_utxo_cost_lovelace},
  )
.validFrom(lower.getTime())
.validTo(upper.getTime())
.addSigner(process.argv[9]) // user vkey in bech32 addr_1 form
.complete();

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log("Tx hash: " + txHash);