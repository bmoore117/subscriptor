if (require.main != module) {
    console.log('This script only to be run from the command line');
    return;
}

const plutusJson = require('./plutus.json');
let plutusVersion = "Plutus" + plutusJson.preamble.plutusVersion.toUpperCase();

const fs = require('node:fs');
import('lucid-cardano').then((Lucid) => {

    if (!process.env.CARDANO_NODE_MAGIC) {
        console.log('Missing environment variable CARDANO_NODE_MAGIC');
        return;
    }

    var network = "Custom";
    if (process.env.CARDANO_NODE_MAGIC == 2) {
        network = "Preview";
    } else if (process.env.CARDANO_NODE_MAGIC == 1) {
        network = "Preprod"
    } else if (process.env.CARDANO_NODE_MAGIC == 764824073) {
        network = "Mainnet"
    }

    Lucid.Lucid.new(null, network).then((lucid) => {
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
            return;
        }

        // if no args passed, we assume the script has no parameters
        var parameterizedValidator = compiledCode;
        if (process.argv.length > 2) {
            let args = process.argv.slice(3).map((elem) => Buffer.from(elem).toString());
            parameterizedValidator = Lucid.applyParamsToScript(compiledCode, args);
        }

        let output = {
            type: "PlutusScript" + plutusJson.preamble.plutusVersion.toUpperCase(),
            description: "",
            cborHex: parameterizedValidator
        };
    
        try {
            fs.writeFileSync(process.argv[2] + ".plutus", JSON.stringify(output));
            fs.writeFileSync(process.argv[2] + ".pol", hash);
        } catch (err) {
            console.error(err);
        }
    })
});



