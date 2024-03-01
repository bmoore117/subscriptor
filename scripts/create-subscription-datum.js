if (require.main != module) {
    console.log('This script only to be run from the command line');
    return;
}

const jsonify = (param) => {
    return JSON.stringify(
        param,
        (key, value) => (typeof value === "bigint" ? value.toString() : value) // return everything else unchanged
    );
};

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
            { lock_until: BigInt(Math.floor(Date.now() / 1000)), billable_amount: 5000n, merchant_vk: dataJson.cborHex  },
            SubscriptionDetails,
        );

        let resultObj = Lucid.Data.from(resultHex);
        fs.writeFileSync("intermediate/subscription-metadata.json", jsonify(resultObj));
    } catch (err) {
        console.error(err);
    }
})