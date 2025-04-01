import { Lucid, mintingPolicyToId, scriptFromNative, paymentCredentialOf, fromText, Kupmios } from "@lucid-evolution/lucid";

process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0; 
const lucid = await Lucid(
  new Kupmios(
    process.env.KUPO_ENDPOINT_PREVIEW,
    process.env.OGMIOS_ENDPOINT_PREVIEW
  ),    
  "Preview"
);

lucid.selectWallet.fromPrivateKey(process.argv[3]);
const address = await lucid.wallet().address(); 
const mintingPolicy = scriptFromNative({
  type: "all",
  scripts: [
    { type: "sig", keyHash: paymentCredentialOf(address).hash }
  ],
});
const policyId = mintingPolicyToId(mintingPolicy);

let assetName = "ImaginaryStablecoin";
const tx = await lucid
  .newTx()
  .mintAssets({
    [policyId + fromText(assetName)]: 100n,
  })
  .pay.ToAddress(address, { [policyId + fromText(assetName)]: 100n })
  .attach.MintingPolicy(mintingPolicy)
  .complete();
 
const signed = await tx.sign.withWallet().complete();
const txHash = await signed.submit();
console.log("Tx hash: " + txHash);