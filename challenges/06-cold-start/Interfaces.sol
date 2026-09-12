// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IInbox {
    function setAllowListEnabled(bool) external;

    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee) external view returns (uint256);

    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
}

// Uniswap SwapRouter02, deployed on Robinhood Chain at 0xCaf681a66D020601342297493863E78C959E5cb2
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
