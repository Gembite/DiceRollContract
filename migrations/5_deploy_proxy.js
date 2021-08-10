const GembitesProxy = artifacts.require("GembitesProxy");

module.exports = async function (deployer) {

    await deployer.deploy(
        GembitesProxy
    );

    return;
};
