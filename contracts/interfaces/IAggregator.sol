// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title Aggregator contract Interface
 */

interface IAggregator {
    /**
     * @dev External function for getting latest price of chainlink oracle.
     */
    function latestAnswer() external view returns (int256);

    /**
     * @dev External function for getting latest round data of chainlink oracle.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
