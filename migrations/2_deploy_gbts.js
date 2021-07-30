const GBTS = artifacts.require("GBTS");

module.exports = async function (deployer) {
    await deployer.deploy(
        GBTS,
    );

    return;
};
