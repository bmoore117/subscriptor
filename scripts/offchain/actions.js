import {getValidators, getPlutusScript} from "./util.js"
import {
  toHex,
  Data,
  fromText,
  Constr,
  paymentCredentialOf,
  applyParamsToScript,
  applyDoubleCborEncoding
} from "lucid-cardano";

const VERBOSE = true;

const contracts = [
  { 
    alias: 'Mint',
    validator: 'subscriptor.handle_subscription',
  },
  { 
    alias: 'Spend',
    validator: 'subscriptor.redeem',
  },
]
const Validators = getValidators(contracts, getPlutusScript())

// #############################################################################
// ## MINT TOKEN
// #############################################################################
export const mint_token = async (lucid) => {

  const user_address = await lucid.wallet.address()
  console.log('INFO: User address:', user_address)

  // Parameterize Contracts ----------------------------------------------------
  if (VERBOSE) { console.log("INFO: Parameterizing Contracts"); }
  const currentTime = new Date().getTime() - 60 * 1000;                // (TTL: time to live)
  const laterTime = new Date(currentTime +  15 * 60 * 1000).getTime(); // 15 minutes


  // Transfer Token Contract - Mint Receipt Redeemer
  const paramScript_Mint = applyParamsToScript(
    Validators.Mint.script,
    [
        fromText("addr_test1vrkah44vlr3p7fzzr0rpyckcp06y2zlcaqqm3rdqcrg93eqzfxld7"),
        fromText("a72f2acea098215d5e6dafd61714507d4d7b225d1ec1e55abe203d0a")
    ],    
  );
  
  // Spend Redeemer -- Spends Base Token
  const paramScript_Spend = applyParamsToScript(
    Validators.Spend.script, 
    [
        fromText("addr_test1vrkah44vlr3p7fzzr0rpyckcp06y2zlcaqqm3rdqcrg93eqzfxld7"),
        fromText("a72f2acea098215d5e6dafd61714507d4d7b225d1ec1e55abe203d0a")
    ],    
  );

  const Validator_Mint = { type: "PlutusV2", script: applyDoubleCborEncoding(paramScript_Mint) };
  const Validator_Spend = { type: "PlutusV2", script: applyDoubleCborEncoding(paramScript_Spend) };

  // Contract Addresses
  const Address_ContractMint = lucid.utils.validatorToAddress(Validator_Mint);
  const Address_ContractSpend = lucid.utils.validatorToAddress(Validator_Spend);

  // Policy IDs
  const policyId_Mint = lucid.utils.validatorToScriptHash(Validator_Mint)
  if (VERBOSE) { console.log("INFO: Policy ID 1", policyId_Mint) };
  
  // Define Sacrificial Token Information --------------------------------------
  if (VERBOSE) { console.log("INFO: Defining Sacrificial and Primary Asset") };

  // Token 1 - Sacrificial token
  const assetName_token = "abc"
  const quantity_token = 1 
  const asset_token = `${policyId_Mint}${fromText(assetName_token)}`
//  const asset_token = `${policyId_Mint}${"000643b0546573744c75636964"}`
  // Token Metadata
  const metaDatum = {
    name: "Some Name",
    description: "Testing this contract.",
  };

  // Configure Script Datum and Redeemer ----------------------------------------
  if (VERBOSE) { console.log("INFO: Configuring Datum"); }

  // Configure Script Datum and Redeemer ----------------------------------------
  if (VERBOSE) { console.log("INFO: Configuring Datum"); }

  const metaDatumStructure = Data.Object({
    name: Data.Bytes(),
    description: Data.Bytes(),
  })
  const metadata = Data.to({
    name: paymentCredentialOf(user_address).hash,
    description: paymentCredentialOf(user_address).hash,
  }, metaDatumStructure
  )

  const scriptDatumStructure = Data.Object({
    time:         Data.Integer(),
    billable:          Data.Integer(),
    merchant:        Data.Bytes(),
  });
  const scriptDatum = Data.to(
    {
      time: BigInt(currentTime),
      billable: BigInt(10),
      merchant: paymentCredentialOf(user_address).hash,
    },
    scriptDatumStructure,
  );
  console.log(scriptDatum)


  // Mint Action 
  const mintRedeemer = Data.to(
    new Constr(0, [])
  ); 


  const utxos_contract = await lucid.utxosAt(Address_ContractMint)
  const scriptUtxo = utxos_contract[0]

  console.log("Address_ContractMint", Address_ContractMint)
  console.log("UTXO's:",  utxos_contract)
  console.log("scriptUtxo", scriptUtxo)

  // Build the First TX --------------------------------------------------------
  if (VERBOSE) { console.log("INFO: Building the TX"); }
  try {
    const tx = await lucid.newTx()
    .collectFrom((await lucid.wallet.getUtxos()).sort((a, b) => {
        return a.txHash.localeCompare(b.txHash) || a.outputIndex - b.outputIndex;
      }))
    .readFrom([scriptUtxo])
    .payToContract(
      Address_ContractSpend,
      { inline: scriptDatum },
      {
        ['lovelace']: BigInt(30000000),
      },
    )
    .mintAssets({[asset_token]: BigInt(quantity_token)}, mintRedeemer)
    .attachMintingPolicy(Validator_Mint)
    .addSigner(user_address)
    .validFrom(currentTime)
    .validTo(laterTime)
//    if (VERBOSE) { console.log("INFO: Raw TX:", await tx.toString()); }

    .complete();

    if (VERBOSE) { console.log("INFO: Raw TX:", tx.toString()); }

    // Request User Signature ----------------------------------------------------
    console.log("INFO: Requesting TX signature");
    const signedTx = await lucid.fromTx(txString).sign().complete(); 
    if (VERBOSE) { console.log("INFO: SIGNED TX ID:", signedTx.toHash()); }

  // Submit the TX -------------------------------------------------------------
  console.log("INFO: Attempting to submit the transaction");
  const txHash = await signedTx.submit();
  //const txHash  = 'TEMP'

  // Return with TX hash -------------------------------------------------------
  console.log(`TX Hash: ${txHash}`);
  return {
    tx_id: txHash,
    address: Address_ContractMint,
    policy_id: policyId_Mint,
  };

  }
  catch (e) {
    console.log(e)
  }
  


}
