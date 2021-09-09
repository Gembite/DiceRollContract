const RandomNumberGenerator = artifacts.require("RandomNumberGenerator");
// const UnifiedLiquidityPool = artifacts.require("UnifiedLiquidityPool");
const { BN } = require("web3-utils");

module.exports = async function (deployer) {

  //  ULP_instance = await UnifiedLiquidityPool.deployed();

    await deployer.deploy(
        RandomNumberGenerator,
        '0x3d2341ADb2D31f1c5530cDC622016af293177AE0', // Chainlink VRF Coordinator address
        '0xb0897686c545045aFc77CF20eC7A532E3120E0F1', // LINK token address
        '0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da', // Key Hash
        new BN('100000000000000'), // Fee
        "0xbD658acCb3364b292E2f7620F941d4662Fd25749"
    );

    return;
};
