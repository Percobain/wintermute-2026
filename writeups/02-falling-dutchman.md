# 02 · Falling Dutchman (Tier 2, 100 pts)

> Can you execute a trade on the DutchX exchange at block 9462777 (Feb 2020) and turn your
> 0.1 ETH into at least 4 ETH?

**Result:** `forge test` **PASS**. The user ends with **8.654 ETH** (started with 0.1).

---

## 1. The story in plain English

A **Dutch auction** runs a normal auction backwards. The seller starts with a very high price
and lowers it every minute until someone says "I'll take it." Flower markets in the
Netherlands work this way, hence the name.

DutchX was an exchange built entirely out of these auctions. Every token pair (for example
KNC/WETH) had an auction that started at **2× the last price** and slid down. After 6 hours
it reached the last price, and **after 24 hours it reached zero**. The designers assumed
someone would always buy long before the price got silly.

By 2020 almost nobody used DutchX anymore. At our block, the KNC/WETH auctions had been
running for **23 hours 11 minutes** with **zero bids**, so their prices had fallen to about
**2% of fair value**:

- 2,820 KNC were for sale for about 0.1 WETH in total. On Uniswap those KNC were worth about 4.5 ETH.
- In the opposite direction, 4.48 WETH were for sale for about 65 KNC, which is roughly 0.1 ETH worth of KNC.

It's a shop with a 98%-off sticker that nobody noticed. We buy both piles and sell what we
don't need on Uniswap.

## 2. Concepts you need

| Term | Plain meaning |
|---|---|
| **ETH / WETH** | ETH is Ethereum's native coin. WETH is the same coin wrapped as a standard token (1:1), because most exchanges only handle tokens. |
| **KNC** | Kyber Network's token. It's just "some token with a market price" here. |
| **Dutch auction** | The price starts high and falls over time. The first buyers get the current price. |
| **Sell volume / buy volume** | How much the sellers put in, and how much buyers have bid so far. The auction *clears* (ends) once buy volume × price covers all sell volume. |
| **Uniswap v1** | An automated exchange pool holding ETH plus one token. It gives a market price at any moment. |
| **Mainnet fork** | Foundry copies Ethereum's state at an old block into a local sandbox, so we can replay history with our own transactions. |

## 3. How it was solved

### Step 1: Read the contract
The DutchX address is a proxy. Storage slot 0 points to the real code at
`0x2bae491b065032a76be1db9e9ecf5738afae203e`, which is verified on Etherscan and Blockscout.
The key function is `getCurrentAuctionPrice`:

```solidity
// P(0 hrs) = 2 * lastClosingPrice, P(6 hrs) = lastClosingPrice, P(>=24 hrs) = 0
num = (24 hours - timeElapsed) * pastNum;
den = (timeElapsed + 12 hours) * pastDen;
```

So the price is `lastPrice × (24h − t) / (t + 12h)`.

The buyer functions are also important:
- `deposit(token, amount)`: you move tokens into your DutchX balance first.
- `postBuyOrder(sellToken, buyToken, auctionIndex, amount)`: bids your `buyToken` balance.
- `claimBuyerFunds(...)`: credits what you bought. It even works **while the auction is still running**, at the current price.
- `withdraw(token, amount)`: moves tokens back to your wallet.

### Step 2: Scan every auction at the fork block
We pulled all 33 `NewTokenPair` events from the exchange and read the state of each pair at
block 9,462,777 (a script in the scratchpad calling `getAuctionIndex`, `getAuctionStart`,
`sellVolumesCurrent`, `buyVolumes` and `getCurrentAuctionPrice`). Most auctions were idle
("waiting for funding"). One stood out:

| Pair (index 1051) | Started | Elapsed | For sale | Bids | Auction price |
|---|---|---|---|---|---|
| sell **KNC** for WETH | 10 Feb 2020 17:14 UTC | 23.19 h | 2,820.7 KNC | 0 | 0.0000367 WETH/KNC |
| sell **WETH** for KNC | same clock | 23.19 h | 4.482 WETH | 0 | 14.53 KNC/WETH |

The decay factor is `(24 − 23.19) / (23.19 + 12) ≈ 0.023`, so the price was 2.3% of the last
clearing price.

A couple of other auctions had already decayed all the way to zero. Those are useless:
at a price of 0, the "outstanding volume" is 0, so a bid just clears the auction and
the buyer receives nothing. 23 hours was the sweet spot, cheap but not zero.

### Step 3: Compare with the real market
Uniswap v1's KNC pool (`0x49c4…1a8b`) held 1,024 ETH and 645,877 KNC, which works out to
**~630 KNC per ETH** (0.00159 ETH per KNC). The DutchX auction offered KNC about **43×
cheaper**. The WETH-for-KNC auction offered WETH at 14.5 KNC instead of 630, also 43× cheaper.

### Step 4: The trade
1. Wrap 0.1 ETH into WETH and deposit it into DutchX.
2. Bid all 0.1 WETH into the **KNC→WETH** auction. That's slightly less than the 0.1035 WETH needed to clear it, so the auction keeps running. `claimBuyerFunds` immediately credits us about **2,710 KNC** at the current price.
3. Bid those KNC into the **WETH→KNC** auction. The contract caps our bid at the outstanding ~65 KNC, which clears that auction and gives us all **4.48 WETH**.
4. Withdraw the WETH and the remaining ~2,650 KNC, then unwrap the WETH to ETH.
5. Sell the KNC on Uniswap v1 for about 4.17 ETH.

A 0.5% DutchX fee applies to each bid. It hardly matters.

## 4. The solution code

`challenges/02-falling-dutchman/Solution.t.sol` (interfaces in `Interfaces.sol`, addresses in `Constants.sol`):

```solidity
IDutchExchange dx = IDutchExchange(DUTCHX);
uint256 idx = dx.getAuctionIndex(KNC, WETH_ADDR); // 1051, both directions share it

// 1. wrap + deposit
IWETH(WETH_ADDR).deposit{value: 0.1 ether}();
IWETH(WETH_ADDR).approve(DUTCHX, type(uint256).max);
dx.deposit(WETH_ADDR, 0.1 ether);

// 2. buy ~2,700 KNC for 0.1 WETH from the stale KNC auction
dx.postBuyOrder(KNC, WETH_ADDR, idx, 0.1 ether);
dx.claimBuyerFunds(KNC, WETH_ADDR, user, idx);

// 3. spend ~65 KNC to buy all 4.48 WETH from the opposite stale auction
dx.postBuyOrder(WETH_ADDR, KNC, idx, dx.balances(KNC, user));
dx.claimBuyerFunds(WETH_ADDR, KNC, user, idx);

// 4. take everything out, unwrap WETH
dx.withdraw(WETH_ADDR, type(uint256).max);
uint256 kncLeft = dx.balances(KNC, user);
dx.withdraw(KNC, kncLeft);
IWETH(WETH_ADDR).withdraw(IERC20(WETH_ADDR).balanceOf(user));

// 5. dump leftover KNC on Uniswap v1
IERC20(KNC).approve(UNIV1_KNC, kncLeft);
IUniswapV1Exchange(UNIV1_KNC).tokenToEthSwapInput(kncLeft, 1, block.timestamp);
```

Output:
```
[PASS] test_Solution()
  Solved. Ending balance in ETH: 8.654236578240266585
```

## 5. Takeaways

- **Price schedules that run on a clock need buyers watching the clock.** A Dutch auction with no participants turns into free money.
- **Deprecated protocols still hold funds.** Old contracts never switch off, and stale state can sit there for years.
- **Scan everything, then compare with a live market.** The win came from a boring loop over 33 pairs, not from clever math.
- **Read the edge cases.** Price = 0 looks best but pays nothing. Price ≈ 2% was the real opportunity.
