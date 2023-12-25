const fs = require('node:fs');
import('lucid-cardano').then((Lucid) => {
    if (require.main === module) {
        const plutusJson = require('./plutus.json');
    
        var compiledCode = "";
        for (const validator of plutusJson.validators) {
            if (validator.title === process.argv[2]) { // first 2 args are node <js file name>, so real args start at 3rd index
                compiledCode = validator.compiledCode;
                break;
            } 
        }
    
        if (compiledCode === "") {
            console.log("Validator " + process.argv[2] + " not found");
            return;
        }
    
        let args = process.argv.slice(3);
    
        let parameterizedValidator = Lucid.applyParamsToScript(compiledCode, args);
    
        try {
            fs.writeFileSync(process.argv[2] + ".plutus", parameterizedValidator);
          } catch (err) {
            console.error(err);
          }
    } else {
        console.log('This script only to be run from the command line');
    }
});



