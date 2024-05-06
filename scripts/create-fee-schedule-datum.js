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

const fs = require('node:fs');
import('lucid-cardano').then((Lucid) => {
    const PlatformFeeSchedule = Lucid.Data.Object({
        fee_percentage_basis_points: Lucid.Data.Integer(),
        platform_vk: Lucid.Data.Bytes(),
        min_utxo_cost_lovelace: Lucid.Data.Integer()
    });

    try {
        let jsonObject = { fee_percentage_basis_points: 25n, platform_vk: process.argv[2], min_utxo_cost_lovelace: 857690n };
        let scheduleHex = Lucid.Data.to(
            jsonObject,
            PlatformFeeSchedule,
        );
        let scheduleCbor = Buffer.from(scheduleHex, 'hex');
        fs.writeFileSync("intermediate/platform-metadata.cbor", scheduleCbor);
        fs.writeFileSync("intermediate/platform-metadata.json", jsonify(jsonObject));
    } catch (err) {
        console.error(err);
    }
})