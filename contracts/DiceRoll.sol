// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGembitesProxy.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/**
 * @title DiceRoll Contract
 */
contract DiceRoll is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice Event emitted when gembites proxy set.
    event GembitesProxySet(address newProxyAddress);

    /// @notice Event emitted when contract is deployed.
    event DiceRollDeployed();

    /// @notice Event emitted when bet is started.
    event BetStarted(
        address player,
        uint256 multiplier,
        uint256 number,
        uint256 amount,
        bool rollOver
    );

    /// @notice Event emitted when bet is finished.
    event Betfinished(address player, uint256 paidAmount, bool betResult);

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IGembitesProxy public GembitesProxy;
    IRandomNumberGenerator public RNG;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    uint256 public gameId;

    struct BetInfo {
        address player;
        uint256 number;
        uint256 amount;
        uint256 multiplier;
        uint256 expectedWin;
        bool rollOver; // true: win when user's number is greater than chainlink random number, false: win when user's number is less than random number.
        bytes32 requestId;
    }

    mapping(bytes32 => BetInfo) public requestToBet;

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of RandomNumberGenerator
     * @param _gameId Game Id
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IRandomNumberGenerator _RNG,
        uint256 _gameId
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        RNG = _RNG;
        gameId = _gameId;

        emit DiceRollDeployed();
    }

    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "DiceRoll: Caller is not the RandomNumberGenerator"
        );
        _;
    }

    /**
     * @dev External function for start betting. This function can be called by anyone.
     * @param _number Tracks Player Selection for UI
     * @param _amount Amount of player betted.
     * @param _rollOver Roll status
     */
    function bet(
        uint256 _number,
        uint256 _amount,
        bool _rollOver
    ) external nonReentrant {
        uint256 winChance;
        uint256 expectedWin;
        uint256 multiplier;
        uint256 minBetAmount;
        uint256 maxWinAmount;

        minBetAmount = GembitesProxy.getMinBetAmount();
        maxWinAmount = GBTS.balanceOf(address(ULP)) / 100;

        require(
            _number > 0 && _number < 100,
            "DiceRoll: Bet amount is out of range"
        );

        if (_rollOver) {
            winChance = _number;
        } else {
            winChance = 100 - _number;
        }

        multiplier = (98 * 1000) / winChance;
        expectedWin = (multiplier * _amount) / 1000;

        require(
            _amount >= minBetAmount && expectedWin <= maxWinAmount,
            "DiceRoll: Expected paid amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        bytes32 requestId = RNG.requestRandomNumber();

        requestToBet[requestId] = BetInfo(
            msg.sender,
            _number,
            multiplier,
            _amount,
            expectedWin,
            _rollOver,
            requestId
        );

        betGBTS += _amount;

        emit BetStarted(msg.sender, multiplier, _number, _amount, _rollOver);
    }

    /**
     * @dev External function for playing. This function can be called by only RandomNumberGenerator.
     * @param _requestId Request Id
     * @param _randomness Random Number
     */
    function play(bytes32 _requestId, uint256 _randomness) external onlyRNG {
        BetInfo memory betInfo = requestToBet[_requestId];

        address player = betInfo.player;
        uint256 expectedWin = betInfo.expectedWin;

        uint256 gameNumber = (uint256(
            keccak256(abi.encode(_randomness, player, gameId))
        ) % 100) + 1;

        if (
            (betInfo.rollOver && betInfo.number >= gameNumber) ||
            (!betInfo.rollOver && betInfo.number <= gameNumber)
        ) {
            ULP.sendPrize(player, expectedWin);
            paidGBTS += expectedWin;
            emit Betfinished(player, expectedWin, true);
        } else {
            emit Betfinished(player, 0, false);
        }
    }

    /**
     * @dev External function to set gembites proxy. This function can be called by only owner.
     * @param _newProxyAddress New Gembites Proxy Address
     */
    function setGembitesProxy(address _newProxyAddress) external onlyOwner {
        require(
            _newProxyAddress.isContract() == true,
            "DiceRoll: Address is not contract address"
        );
        GembitesProxy = IGembitesProxy(_newProxyAddress);

        emit GembitesProxySet(_newProxyAddress);
    }
}
