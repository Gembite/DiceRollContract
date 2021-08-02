// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IAggregator.sol";

/**
 * @title DiceRoll Contract
 */
contract DiceRoll is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IAggregator public LinkUSDT;
    IAggregator public GBTSUSDT;

    uint256 constant RTP = 98;
    uint256 constant gameId = 1;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    uint256 public vrfCost = 10000; // 0.0001 Link

    struct BetInfo {
        uint256 number;
        uint256 amount;
        uint256 multiplier;
        bytes32 requestId;
    }

    mapping(address => BetInfo) private betInfos;

    /// @notice Event emitted only on construction.
    event DiceRollDeployed();

    /// @notice Event emitted when player start the betting.
    event BetStarted(
        address indexed player,
        uint256 number,
        uint256 amount,
        bytes32 batchID
    );

    /// @notice Event emitted when player finish the betting.
    event BetFinished(address indexed player, bool won);

    /// @notice Event emitted when game number generated.
    event VerifiedGameNumber(uint256 vrf, uint256 gameNumber, uint256 gameId);

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _GBTSUSDT Interface of GBTS Token USDT Aggregator
     * @param _LinkUSDT Interface of Link Token USDT Aggregator "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665" Address of LINK/USD Price Contract
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IAggregator _GBTSUSDT,
        IAggregator _LinkUSDT
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        GBTSUSDT = _GBTSUSDT;
        LinkUSDT = _LinkUSDT;

        emit DiceRollDeployed();
    }

    /**
     * @dev External function to start betting. This function can be called by players.
     * @param _number Number of player set
     * @param _amount Amount of player betted.
     */
    function bet(uint256 _number, uint256 _amount) external {
        require(betInfos[msg.sender].number == 0, "DiceRoll: Already betted");
        require(1 <= _number && _number <= 50, "DiceRoll: Number out of range");
        require(
            GBTS.balanceOf(msg.sender) >= _amount,
            "DiceRoll: Caller has not enough balance"
        );

        uint256 multiplier = (RTP * 1000) / _number;
        uint256 winnings = (_amount * multiplier) / 1000;

        require(
            checkBetAmount(winnings, _amount),
            "DiceRoll: Bet amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        betInfos[msg.sender].number = _number;
        betInfos[msg.sender].amount = _amount;
        betInfos[msg.sender].multiplier = multiplier;
        betInfos[msg.sender].requestId = ULP.requestRandomNumber();
        betGBTS += _amount;

        emit BetStarted(
            msg.sender,
            _number,
            _amount,
            betInfos[msg.sender].requestId
        );
    }

    /**
     * @dev External function to calculate betting win or lose.
     */
    function play() external nonReentrant {
        require(
            betInfos[msg.sender].number != 0,
            "DiceRoll: Cannot play without betting"
        );

        uint256 newRandomNumber = ULP.getVerifiedRandomNumber(
            betInfos[msg.sender].requestId
        );

        uint256 gameNumber = uint256(
            keccak256(abi.encode(newRandomNumber, address(msg.sender), gameId))
        ) % 100;

        emit VerifiedGameNumber(newRandomNumber, gameNumber, gameId);

        BetInfo storage betInfo = betInfos[msg.sender];

        if (gameNumber < betInfo.number) {
            ULP.sendPrize(
                msg.sender,
                (betInfo.amount * betInfo.multiplier) / 1000
            );

            paidGBTS += (betInfo.amount * betInfo.multiplier) / 1000;
            betInfos[msg.sender].number = 0;

            emit BetFinished(msg.sender, true);
        } else {
            betInfos[msg.sender].number = 0;

            emit BetFinished(msg.sender, false);
        }
    }

    /**
     * @dev Public function to return min bet amount with current Link and GBTS token price.
     */
    function minBetAmount() public view returns (uint256) {
        int256 GBTSPrice;
        int256 LinkPrice;

        (, GBTSPrice, , , ) = GBTSUSDT.latestRoundData();
        (, LinkPrice, , , ) = LinkUSDT.latestRoundData();

        return (uint256(LinkPrice) * 53) / (uint256(GBTSPrice) * vrfCost);
    }

    /**
     * @dev Internal function to check current bet amount is enough to bet.
     * @param _winnings Amount of GBTS if user wins.
     * @param _betAmount Bet Amount
     */
    function checkBetAmount(uint256 _winnings, uint256 _betAmount)
        internal
        view
        returns (bool)
    {
        return (GBTS.balanceOf(address(ULP)) / 100 >= _winnings &&
            _betAmount >= minBetAmount());
    }
}
