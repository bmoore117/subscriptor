const fs = require('node:fs');
const data = require('./intermediate/subscription-metadata.json');

let time = data.fields[0]
time.int = time.int + 300000;

try {
    fs.writeFileSync("intermediate/subscription-metadata-updated.json", JSON.stringify(data));
} catch (err) {
    console.error(err);
}

console.log(data.fields[1].int)