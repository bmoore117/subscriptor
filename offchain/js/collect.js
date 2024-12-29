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

// init wallet
// 2 = merchant skey in bech32
lucid.selectWallet.fromPrivateKey(process.argv[2]);
const address = await lucid.wallet().address(); // Bech32 address: addr_1
console.log("Using wallet: " + address);

// fetch existing datum & create updated datum
// 3 = contract address, 4 = contract policy, 5 = asset name
let contractUtxos = await lucid.utxosAt(process.argv[3]);
let assetName = process.argv[4] + "000643b0" + fromText(process.argv[5]);
let subscription = contractUtxos.filter(function(utxo) { return utxo.assets[assetName] == 1n});
let datum = Data.from(subscription[0].datum, SubscriptionDetails);
let newDatum = Data.to(
    // now.getTime() is in milliseconds, so add 5 minutes in millis
    { lock_until: datum.lock_until + 300000n, billable_amount: datum.billable_amount, merchant_vk: datum.merchant_vk  }, // merchant vkey hash
    SubscriptionDetails,
);

// Aiken enum value 1, collect
let redeemer = Data.to(new Constr(1, []));

// 6 = platform address, 7 = platform policy id
// "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
let platformUtxos = await lucid.utxosAtWithUnit(process.argv[6], process.argv[7] + "000643b0506c6174666f726d4665655363686564756c65");
let platformDetails = Data.from(platformUtxos[0].datum, PlatformDetails);

// unit datum hash
let referenceInputs = contractUtxos.filter(function(utxo) { return utxo.scriptRef != null});
referenceInputs.push(platformUtxos[0]);

function maxBigInt(a, b) {
  return a > b ? a : b;
}
let platformAmount = maxBigInt(platformDetails.fee_percentage_basis_points * datum.billable_amount, platformDetails.min_utxo_cost_lovelace);
console.log("Platform amount: " + platformAmount);
let merchantAmount = maxBigInt(datum.billable_amount, platformDetails.min_utxo_cost_lovelace);
console.log("Merchant amount: " + platformAmount);

let toSpend = [subscription[0]];
if (toSpend[0].assets.lovelace < platformAmount + merchantAmount + 1284380n) { // experience-based lovelace amount necessary for datum + anchor
  // utxos with no assets except lovelace, and no script ref
  let spendables = contractUtxos.filter(utxo => utxo.scriptRef == null && Object.keys(utxo.assets).length === 1);
  let i = 0;
  while (toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n) < platformAmount + merchantAmount + 1284380n && i < spendables.length) {
    toSpend.push(spendables[i]);
    i++;
  }
}
console.log("Spending " + toSpend.length + " utxo" + (toSpend.length > 1 ? "s" : ""));
let totalAda = toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n)
let remainder = totalAda - platformAmount - merchantAmount;

let tx = await lucid.newTx()
.readFrom(referenceInputs)
.collectFrom(toSpend, redeemer)
.pay.ToAddress(process.argv[6], {lovelace: platformAmount})
.pay.ToAddress(process.argv[8], {lovelace: merchantAmount}) // merchant addr
.pay.ToAddressWithData(
  process.argv[3], // contract address
  {kind: "inline", value: newDatum},
  {[assetName]: 1n, lovelace: remainder},
)
.complete();

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log("Tx hash: " + txHash);