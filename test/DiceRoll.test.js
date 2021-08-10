const GBTS = artifacts.require("GBTS");
const ULP = artifacts.require("UnifiedLiquidityPool");
const DiceRoll = artifacts.require("DiceRoll");
const RNG = artifacts.require("RandomNumberConsumer");
const GembitesProxy = artifacts.require("GembitesProxy");

const { assert } = require("chai");
const { BN } = require("web3-utils");
const timeMachine = require('ganache-time-traveler');

contract("DiceRoll", (accounts) => {
    let gbts_contract, ulp_contract, diceRoll_contract, rng_contract, proxy_contract;

    before(async () => {
        await GBTS.new(
            { from: accounts[0] }
        ).then((instance) => {
            gbts_contract = instance;
        });

        await RNG.new(
            "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9",   // Chainlink VRF Coordinator address
            "0xa36085F69e2889c224210F603D836748e7dC0088",   // LINK token address
            "0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4",   // Key Hash
            1, // fee
            { from: accounts[0] }
        ).then((instance) => {
            rng_contract = instance;
        });

        await ULP.new(
            gbts_contract.address,
            rng_contract.address,
            { from: accounts[0] }
        ).then((instance) => {
            ulp_contract = instance;
        });

        await GembitesProxy.new(
            { from: accounts[0] }
        ).then((instance) => {
            proxy_contract = instance;
        });

        await DiceRoll.new(
            ulp_contract.address,
            gbts_contract.address,
            proxy_contract.address,
            { from: accounts[0] }
        ).then((instance) => {
            diceRoll_contract = instance;
        });

        await gbts_contract.transfer(accounts[1], new BN('1000000000000000000000000'), { from: accounts[0] }); // Win Account 1000000 GBTS
        await gbts_contract.transfer(accounts[2], new BN('1000000000000000000000000'), { from: accounts[0] }); // Lose Account 1000000 GBTS
        await gbts_contract.transfer(ulp_contract.address, new BN('100000000000000000000000'), { from: accounts[0] }); //  100000 GBTS

        await gbts_contract.approve(ulp_contract.address, new BN('10000000000000000000000'), { from: accounts[0] }); // 1000GBTS

        await ulp_contract.startStaking(
            new BN('1000000000000000000000'), //1000 GBTS
            { from: accounts[0] }
        );

        await ulp_contract.unlockGameForApproval(
            diceRoll_contract.address,
            { from: accounts[0] }
        );

        await timeMachine.advanceTimeAndBlock(86400);

        await ulp_contract.changeGameApproval(
            diceRoll_contract.address,
            true,
            { from: accounts[0] }
        );
        await rng_contract.setULPAddress(ulp_contract.address);
    });

    describe("Bet", () => {
        it("Betting is not working with insuffcient balance", async () => {
            let thrownError;
            try {
                await diceRoll_contract.bet(
                    40,
                    new BN('10000000000000000000000000'), 
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Caller has not enough balance',
            )
        });

        it("Betting is not working with bet amount less than 25", async () => {
            let thrownError;
            try {
                await diceRoll_contract.bet(
                    40,
                    new BN('24000000000000000000'), // 24 GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Bet amount is out of range',
            )
        });

        it("Betting is not working with bet amount more than 1% of ULP", async () => {
            let thrownError;
            try {
                await diceRoll_contract.bet(
                    40,
                    new BN('10000000000000000000000'), // 10000 GBTS
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Bet amount is out of range',
            )
        });

        it("First player betting is working", async () => {
            await gbts_contract.approve(diceRoll_contract.address, new BN('1000000000000000000000'), { from: accounts[1] });
            await diceRoll_contract.bet(40, new BN('100000000000000000000'), { from: accounts[1] }); // Bet Number: 40, Bet Amount: 100 GBTS
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('101100000000000000000000').toString());
        });

        it("Player already betted", async () => {
            let thrownError;
            try {
                await diceRoll_contract.bet(
                    40,
                    new BN('100000000000000000000'),
                    { from: accounts[1] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Already betted',
            )
        });

        it("Betting is not working with number out of range", async () => {
            let thrownError;
            try {
                await diceRoll_contract.bet(
                    51,
                    new BN('100000000000000000000'),
                    { from: accounts[2] }
                );
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Number out of range',
            )
        });

        it("Second player betting is working", async () => {
            await gbts_contract.approve(diceRoll_contract.address, new BN('100000000000000000000'), { from: accounts[2] });
            await diceRoll_contract.bet(20, new BN('100000000000000000000'), { from: accounts[2] }); // Bet Number: 20, Bet Amount: 100 GBTS
            assert.equal(new BN(await gbts_contract.balanceOf(ulp_contract.address)).toString(), new BN('101200000000000000000000').toString());
        });
    });

    describe("Play", () => {

        it("Play is not working without betting", async () => {
            let thrownError;

            try {
                await diceRoll_contract.play({ from: accounts[3] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'DiceRoll: Cannot play without betting',
            )
        });

        it("First player wins", async () => {
            await diceRoll_contract.play({ from: accounts[1] });
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[1])).toString(), new BN('1000145000000000000000000').toString());
        });

        it("Second player loses", async () => {
            await diceRoll_contract.play({ from: accounts[2] });
            assert.equal(new BN(await gbts_contract.balanceOf(accounts[2])).toString(), new BN('999900000000000000000000').toString());
        });

    });

    describe("GembitesProxy", () => {

        it("Can't change the min bet amount within an hour", async () => {
            await proxy_contract.setMinBetAmount(new BN('24000000000000000000'));
            let thrownError;

            try {
                await proxy_contract.setMinBetAmount(new BN('24000000000000000000'));
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'GembitesProxy: Not time to change',
            )
        });

        it("Changing the min bet amount is working", async () => {
            await timeMachine.advanceTimeAndBlock(3600);
            await proxy_contract.setMinBetAmount(new BN('24000000000000000000'));
            await timeMachine.advanceTimeAndBlock(3600);
            await proxy_contract.setMinBetAmount(new BN('24000000000000000000'));
        });
    });

});
