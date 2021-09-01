// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGembitesProxy.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/**
 * @title DiceRoll Contract
 */
contract DiceRoll is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using Counters for Counters.Counter;

    /// @notice Event emitted when gembites proxy set.
    event GembitesProxySet(address newProxyAddress);

    /// @notice Event emitted when contract is deployed.
    event DiceRollDeployed();

    event BetPlaced(
        address player,
        uint256 betId,
        uint256 number,
        uint256 amount,
        uint256 roll
    );
    event BetSettled(address player, uint256 betId, uint256 betResult); // betResult 1 for win, 0 for loss

    Counters.Counter private betIds;

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IGembitesProxy public GembitesProxy;
    IRandomNumberGenerator public RNG;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    struct BetInfo {
        address player;
        uint256 betId;
        uint256 number;
        uint256 amount;
        uint256 multiplier;
        uint256 expectedWin;
        uint256 roll; // 1 for over, 0 for under
        bytes32 requestId;
    }

    mapping(bytes32 => BetInfo) public requestToBet;
    mapping(uint256 => BetInfo) public betIdToBet;
    mapping(uint256 => uint256) public betIdToRoll;

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of RandomNumberGenerator
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IRandomNumberGenerator _RNG
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        RNG = _RNG;

        emit DiceRollDeployed();
    }

    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "DiceRoll: Caller is not the RandomNumberGenerator."
        );
        _;
    }

    /**
     * @dev External function for start betting. This function can be called by anyone.
     * @param _number Tracks Player Selection for UI
     * @param _amount Amount of player betted.
     * @param _roll roll
     */
    function bet(
        uint256 _number,
        uint256 _amount,
        uint256 _roll
    ) external nonReentrant returns (uint256 betId) {
        uint256 winChance;
        uint256 expectedWin;
        uint256 multiplier;
        uint256 minBet;
        uint256 maxWin;
        uint256 currentBetId;

        minBet = GembitesProxy.getMinBetAmount();
        maxWin = GBTS.balanceOf(address(ULP)) / 100;

        require(_roll == 0 || _roll == 1, "DiceRoll: Invalid roll");
        require(_number > 0 && _number < 50, "DiceRoll: Invalid number");

        if (_roll == 0) {
            winChance = _number;
        } else {
            winChance = 100 - _number;
        }

        multiplier = (98 * 1000) / winChance;
        expectedWin = (multiplier * _amount) / 1000;

        require(
            _amount >= minBet && expectedWin <= maxWin,
            "DiceRoll: Amount invalid"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        bytes32 requestId = RNG.requestRandomNumber();

        betIds.increment();
        currentBetId = betIds.current();

        requestToBet[requestId] = BetInfo(
            msg.sender,
            currentBetId,
            _number,
            multiplier,
            _amount,
            expectedWin,
            _roll,
            requestId
        );
        betIdToBet[currentBetId] = BetInfo(
            msg.sender,
            currentBetId,
            _number,
            _amount,
            multiplier,
            expectedWin,
            _roll,
            requestId
        );

        emit BetPlaced(msg.sender, currentBetId, _number, _amount, _roll);

        betGBTS += _amount;

        return currentBetId;
    }

    /**
     * @dev External function for playing. This function can be called by only RandomNumberGenerator.
     * @param _requestId Request Id
     * @param _randomness Random Number
     */
    function play(bytes32 _requestId, uint256 _randomness) external onlyRNG {
        BetInfo memory betInfo = requestToBet[_requestId];

        address player = betInfo.player;
        uint256 rng = _randomness;
        uint256 betId = betInfo.betId;
        uint256 number = betInfo.number;
        uint256 expectedWin = betInfo.expectedWin;
        uint256 roll = betInfo.roll;

        uint256 result = (rng % 100) + 1;

        betIdToRoll[betId] = result;

        if (roll == 0) {
            if (number >= result) {
                ULP.sendPrize(player, expectedWin);
                emit BetSettled(player, betId, 1);
                paidGBTS += expectedWin;
            } else {
                emit BetSettled(player, betId, 0);
            }
        } else if (roll == 1) {
            if (number <= result) {
                ULP.sendPrize(player, expectedWin);
                emit BetSettled(player, betId, 1);
                paidGBTS += expectedWin;
            } else {
                emit BetSettled(player, betId, 0);
            }
        }
    }

    /**
     * @dev External function to set gembites proxy. This function can be called by only owner.
     * @param _newProxyAddress New Gembites Proxy Address
     */
    function setGembitesProxy(address _newProxyAddress) external onlyOwner {
        require(
            _newProxyAddress.isContract() == true,
            "CoinFlip: Address is not contract address"
        );
        GembitesProxy = IGembitesProxy(_newProxyAddress);

        emit GembitesProxySet(_newProxyAddress);
    }
}
