# 06 · Cold Start (Tier 3, 150 pts)

> **Goal:** have at least 1,000,000 CASHCAT on Robinhood Chain, a brand-new Layer 2. The only thing you can reach is an Ethereum contract called the *Delayed Inbox*.
>
> **Result:** ✅ `forge test` passes with **3,086,703 CASHCAT** from one 0.5 ETH buy.

---

## 1. The story in plain English

Picture a new island city (Robinhood Chain) just offshore from a big, busy capital (Ethereum).
A shop on the island has started selling a collectible called **CASHCAT**, and you want some.

The catch is that you can't get to the island yet. There's no ferry terminal (no public RPC),
no ticket booth (no bridge website), and no map (no block explorer).

The island does have one thing every city like it has: a **mailbox in the capital**.
Every letter dropped into it gets carried to the island and carried out there.
The island can't ignore these letters. That's the whole point of the mailbox.

So the plan is simple. Write a letter that says *"Take this 0.5 ETH, go to the island's
exchange, buy CASHCAT with it, and deliver the cats to my home address."* Put enough money
in the envelope to cover postage and the purchase, then drop it in the mailbox.

---

## 2. Key concepts, simply

| Concept | What it means |
|---|---|
| **L1 / L2 (rollup)** | Ethereum is the L1. A rollup like Robinhood Chain is an L2: a faster, cheaper chain that runs its own transactions but records them on Ethereum for security. |
| **Sequencer** | The single operator that orders L2 transactions and produces L2 blocks. Normally you send your transaction to the sequencer through an RPC. |
| **Delayed Inbox** | A contract **on Ethereum** that anyone can put messages into. The rollup has to process them, which is how users stay safe from a sequencer that censors them or goes offline. Arbitrum-style chains call it the `Inbox`. |
| **Retryable ticket** | The main kind of message you put in the Inbox. It says: "on L2, call contract `to` with `data` and send it `l2CallValue` ETH." You pre-pay the ETH, a storage fee (`maxSubmissionCost`) and L2 gas (`gasLimit × maxFeePerGas`). If the L2 call fails, it can be retried later. |
| **Address aliasing** | When an L1 address sends a message to L2, the L2 sees the sender as `address + 0x1111…1111`. This stops someone on L1 from pretending to be a contract with the same address on L2. **So the L2 call does not come from your address.** Anything sent to `msg.sender` lands at the alias, which you don't control. |
| **Uniswap V3 pool and router** | A DEX, which is an automated exchange. The *pool* holds CASHCAT and WETH and prices them with a formula. The *router* is the easy front door: you tell it "swap X of this for at least Y of that and send it to address Z." |
| **Launch token** | CASHCAT came from a token launchpad that set up its pool automatically. It also shipped anti-sniping rules: at most 2% of supply per wallet during the first blocks. |

---

## 3. How I figured it out

### Step 1: What is CASHCAT?
The official public RPC doesn't keep old state ("metadata is not found" at block 120000),
but dRPC does (`https://robinhood.drpc.org`). Reading the token at L2 block 120000 gave:

```
name/symbol      Cash Cat / CASHCAT, 18 decimals, 1,000,000,000 supply
launchFactory()  0xD9eC2db5f3D1b236843925949fe5bd8a3836FCcB   (a token launchpad)
liquidityPool()  0xA70fc67C9F69da90B63a0e4C05D229954574E313   (Uniswap V3 pool)
pairToken()      0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73   (WETH)
poolFee()        10000                                          (1% fee tier)
maxWalletAmount  20,000,000 CASHCAT                             (anti-snipe cap; we need only 1M)
```

The token has no mint or claim function, so the tokens have to be **bought**.

### Step 2: Is the pool worth buying from?
- `slot0().sqrtPriceX96 = 3.12e25` works out to about 1.55e-7 WETH per CASHCAT, so 1M CASHCAT is roughly 0.16 ETH.
- The pool holds about **93.7M CASHCAT and 13.2 WETH**. That's plenty of depth.

### Step 3: Find a way to trade
An EOA can't call `pool.swap()` directly, because the pool pays you first and then calls back
into the caller to collect payment. We needed a router. dRPC's free plan rejects log queries
over big block ranges, but the official RPC doesn't. I pulled every pool event up to block
120000: 1 Initialize, 1 Mint, and **882 Swaps**. Every single swap had the same `sender`:

```
0xCaf681a66D020601342297493863E78C959E5cb2
```

Its bytecode includes the selectors `multicall(uint256,bytes[])` (`0x5ae401dc`),
`exactInputSingle` (`0x04e45aaf`) and `exactOutputSingle` (`0x5023b4df`). That's
**Uniswap SwapRouter02**, and its `WETH9()` is the pool's WETH. SwapRouter02 wraps native
ETH automatically when you send ETH along with the call, so a single call does the whole buy.

### Step 4: Check that the Inbox accepts the ticket
On Ethereum at block 25347213 the Inbox (`0x1A07…7a2D`) isn't paused, and `setUp()` turns
its allow-list off. `calculateRetryableSubmissionFee(len, basefee)` tells us the minimum
storage fee to pay.

### Step 5: Read the test's relay
`_relay()` stands in for the sequencer. It decodes the 9-word retryable header (`to`,
`l2CallValue`, …, `data.length`) plus `data` from the Inbox's `InboxMessageDelivered` event.
Then it runs `to.call{value: l2CallValue}(data)` on L2 from the **aliased** user. That's why
the router's `recipient` has to be our real `user` address.

---

## 4. The solution

```solidity
// 1. The L2 call we want executed: buy CASHCAT with 0.5 ETH on the
//    Uniswap router, sending the tokens to our real (unaliased) address.
uint256 buyAmount = 0.5 ether;
bytes memory swapCall = abi.encodeCall(
    ISwapRouter02.exactInputSingle,
    (ISwapRouter02.ExactInputSingleParams({
        tokenIn: L2_WETH,               // pay with (auto-wrapped) ETH
        tokenOut: CASHCAT,              // receive CASHCAT
        fee: CASHCAT_POOL_FEE,          // the 1% pool
        recipient: user,                // NOT msg.sender (that's the alias!)
        amountIn: buyAmount,
        amountOutMinimum: 1_000_000e18, // revert if we'd get less than the goal
        sqrtPriceLimitX96: 0            // no price limit
    }))
);

// 2. Pay for the ticket: storage fee for the calldata plus L2 gas.
uint256 submissionCost = IInbox(INBOX).calculateRetryableSubmissionFee(swapCall.length, block.basefee) * 2 + 0.001 ether;
uint256 gasLimit = 1_000_000;
uint256 maxFeePerGas = 1 gwei;
uint256 total = submissionCost + buyAmount + gasLimit * maxFeePerGas;

// 3. Post the retryable ticket to the Delayed Inbox on Ethereum.
IInbox(INBOX).createRetryableTicket{value: total}(
    L2_SWAP_ROUTER,   // to: the Uniswap router on Robinhood Chain
    buyAmount,        // l2CallValue: ETH delivered with the call
    submissionCost,   // maxSubmissionCost
    user, user,       // refund addresses for leftover fees / call value
    gasLimit, maxFeePerGas,
    swapCall          // data
);
```

Line by line:
- **`swapCall`** is the letter's contents: an ABI-encoded call to the router. `recipient: user` is the key detail.
- **`amountOutMinimum`** protects the buy. If the price had moved and 0.5 ETH bought fewer than 1M cats, the swap would revert instead of quietly failing the goal.
- **`submissionCost`** pays L2 to store the ticket. I pay double the quoted minimum plus a small buffer, and the extra is refunded to `user`.
- **`gasLimit × maxFeePerGas`** pre-pays L2 execution. Both must be above 1, because the values 0 and 1 have special meanings in Arbitrum.
- **`createRetryableTicket`** requires `msg.value ≥ submissionCost + l2CallValue + gas`, which `total` covers.

I added `IInbox.createRetryableTicket`, `calculateRetryableSubmissionFee` and a minimal
`ISwapRouter02` to `Interfaces.sol`, and put the router, WETH and fee constants in `Constants.sol`.

Run it:
```
forge test --match-path challenges/06-cold-start/Solution.t.sol --match-test test_Solution -vvv
# [PASS] test_Solution()  Cold Start solved. CASHCAT: 3086703.63
```

---

## 5. Takeaways

- **A rollup can't lock you out.** Even without an RPC, bridge UI or explorer, the L1 Delayed Inbox always gets your transaction onto the L2. That's the censorship-resistance promise of rollups, and it also makes a handy back door during a "cold start."
- **Remember aliasing.** Anything cross-chain that pays `msg.sender` sends funds to an address you don't control. Always set an explicit recipient.
- **When there's no explorer, events are your explorer.** Scanning the pool's `Swap` logs showed which router the whole market was using within seconds.
- **Selectors identify contracts.** Without verified source, the function selectors in the bytecode (`cast selectors`, 4byte) were enough to recognize Uniswap SwapRouter02.
