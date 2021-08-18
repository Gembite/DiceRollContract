const DiceRoll = artifacts.require('DiceRoll');
const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");
const GembitesProxy = artifacts.require("GembitesProxy");

module.exports = async function (deployer) {

    GBTS_instance = await GBTS.deployed();
    ULP_instance = await UnifiedLiquidityPool.deployed();
    Proxy_instance = await GembitesProxy.deployed();

    await deployer.deploy(
        DiceRoll,
        ULP_instance.address, // Deployed ULP Address
        GBTS_instance.address, // Deployed GBTS Address
        Proxy_instance.address, // Deployed GembitesProxy Address
        2, // Game Id
    );

    return;
};
