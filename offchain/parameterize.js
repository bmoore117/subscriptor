import { applyParamsToScript } from "@lucid-evolution/lucid";
import * as fs from 'fs';
import plutusJson from './plutus.json' with {type: "json"}

var compiledCode = "";
var hash = "";
for (const validator of plutusJson.validators) {
    if (validator.title === process.argv[2]) { // first 2 args are node <js file name>, so real args start at 3rd index
        compiledCode = validator.compiledCode;
        hash = validator.hash;
        break;
    } 
}
    
if (compiledCode === "") {
    console.log("Validator " + process.argv[2] + " not found");
} else {
    // if no args passed, we assume the script has no parameters
    var parameterizedValidator = compiledCode;
    if (process.argv.length > 2) {
        let args = process.argv.slice(3).map((elem) => Buffer.from(elem).toString());
        parameterizedValidator = applyParamsToScript(compiledCode, args);
    }

    let output = {
        type: "PlutusScript" + plutusJson.preamble.plutusVersion.toUpperCase(),
        description: "",
        cborHex: parameterizedValidator
    };
        
    try {
        fs.writeFileSync(process.argv[2] + ".json", JSON.stringify(output));
    } catch (err) {
        console.error(err);
    }
}





