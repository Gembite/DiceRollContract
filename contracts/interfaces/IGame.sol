// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

/**
 * @title Game interface
 */
interface IGame {
    function play(bytes32 _requestId, uint256 _randomness) external;
}
