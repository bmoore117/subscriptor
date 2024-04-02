if (require.main != module) {
    console.log('This script only to be run from the command line');
    return;
}

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
        let scheduleCbor = Buffer.from(scheduleHex, 'hex');
        fs.writeFileSync("intermediate/platform-metadata.cbor", scheduleCbor);
    } catch (err) {
        console.error(err);
    }
})