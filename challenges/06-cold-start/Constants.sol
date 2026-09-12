// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

uint256 constant L1_FORK_BLOCK = 25347213;
uint256 constant L2_FORK_BLOCK = 120000;

address constant INBOX = 0x1A07cc4BD17E0118BdB54D70990D2158AbAD7a2D;

address constant CASHCAT = 0x020bfC650A365f8BB26819deAAbF3E21291018b4;
// L2 (Robinhood Chain) contracts, discovered from the CASHCAT pool's Swap events
address constant L2_SWAP_ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2; // Uniswap SwapRouter02
address constant L2_WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73; // CASHCAT.pairToken()
uint24 constant CASHCAT_POOL_FEE = 10000; // CASHCAT.poolFee(), 1% tier
