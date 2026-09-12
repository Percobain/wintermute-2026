// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDutchExchange {
    function deposit(address tokenAddress, uint256 amount) external returns (uint256);
    function withdraw(address tokenAddress, uint256 amount) external returns (uint256);
    function postBuyOrder(address sellToken, address buyToken, uint256 auctionIndex, uint256 amount)
        external
        returns (uint256);
    function claimBuyerFunds(address sellToken, address buyToken, address user, uint256 auctionIndex)
        external
        returns (uint256 returned, uint256 frtsIssued);
    function getAuctionIndex(address token1, address token2) external view returns (uint256);
    function balances(address token, address user) external view returns (uint256);
}

interface IUniswapV1Exchange {
    function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) external returns (uint256);
}
