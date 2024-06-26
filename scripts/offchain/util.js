import fs from 'fs';
import 'dotenv/config';
import {
  Blockfrost, 
  Lucid, 
} from "lucid-cardano";

export function getPlutusScript() {
  try {
    const data = JSON.parse(fs.readFileSync('../../plutus.json', 'utf8'));
    return data;
  } catch (error) {
    console.error('Error reading plutus.json:', error);
    return null; // Or handle the error differently
  }
}

// Initialize Lucid ------------------------------------------------------------
export const api_blockfrost = async (network, wallet) => {

  let key

  if (network == "Preview") {
    key =  process.env.BLOCKFROST_PREVIEW
  } else if (network == "Mainnet") {
    key =  process.env.BLOCKFROST_PREVIEW
  } else {
    return
  }

  const api = await Lucid.new(
    new Blockfrost(
      "https://cardano-"+network.toLowerCase()+".blockfrost.io/api/v0", 
      key),
      network,
  );

  return api;
}

// Retrieve validators from plutus.json ----------------------------------------
export function getValidators(endpoints, contract)  {

  var Validators = {}

  endpoints.forEach(function (endpoint) {
    Validators[endpoint.alias] =  {
      type: "PlutusV2",
      script: contract.validators.find((v) => v.title === endpoint.validator).compiledCode,
    }
  });
  return Validators
}

