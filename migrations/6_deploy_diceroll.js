const DiceRoll = artifacts.require('DiceRoll');

module.exports = async function (deployer) {

    await deployer.deploy(
        DiceRoll,
        "0xbD658acCb3364b292E2f7620F941d4662Fd25749", // Deployed ULP Address
        "0xbe9512e2754cb938dd69bbb96c8a09cb28a02d6d", // Deployed GBTS Address
        RNG_instance.address, // // Deployed RNG Address
    );

    return;
};
