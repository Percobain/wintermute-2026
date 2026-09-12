# 07 · Firepit (Tier 3, 150 pts)

> Burn 2,000 UNI on X Layer and walk away with at least **45,000 USD₮0**.
>
> **Result:** solved, `[PASS]`, ending balance **55,176 USD₮0**.
> Code: [`challenges/07-firepit/Solution.t.sol`](../challenges/07-firepit/Solution.t.sol)

---

## 1. The story in plain English

Imagine a big chain of vending machines (Uniswap). Every time someone buys a snack, a
small fee goes to the people who stocked the machine. In late 2025 the owners voted to take a
cut of that fee for themselves, a "protocol fee". That cut piles up in a **tip jar** on each
chain.

Nobody on staff empties the tip jar. The rule is instead:

> *Anyone* can empty the whole jar into their own pocket, **as long as they throw 2,000 UNI
> tokens into a fire** (burning them forever) while they do it.

UNI holders like this because every burn removes UNI from circulation, making the rest scarcer.
The person emptying the jar likes it when the jar is worth more than the UNI they burn.

The twist on X Layer (OKX's blockchain): **the jar looks empty.** The tips were never
carried from the vending machines to the jar. Anyone may carry them over, but nobody had.
So the real opportunity is:

1. Carry every machine's tips into the jar (free, anyone can do it).
2. Burn 2,000 UNI and take the whole jar.
3. Swap the mix of coins you got (OKB, ETH, SOL, BTC, other dollar tokens) into USD₮0.

## 2. Key concepts, simply

| Concept | What it means here |
|---|---|
| **Uniswap** | A decentralised exchange. Instead of an order book, each trading pair is a *pool* holding two tokens; a formula sets the price. |
| **LP fees** | Traders pay a fee (0.01%–1%) on each swap. It goes to *liquidity providers* (LPs), the people who deposited tokens into the pool. |
| **Protocol fee** | A slice of the LP fee (here 1/4 or 1/6) that the protocol keeps. In Uniswap V3 it sits inside each pool in a counter called `protocolFees` until someone calls `collectProtocol`. |
| **TokenJar** | One contract per chain where protocol fees are meant to end up. Only one address, the *releaser*, can take anything out. |
| **Releaser / Firepit** | The releaser contract. Call `release()`, pay exactly `threshold` UNI, and it hands you **everything** in the jar for the tokens you list. On L2s like X Layer the UNI is sent back to Ethereum and burned there. |
| **Burning** | Sending tokens somewhere nobody can ever spend them. Total supply goes down. |
| **Nonce** | A counter the releaser checks, so two searchers can't both claim the same jar. You must pass the current value (it was `0` here, so nobody had ever burned on X Layer). |
| **Searchers / MEV** | Bots and people who hunt for moments when doing something onchain pays more than it costs. This challenge is a textbook searcher trade. |
| **Slippage** | Selling a lot of a token into a small pool pushes its price down, so you get less. Splitting a sale into chunks and across routes helps. |

**Why burning UNI can pay:** the price (2,000 UNI) is fixed, but the jar keeps growing. Once the
jar is worth more than 2,000 UNI plus gas, the first person to burn makes a profit. It works
like a Dutch auction that nobody is watching.

## 3. How the opportunity was found

### 3.1 Find the contracts

The fee system is open source at
[github.com/Uniswap/protocol-fees](https://github.com/Uniswap/protocol-fees). Its README lists
the X Layer (chain 196) deployments:

| Contract | Address |
|---|---|
| TokenJar | `0x8Dd8B6D56e4a4A158EDbBfE7f2f703B8FFC1a754` |
| Releaser (`OptimismBridgedResourceFirepit`) | `0xe122E231cb52aea99690963Fd73E91e33E97468f` |
| `V3OpenFeeAdapter` (owns the V3 factory) | `0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7` |

The releaser code (`ExchangeReleaser.release`) is short:

```solidity
function release(uint256 _nonce, Currency[] calldata assets, address recipient) external handleNonce(_nonce) {
    RESOURCE.safeTransferFrom(msg.sender, RESOURCE_RECIPIENT, threshold); // take the UNI
    TOKEN_JAR.release(assets, recipient);                                   // give away the jar
    _afterRelease(assets, recipient);                                       // bridge UNI to L1 to burn
}
```

`_afterRelease` calls the L2 bridge at `0x4200…0010`. The challenge's `setUp()` replaces that
bridge with code that does nothing, so the bridging step can't get in the way on the fork.

### 3.2 Read the state at block 68413600

```
releaser.threshold()   = 2000e18   (exactly our 2,000 UNI)
releaser.nonce()       = 0
jar USD₮0 balance      = 0          <- the jar looks empty
adapter.defaultFee()   = 68 (0x44)  -> protocol takes 1/4 of LP fees
```

An empty jar isn't worth burning for, so the question became: where are the fees?

### 3.3 The fees are still in the pools

`V3OpenFeeAdapter.collect()` is **permissionless**: anyone can call it, and it always sends the
fees to the TokenJar. The next step was listing the pools with protocol fees switched on.

X Layer's public RPC only allows 100-block log queries, so scanning every `PoolCreated` event
wasn't practical. A shortcut worked instead:

1. Binary-search the block where a known pool (OKB/USD₮0) first had a non-zero `feeProtocol`:
   **block 54136259**.
2. That block contains one `batchTriggerFeeUpdateByPool(address[])` call to the adapter. Its
   calldata lists the **28 pools** that got protocol fees switched on.
3. Calling `getPool` on the factory for every pair of the main tokens found a few more pools
   switched on later.

Reading `protocolFees()` on each pool gave the uncollected fees (the big ones):

| Pool | Uncollected protocol fees |
|---|---|
| USD₮0 / WOKB 0.3% | 7,224 USD₮0 + 86.4 OKB |
| USD₮0 / xETH 0.05% | 4,480 USD₮0 + 2.30 xETH |
| USD₮0 / WOKB 0.05% | 3,961 USD₮0 + 42.7 OKB |
| xSOL / USD₮0 0.05% | 47.5 xSOL + 3,722 USD₮0 |
| USD₮0 / xBTC 0.05% | 3,023 USD₮0 + 0.044 xBTC |
| USDG / USD₮0 0.01% | 2,713 USDG + 2,701 USD₮0 |
| USD₮0 / WOKB 0.01% | 505 USD₮0 + 5.2 OKB |
| …plus ~25 small ones | dust |

That's about **25.6k USD₮0 in cash** plus roughly **$29k** in OKB (~$103), xETH (~$2,170),
xSOL (~$79), xBTC (~$69k) and USDG. Cash alone is below 45k, so the other tokens have to be
sold too.

### 3.4 Is 2,000 UNI enough?

Yes. The threshold is exactly 2,000 UNI, so no extra UNI has to be bought. Every other token
we receive can be swapped into USD₮0.

## 4. The solution

Three steps inside `test_Solution()`:

```solidity
// 1. Sweep protocol fees from every pool into the TokenJar (anyone may call this)
IV3OpenFeeAdapter(V3_FEE_ADAPTER).collect(params);          // 34 pools, amount = max

// 2. Burn 2,000 UNI and have the jar paid out to a helper "Seller" contract
Seller seller = new Seller();
IERC20(UNI).approve(FIREPIT, IFirepit(FIREPIT).threshold());
IFirepit(FIREPIT).release(IFirepit(FIREPIT).nonce(),
    [USDT0, WOKB, xETH, xSOL, xBTC, USDG, USDC, USDT, WETH], address(seller));

// 3. Sell everything into USD₮0, then send it to the user
seller.sell(XETH, routes, 20);  seller.sell(XSOL, routes, 20);
seller.sell(XBTC, routes, 20);  seller.sell(WOKB, routes, 20);
seller.sell(USDG, routes, 1);   seller.sweep(USDT, user);
```

**Why a helper contract?** A Uniswap V3 pool pays you first and then calls
`uniswapV3SwapCallback` on the caller to collect payment. A plain wallet has no code to answer
that call, so a small `Seller` contract does the swapping.

**How `Seller.sell` limits slippage:** the xETH, xSOL and xBTC pools are thin, so dumping all
at once would crash the price. `sell` splits each balance into 20 chunks. For every chunk it
*quotes* each route (for example xETH→USD₮0 directly, xETH→USDG→USD₮0, or xETH→xSOL→USD₮0) and
uses the best one. The quote really performs the swaps inside a call that then reverts, so
nothing changes onchain but the output amount is known. This is the trick Uniswap's own Quoter
uses.

Test output:

```
USDT0 in jar after collect: 25616.84245
OKB in jar after collect:   134.43
xETH in jar after collect:  2.47
xSOL in jar after collect:  49.60
xBTC in jar after collect:  0.0464
USDG in jar after collect:  2800.62
USDT0 released from jar:  25616.84
  after selling xETH:     31158.13
  after selling xSOL:     35378.45
  after selling xBTC:     38554.92
  after selling OKB:      52373.67
Firepit solved. USDT: 55176.114839
[PASS] test_Solution()
```

Run it:

```
forge test --match-path challenges/07-firepit/Solution.t.sol --match-test test_Solution -vv
# or
python alpha.py check 07
```

## 5. Takeaways

- **"Empty" doesn't mean worthless.** In pull-based fee systems the money often sits upstream
  (inside pools), waiting for anyone to call a free `collect`. Check where value *can* be
  pulled from, not just current balances.
- **Fixed prices on growing pots create races.** A fixed 2,000 UNI burn on a jar that grows
  every block is a Dutch auction. The protocol's own comments warn about this.
- **Cheap tricks beat brute force for research.** When logs were rate-limited, binary-searching
  one storage value found the one transaction that listed every pool.
- **Getting paid in many tokens is a liquidation problem.** Half the value came from selling
  OKB, ETH, SOL and BTC through thin pools. Chunking and route quoting was worth thousands of
  dollars compared with one big market sell.
