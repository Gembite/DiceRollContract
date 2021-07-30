const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const RandomNumberConsumer = artifacts.require("RandomNumberConsumer");
const GBTS = artifacts.require("GBTS");

module.exports = async function (deployer) {

    GBTS_instance = await GBTS.deployed();
    RNG_instance = await RandomNumberConsumer.deployed();

    await deployer.deploy(
        UnifiedLiquidityPool,
        GBTS_instance.address, // Deployed GBTS Address
        RNG_instance.address, // Deployed RNG Address
    );

    return;
};
