import { Lucid, Data, Constr, Kupmios } from "@lucid-evolution/lucid";
import { fromText } from "@lucid-evolution/core-utils"
import { calculateMinLovelaceFromUTxO } from "@lucid-evolution/utils"

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0; 
const lucid = await Lucid(
  new Kupmios(
    process.env.KUPO_ENDPOINT_PREVIEW,
    process.env.OGMIOS_ENDPOINT_PREVIEW
  ),    
  "Preview"
);

let userSkey = process.argv[2];
let scriptAddr = process.argv[3];
let anchorPolicyId = process.argv[4];
let anchorAssetName = process.argv[5];
let platformAddr = process.argv[6];
let platformPolicyId = process.argv[7];
let merchantAddr = process.argv[8];

const SubscriptionDetails = Data.Object({
    lock_until: Data.Integer(),
    billable_amount: Data.Integer(),
    billable_unit: Data.Bytes(),
    billable_unit_name: Data.Bytes(),
    merchant_vk: Data.Bytes()
});

const PlatformDetails = Data.Object({
  fee_percentage_basis_points: Data.Integer(),
  platform_vk: Data.Bytes(),
  min_utxo_cost_lovelace: Data.Integer()
});

function findUtxos(contractUtxos, toSpend, targetAmount, billableAsset) {
  if (billableAsset === "") {
    // utxos with no assets except lovelace, and no script ref, which are not also the initial starting utxo
    let spendables = contractUtxos.filter(utxo => utxo.scriptRef == null && Object.keys(utxo.assets).length === 1 && !(utxo.txHash === toSpend[0].txHash && utxo.outputIndex == toSpend[0].outputIndex));
    if (spendables.length == 0) {
      throw new Error("No utxos found");
    }
    let i = 0;
    while (toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n) < targetAmount && i < spendables.length) {
      toSpend.push(spendables[i]);
      i++;
    }
  } else {
    // utxos with the billable asset, and no script ref, which are not also the initial starting utxo
    let spendables = contractUtxos.filter(utxo => utxo.scriptRef == null && Object.keys(utxo.assets).length > 1 && utxo.assets[billableAsset] > 0 && !(utxo.txHash === toSpend[0].txHash && utxo.outputIndex == toSpend[0].outputIndex));
    if (spendables.length == 0) {
      throw new Error("No utxos found");
    }
    let i = 0;
    while (toSpend.reduce((total, utxo) => total + utxo.assets[billableAsset], 0n) < targetAmount && i < spendables.length) {
      toSpend.push(spendables[i]);
      i++;
    }
  }
}

// init wallet
// 2 = merchant skey in bech32
lucid.selectWallet.fromPrivateKey(userSkey);
const address = await lucid.wallet().address(); // Bech32 address: addr_1
console.log("Using wallet: " + address);

// fetch existing datum & create updated datum
// 3 = contract address, 4 = contract policy, 5 = asset name
let contractUtxos = await lucid.utxosAt(scriptAddr);
let anchorAsset = anchorPolicyId + "000643b0" + fromText(anchorAssetName);
let subscription = contractUtxos.filter(function(utxo) { return utxo.assets[anchorAsset] == 1n});
let datum = Data.from(subscription[0].datum, SubscriptionDetails);
let newDatum = Data.to(
    // now.getTime() is in milliseconds, so add 5 minutes in millis
    { lock_until: datum.lock_until + 300000n, 
      billable_amount: datum.billable_amount, 
      billable_unit: datum.billable_unit, 
      billable_unit_name: datum.billable_unit_name,
       merchant_vk: datum.merchant_vk  }, // merchant vkey hash
    SubscriptionDetails,
);

// Aiken enum value 1, collect
let redeemer = Data.to(new Constr(1, []));

// 6 = platform address, 7 = platform policy id
// "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
let platformUtxos = await lucid.utxosAtWithUnit(platformAddr, platformPolicyId + "000643b0506c6174666f726d4665655363686564756c65");
let platformDetails = Data.from(platformUtxos[0].datum, PlatformDetails);

let referenceInputs = contractUtxos.filter(function(utxo) { return utxo.scriptRef != null});
referenceInputs.push(platformUtxos[0]);

function maxBigInt(a, b) {
  return a > b ? a : b;
}

let protocolParams = await lucid.config().provider.getProtocolParameters();
let billableAsset = datum.billable_unit + datum.billable_unit_name;
let toSpend = [subscription[0]];
var tx;

if (billableAsset === "") {
  let merchantAmount = maxBigInt(datum.billable_amount, platformDetails.min_utxo_cost_lovelace);
  console.log("Merchant amount: " + merchantAmount);
  
  let platformAmount = maxBigInt((platformDetails.fee_percentage_basis_points * datum.billable_amount) / 1000n, platformDetails.min_utxo_cost_lovelace);
  console.log("Platform amount: " + platformAmount);
  
  let outputUtxo = structuredClone(toSpend[0]);
  outputUtxo.assets.lovelace = 0;
  outputUtxo.txHash = null;
  outputUtxo.outputIndex = null;
  let minUtxo = calculateMinLovelaceFromUTxO(protocolParams.coinsPerUtxoByte, outputUtxo);
  
  if (toSpend[0].assets.lovelace < platformAmount + merchantAmount + minUtxo) {
    findUtxos(contractUtxos, toSpend, platformAmount + merchantAmount + minUtxo, billableAsset);
  }
  console.log("Spending " + toSpend.length + " utxo" + (toSpend.length > 1 ? "s" : ""));
  let totalAda = toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n)
  let remainder = totalAda - platformAmount - merchantAmount;

  tx = await lucid.newTx()
  .readFrom(referenceInputs).collectFrom(toSpend, redeemer)
  .pay.ToAddress(platformAddr, {lovelace: platformAmount})
  .pay.ToAddress(merchantAddr, {lovelace: merchantAmount}) // merchant address
  .pay.ToAddressWithData(
    scriptAddr, // contract address
    {kind: "inline", value: newDatum},
    {[anchorAsset]: 1n, lovelace: remainder},
  )
  .complete();
} else {
  let merchantAmount = datum.billable_amount;
  console.log("Merchant amount: " + merchantAmount);
  
  let platformAmount = (platformDetails.fee_percentage_basis_points * merchantAmount) / 1000n;
  console.log("Platform amount: " + platformAmount);
    
  if (toSpend[0].assets[billableAsset] < platformAmount + merchantAmount) {
    findUtxos(contractUtxos, toSpend, platformAmount + merchantAmount, billableAsset);
  }

  let spendableAda = toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n);
  let spendableAsset = toSpend.reduce((total, utxo) => total + utxo.assets[billableAsset], 0n);

  // TODO: this particular calculation may be slightly inaccurate, might need to construct utxo from nothing as below
  var outputUtxo = structuredClone(subscription[0]);
  outputUtxo.assets[billableAsset] = spendableAsset - platformAmount - merchantAmount;
  outputUtxo.assets.lovelace = null;
  outputUtxo.txHash = null;
  outputUtxo.outputIndex = null;
  let minUtxoContract = calculateMinLovelaceFromUTxO(protocolParams.coinsPerUtxoByte, outputUtxo);
  
  let platformUtxo = {assets: {}}
  platformUtxo.assets[billableAsset] = platformAmount;
  platformUtxo.address = platformAddr;
  let minUtxoPlatform = calculateMinLovelaceFromUTxO(protocolParams.coinsPerUtxoByte, platformUtxo);

  let merchantUtxo = {assets: {}}
  merchantUtxo.assets[billableAsset] = merchantAmount;
  merchantUtxo.address = merchantAddr;
  let minUtxoMerchant = calculateMinLovelaceFromUTxO(protocolParams.coinsPerUtxoByte, merchantUtxo);

  let minUtxoTotal = minUtxoContract + minUtxoMerchant + minUtxoPlatform;
  if (spendableAda < minUtxoTotal) {
    console.log("Finding additional utxos for ADA");
    findUtxos(contractUtxos, toSpend, minUtxoTotal, "");
  }
  console.log("Spending " + toSpend.length + " utxo" + (toSpend.length > 1 ? "s" : ""));
  let totalCurrency = toSpend.reduce((total, utxo) => {
    let amt = utxo.assets[billableAsset];
    if (amt == undefined) {
      amt = 0n;
    }
    return total + amt;
  }, 0n);
  let totalAda = toSpend.reduce((total, utxo) => total + utxo.assets.lovelace, 0n);
  let remainder = totalCurrency - platformAmount - merchantAmount;
  let remainderAda = totalAda - minUtxoMerchant - minUtxoPlatform;
  
  tx = await lucid.newTx()
  .readFrom(referenceInputs).collectFrom(toSpend, redeemer)
  .pay.ToAddress(platformAddr, {[billableAsset]: platformAmount})
  .pay.ToAddress(merchantAddr, {[billableAsset]: merchantAmount}) // merchant address
  .pay.ToAddressWithData(
    scriptAddr, // contract address
    {kind: "inline", value: newDatum},
    {[anchorAsset]: 1n, [billableAsset]: remainder, lovelace: remainderAda},
  )
  .complete();
}

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log("Tx hash: " + txHash);