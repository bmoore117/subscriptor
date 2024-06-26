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
        // hardcoding a lock_until of five minutes into the future
        let resultHex = Lucid.Data.to(
            { lock_until: (BigInt(process.argv[2]) + 300n)*1000n, billable_amount: 5000n, merchant_vk: process.argv[3]  },
            SubscriptionDetails,
        );

        let resultObj = Lucid.Data.from(resultHex);
        fs.writeFileSync("intermediate/subscription-metadata.json", jsonify(expandData(resultObj)));
    } catch (err) {
        console.error(err);
    }
})