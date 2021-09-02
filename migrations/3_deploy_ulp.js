const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");

module.exports = async function (deployer) {

    GBTS_instance = await GBTS.deployed();

    await deployer.deploy(
        UnifiedLiquidityPool,
        GBTS_instance.address, // Deployed GBTS Address
        "0x7813391Ca670be5F1324CD5BE3ff6bfAE2B42E01", // Deployed RNG Address
    );

    return;
};
