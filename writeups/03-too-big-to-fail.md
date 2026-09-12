# 03 · Too Big To Fail (Tier 2, 100 pts)

> On 19 May 2021 the market fell ~30% in an afternoon. On Liquity, one user held a ~$1B position
> that was never liquidated. Can you process this liquidation at block 12465029 and end with
> more than 2,500 ETH?

**Result:** `forge test` **PASS**. The user ends with **2,504.48 ETH** (started with 0.1).

---

## 1. The story in plain English

**Liquity** is a pawn shop that lives on a blockchain. You hand over ETH as collateral and
borrow LUSD, a dollar-pegged token. As long as your collateral is worth enough more than your
loan, nobody touches it.

If ETH's price falls and your cushion gets too thin, **anyone** can call `liquidate` on your
loan. Your debt is paid off from a shared savings pot (the **Stability Pool**). The savers get
your ETH, and the person who pressed the button gets a **tip: 0.5% of the collateral**.

The usual rule is that a loan is liquidatable below **110%** collateral. There's a second,
less famous rule. If the **whole system** is under-collateralized (below 150% in total), Liquity
enters **Recovery Mode**. In Recovery Mode, any loan below the system average can be
liquidated, even one sitting at a healthy-looking 133%.

On 19 May 2021 one borrower had **606,280 ETH** locked against **900M LUSD** of debt. That
single loan held about 64% of all the ETH in Liquity. When ETH crashed, the loan was around 133%,
safe under the normal rule. But once the price feed was refreshed, the system as a whole was below 150%. We can't know
for sure why nobody acted. A likely explanation is that bots watched the 110% line and
Liquity's stored (stale) price, and missed the Recovery Mode rule. About 40 minutes later the owner
topped up the loan and the chance was gone.

0.5% of a billion-dollar loan's collateral is a very large tip.

## 2. Concepts you need

| Term | Plain meaning |
|---|---|
| **Trove** | Liquity's name for one loan: collateral (ETH) plus debt (LUSD). |
| **ICR** (Individual Collateral Ratio) | The loan's collateral value divided by its debt. 150% means $1.50 of ETH per $1 borrowed. |
| **TCR** (Total Collateral Ratio) | The same ratio for all loans combined. |
| **MCR** | Minimum collateral ratio, 110%. Below it you can always be liquidated. |
| **Recovery Mode** | Kicks in when TCR < 150%. Then any trove with ICR < TCR can be liquidated, provided the Stability Pool can absorb its full debt. |
| **Stability Pool** | A pot of LUSD deposited by savers. It repays liquidated debt and receives the collateral at a discount. |
| **Gas compensation** | The liquidator's reward: 0.5% of the liquidated collateral plus 200 LUSD. |
| **Price feed** | Liquity keeps a stored `lastGoodPrice` and refreshes it from Chainlink whenever someone calls `fetchPrice()`. `liquidate` refreshes it too. |

## 3. How it was solved

### Step 1: Identify the protocol and the borrower
The "rebalance" transaction in the README (block 12,465,216) is an `adjustTrove` call on
Liquity's **BorrowerOperations** (`0x2417…e007`), sent by
**`0x903d12bf2c57A29f32365917c706ce0e1a84Cce3`**. That's our whale.

Liquity's other core contracts (from their docs and Etherscan):
- TroveManager `0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2`
- PriceFeed `0x4c517D4e2C851CA76d7eC94B805269Df0f2201De`
- StabilityPool `0x66017D22b0f8556afDd19FC67041899Eb65a21bb`

### Step 2: Read the state at block 12,465,029 (13:15 UTC)
Using `cast call ... --block 12465029`:

| Value | Reading |
|---|---|
| Whale trove | **606,280 ETH** collateral, **899,999,899 LUSD** debt |
| Stored `lastGoodPrice` | $2,096.66 |
| ICR / TCR at the *stored* price | 141.2% / 153.7%, so not in Recovery Mode and nothing looks liquidatable |
| Simulated `fetchPrice()` (fresh Chainlink) | **$1,976.54** |
| Stability Pool deposits | **1,076,032,270 LUSD**, more than the 900M debt |

That's the catch. At the stored price everything looks fine. Refresh the price and:

- Whale ICR = 606,280 × 1,976.54 / 900M = **133.1%**
- System TCR = **144.9%**, below 150%, so **Recovery Mode is on**
- 133.1% < 144.9%, and the Stability Pool can cover 900M, so the whale is **liquidatable**.

### Step 3: Work out the reward
In Recovery Mode (for 110% ≤ ICR < TCR), Liquity doesn't seize all the collateral. It
**caps** it at 110% of the debt, and the rest (the "surplus") goes back to the borrower:

```
capped collateral = debt × 1.1 / price = 900M × 1.1 / 1976.54 ≈ 500,875 ETH
liquidator reward = 0.5% × 500,875     ≈ 2,504.38 ETH   (+200 LUSD)
Stability Pool    = 99.5% × 500,875    ≈ 498,371 ETH
borrower surplus  = 606,280 − 500,875  ≈ 105,405 ETH
```

2,504.38 + our 0.1 ETH = 2,504.48 ETH. That clears the 2,500 target, which was clearly
chosen with this exact number in mind.

### Step 4: Do it
One call. `TroveManager.liquidate(whale)` refreshes the price itself, detects Recovery
Mode, and pays the reward to `msg.sender`. The solution calls `fetchPrice()` first only so
it can log the numbers.

## 4. The solution code

`challenges/03-too-big-to-fail/Solution.t.sol` (interfaces in `Interfaces.sol`, addresses in `Constants.sol`):

```solidity
ITroveManager tm = ITroveManager(TROVE_MANAGER);

// Stored price is stale ($2,096). Fresh Chainlink price ($1,976) pushes TCR below 150%.
uint256 price = IPriceFeed(PRICE_FEED).fetchPrice();
console.log("price        %18e", price);
console.log("whale ICR    %18e", tm.getCurrentICR(WHALE, price));
console.log("system TCR   %18e", tm.getTCR(price));
console.log("recovery?    %s", tm.checkRecoveryMode(price));

// Recovery Mode: ICR < TCR and the Stability Pool can absorb the debt -> liquidatable.
tm.liquidate(WHALE);
```

Output:
```
[PASS] test_Solution() (gas: 513962)
  price        1976.54
  whale ICR    1.331485339318991662
  system TCR   1.448911651445323625
  recovery?    true
  Solved. Ending balance in ETH: 2504.476053968045169842
```

The whole liquidation costs about 514k gas. It was not "too big to process". A single
ordinary transaction could have done it.

## 5. Takeaways

- **Know every liquidation rule, not just the famous one.** The 110% threshold is what everyone monitors. Recovery Mode is a separate, system-wide trigger.
- **Stored state can be stale.** Liquity's saved price made the system look healthy. The truth appeared only after pulling the fresh oracle price. Always simulate with fresh inputs.
- **One giant position weighs on the whole system.** This trove held 606,280 of the 941,570 ETH in Liquity (`getEntireSystemColl()`), about 64%, so its health and the system's health were tightly linked.
- **Reward size scales with position size.** 0.5% is a tiny rate, but on ~500k ETH it's 2,500 ETH for one transaction.
