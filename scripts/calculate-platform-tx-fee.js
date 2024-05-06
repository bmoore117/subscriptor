const subscriptionData = require('./intermediate/subscription-metadata.json');
const platformData = require('./intermediate/platform-metadata.json');

let amount = platformData.fee_percentage_basis_points * subscriptionData.fields[1].int / 1000
console.log(amount);