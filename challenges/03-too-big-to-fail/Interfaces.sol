// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITroveManager {
    function liquidate(address borrower) external;
    function getCurrentICR(address borrower, uint256 price) external view returns (uint256);
    function getTCR(uint256 price) external view returns (uint256);
    function checkRecoveryMode(uint256 price) external view returns (bool);
}

interface IPriceFeed {
    function fetchPrice() external returns (uint256);
}
