// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract TooBigToFail is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);
        ITroveManager tm = ITroveManager(TROVE_MANAGER);

        // Liquity's stored price is stale ($2,096). Pulling the fresh Chainlink price ($1,976)
        // drops the system-wide collateral ratio (TCR) below 150%, i.e. Recovery Mode.
        uint256 price = IPriceFeed(PRICE_FEED).fetchPrice();
        console.log("price        %18e", price);
        console.log("whale ICR    %18e", tm.getCurrentICR(WHALE, price));
        console.log("system TCR   %18e", tm.getTCR(price));
        console.log("recovery?    %s", tm.checkRecoveryMode(price));

        // In Recovery Mode any trove with ICR < TCR can be liquidated if the Stability Pool
        // can absorb its debt. The liquidator is paid 0.5% of the (capped) collateral.
        tm.liquidate(WHALE);
        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 2500 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
