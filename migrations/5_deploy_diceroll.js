const DiceRoll = artifacts.require('DiceRoll');
const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const GBTS = artifacts.require("GBTS");

module.exports = async function (deployer) {

    GBTS_instance = await GBTS.deployed();
    ULP_instance = await UnifiedLiquidityPool.deployed();

    await deployer.deploy(
        DiceRoll,
        ULP_instance.address, // Deployed ULP Address
        GBTS_instance.address, // Deployed GBTS Address
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665",
        "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665"
    );

    return;
};
