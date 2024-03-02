if (require.main != module) {
    console.log('This script only to be run from the command line');
    return;
}

const jsonify = (param) => {
    return JSON.stringify(
        param,
        (key, value) => (typeof value === "bigint" || Number.isInteger(value) ? Number.parseInt(value.toString()) : value) // return everything else unchanged
    );
};

function expandData(obj) {
    let result = {};
    Object.entries(obj).forEach(([key, value]) => {
        if (key === "index") {
            result["constructor"] = value;
        } else {
            let arr = [];
            value.forEach((item) => {
                if (Number.isInteger(item) || typeof item === "bigint") {
                    arr.push({int: item});
                } else if (typeof item === "string") {
                    arr.push({bytes: item});
                }
            });
            result[key] = arr;
        }
    });
    return result;
}

const fs = require('node:fs');
import('lucid-cardano').then((Lucid) => {
    const SubscriptionDetails = Lucid.Data.Object({
        lock_until: Lucid.Data.Integer(),
        billable_amount: Lucid.Data.Integer(),
        merchant_vk: Lucid.Data.Bytes()
    });

    try {
        let data = fs.readFileSync('./intermediate/merchant.vkey');
        let dataJson = JSON.parse(data);
        let resultHex = Lucid.Data.to(
            { lock_until: BigInt(process.argv[2]) + 300n, billable_amount: 5000n, merchant_vk: dataJson.cborHex  },
            SubscriptionDetails,
        );

        let resultObj = Lucid.Data.from(resultHex);
        fs.writeFileSync("intermediate/subscription-metadata.json", jsonify(expandData(resultObj)));
    } catch (err) {
        console.error(err);
    }
})