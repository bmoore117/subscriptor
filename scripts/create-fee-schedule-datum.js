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
    const PlatformFeeSchedule = Lucid.Data.Object({
        fee_percentage_basis_points: Lucid.Data.Integer(),
        platform_vk: Lucid.Data.Bytes()
    });

    try {
        let scheduleHex = Lucid.Data.to(
            { fee_percentage_basis_points: 25n, platform_vk: process.argv[2]  },
            PlatformFeeSchedule,
        );

        let scheduleObj = Lucid.Data.from(scheduleHex);
        fs.writeFileSync("intermediate/platform-metadata.json", jsonify(scheduleObj));
    } catch (err) {
        console.error(err);
    }
})