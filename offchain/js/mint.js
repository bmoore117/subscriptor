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

let merchantVkey = process.argv[2];
let userSkey = process.argv[3];
let anchorPolicyId = process.argv[4];
let anchorAssetName = process.argv[5];
let scriptAddr = process.argv[6];
let platformAddr = process.argv[7];
let platformPolicyId = process.argv[8];
let billableTokenPolicyId = process.argv[9] === "ada" ? "" : process.argv[9];
let billableTokenAssetName = process.argv[10] === "ada" ? "" : process.argv[10];
let billableTokenAmount = process.argv[11];
let billableTokenDepositAmount = process.argv[12];
let userAddr = process.argv[13];
let billingScheduleArg = process.argv[14] || "monthly";

let now = new Date();
let lower = new Date(now.getTime());
lower.setMinutes(lower.getMinutes() - 2);

let upper = new Date(now.getTime());
upper.setMinutes(upper.getMinutes() + 1);

const BillingSchedule = Data.Enum([
  Data.Object({ EveryNMilliseconds: Data.Tuple([Data.Integer()]) }),
  Data.Literal("Daily"),
  Data.Literal("Weekly"),
  Data.Literal("BiWeekly"),
  Data.Literal("Monthly"),
]);

const SubscriptionDetails = Data.Object({
    lock_until: Data.Integer(),
    billable_amount: Data.Integer(),
    billable_unit: Data.Bytes(),
    billable_unit_name: Data.Bytes(),
    merchant_vk: Data.Bytes(),
    billing_schedule: BillingSchedule,
});

const DAY_MS = 86400000n;

function parseBillingSchedule(arg) {
  switch (arg.toLowerCase()) {
    case "daily": return "Daily";
    case "weekly": return "Weekly";
    case "biweekly": return "BiWeekly";
    case "monthly": return "Monthly";
    default: return { EveryNMilliseconds: [BigInt(arg)] };
  }
}

function computeInitialLockUntil(upperTime, schedule) {
  const upper = BigInt(upperTime);
  if (typeof schedule === "object" && schedule.EveryNMilliseconds) {
    return upper + schedule.EveryNMilliseconds[0];
  }
  const startOfDay = (upper / DAY_MS) * DAY_MS;
  switch (schedule) {
    case "Daily": return startOfDay + DAY_MS;
    case "Weekly": return startOfDay + 7n * DAY_MS;
    case "BiWeekly": return startOfDay + 14n * DAY_MS;
    case "Monthly": {
      const d = new Date(upperTime);
      return BigInt(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).getTime());
    }
  }
}

let billingSchedule = parseBillingSchedule(billingScheduleArg);

// user skey in bech32
lucid.selectWallet.fromPrivateKey(userSkey);
const address = await lucid.wallet().address(); // Bech32 address: addr_1
console.log("Using wallet: " + address);

// policy id + CIP64 prefixed asset name
let assetName = anchorPolicyId + "000643b0" + fromText(anchorAssetName);
let contractUtxos = await lucid.utxosAt(scriptAddr);

// "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
let platformUtxos = await lucid.utxosAtWithUnit(platformAddr, platformPolicyId + "000643b0506c6174666f726d4665655363686564756c65");

let referenceInputs = contractUtxos.filter(function(utxo) { return utxo.scriptRef != null});
referenceInputs.push(platformUtxos[0]);

let redeemer = Data.to(new Constr(0, []));

let initialLockUntil = computeInitialLockUntil(upper.getTime(), billingSchedule);

var tx;
if (billableTokenPolicyId === "") {
  let datum = Data.to(
    { lock_until: initialLockUntil, 
      billable_amount: BigInt(billableTokenAmount), 
      billable_unit: "",
      billable_unit_name: "",
      merchant_vk: merchantVkey,
      billing_schedule: billingSchedule },
    SubscriptionDetails,
  );
  console.log("Using datum: " + datum);

  tx = await lucid.newTx()
  .readFrom(referenceInputs)
  .mintAssets({[assetName]: 1n}, redeemer)
  .pay.ToAddressWithData(
    scriptAddr, // sc address in bech32 addr_1 form
    {kind: "inline", value: datum},
    {[assetName]: 1n, lovelace: BigInt(billableTokenDepositAmount)},
  )
  .validFrom(lower.getTime())
  .validTo(upper.getTime())
  .addSigner(userAddr) // user vkey in bech32 addr_1 form
  .complete();
} else {
  let datum = Data.to(
    { lock_until: initialLockUntil, 
      billable_amount: BigInt(billableTokenAmount), 
      billable_unit: billableTokenPolicyId,
      billable_unit_name: fromText(billableTokenAssetName),
      merchant_vk: merchantVkey,
      billing_schedule: billingSchedule },
    SubscriptionDetails,
  );
  console.log("Using datum: " + datum);

  tx = await lucid.newTx()
  .readFrom(referenceInputs)
  .mintAssets({[assetName]: 1n}, redeemer)
  .pay.ToAddressWithData(
    scriptAddr, // sc address in bech32 addr_1 form
    {kind: "inline", value: datum},
    {[assetName]: 1n, [billableTokenPolicyId + fromText(billableTokenAssetName)]: BigInt(billableTokenDepositAmount)},
  )
  .validFrom(lower.getTime())
  .validTo(upper.getTime())
  .addSigner(userAddr) // user vkey in bech32 addr_1 form
  .complete();
}

const signedTx = await tx.sign.withWallet().complete();
const txHash = await signedTx.submit();
console.log("Tx hash: " + txHash);