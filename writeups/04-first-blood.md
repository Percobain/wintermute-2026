# 04 · First Blood — who tried to buy TRUMP first, and what actually opened the doors?

> **Answers** (verified with `python alpha.py check 04` → 100/100)
>
> - `first_snipe` = `41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv`
> - `trading_possible` = `4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt`

---

## 1. The story in plain English

On the evening of 17 January 2025, Donald Trump announced an "official" memecoin called **TRUMP**
on the Solana blockchain. Within a day it was worth billions.

Think of a new shop opening in a mall:

- The shop was **built and stocked** in the morning, with shelves full of TRUMP tokens (the
  *pool* was created and *liquidity* was added).
- About 45 minutes later the mall manager **locked the front door** (the pool was *disabled*).
- Everything happens in public on a blockchain, so a few professional bargain hunters (*snipers*)
  saw a fully stocked shop with a locked door and worked out what was coming. Their robots started
  **rattling the door handle** thousands of times, hoping to be first inside when it unlocked.
- At 02:01 UTC the manager **unlocked the door**. The robots got in within about a second, and one
  of them turned roughly $1M into over $100M.

The challenge asks two things:

1. **The first rattle of the handle**: the earliest transaction that tried to buy TRUMP.
2. **The key turning in the lock**: the transaction that actually made buying possible.

---

## 2. Key concepts, simply

| Term | What it means here |
|---|---|
| **Solana** | A blockchain: a public, shared ledger that anyone can read. Every action is a *transaction*. |
| **Transaction signature** | The unique ID of a Solana transaction, a long base58 string like `4SMUTho7…`. It is the same idea as a receipt number. You can paste it into [solscan.io](https://solscan.io) to see what happened. |
| **Slot** | Solana's "tick" of time (about 0.4 s). Transactions are grouped into slots, and inside a slot they have a fixed order. |
| **Token mint** | The "master record" of a token. TRUMP's mint is `6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN`. |
| **Liquidity pool** | A robot market maker: a smart contract holding two tokens (here TRUMP and USDC, a dollar stablecoin) that anyone can trade against. TRUMP launched on a **Meteora DLMM** pool, a type of pool that places liquidity at discrete price "bins". |
| **Pool status / activation** | Meteora pools can have a start time (*activation point*) and an admin on/off switch (`TogglePairStatus`). While a pool is off, every swap fails with `PoolDisabled`. |
| **Sniper bot** | A program that watches the chain and tries to be the very first buyer of a new token, often paying big fees to jump the queue. |
| **Failed transaction** | On Solana a failed transaction is still recorded forever (and the sender still pays a fee). That is why we can see snipers' failed attempts today. |

---

## 3. The investigation, step by step

Everything below used only the free public RPC `https://api.mainnet-beta.solana.com` plus
DexScreener's public API. The Python helpers are tiny wrappers around JSON-RPC:

```python
import json, urllib.request
def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request("https://api.mainnet-beta.solana.com", body,
                                 {"content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))
```

### Step 1: Find the launch pool

Ask DexScreener for every pool containing the TRUMP mint:

```
curl https://api.dexscreener.com/latest/dex/tokens/6p6xgHyF7AeE6TZkSmFsko444wqoP15icUSqi2jfGiPN
```

The earliest Meteora TRUMP/USDC pool, with its first trade at 1737165693 (18 Jan 2025 02:01:33 UTC), is

**`A8nPhpCJqtqHdqUk35Uj9Hy2YsGXFkCZGuNwvkD3k7VC`** ([solscan](https://solscan.io/account/A8nPhpCJqtqHdqUk35Uj9Hy2YsGXFkCZGuNwvkD3k7VC))

### Step 2: Turn "02:01 UTC" into a slot

A binary search with `getBlockTime` lands on slot **≈ 314,693,472**. Scanning the next few blocks
with `getBlock` and looking for the pool address finds exactly one pool transaction in slot
314,693,476:

```
4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt
  signer: 5unTfT2kssBuNvHPY6LbJfJpLqEcdMxGYLWHwShaeTLi   (Meteora admin)
  log:    "Instruction: TogglePairStatus"
  time:   2025-01-18 02:01:32 UTC
```

Two slots later (314,693,478) the **first successful swaps** appear, one of them from the famous
sniper wallet `6QSc2CxSdkUQSXttkceR9yMuxMf36L75fS8624wJ9tXv`. A pool switch flipped, and a
second later people could buy. That makes it a strong candidate for the key in the lock.

### Step 3: Read the pool's own settings

Decoding the pool account (and the instruction data of its creation transaction) gives:

- `activation_type = 1` (timestamp), `activation_point = 1737153000`, which is **17 Jan 22:30 UTC**
- `has_alpha_vault = true`, `pre_activation_duration = 3600`

So by its own schedule the pool should have opened at 22:30. It didn't. Why not?

### Step 4: Rebuild the pool's full admin history

The pool creator `8tKLhRyFC3RsQ41APTqKdzr9DdeGqV2RtRgSjVgsY4xb` and the admin
`5unTfT2k…` have short histories, so `getSignaturesForAddress` on them gives the whole setup:

| Time (UTC) | Signature | What happened |
|---|---|---|
| 17 Jan 14:19:03 | [`2GcsWNeW…`](https://solscan.io/tx/2GcsWNeWVyYfiNybz9HQmiWvkboC2oTeikD5CLURfnwqrBGojdmc5GLZ1x6W4qw9Hx9xfjXaVgYngQdf8G5yncDR) | `InitializeCustomizablePermissionlessLbPair`: pool created |
| 14:25 – 14:52 | several | `InitializeBinArray`, `InitializePositionByOperator`, `AddLiquidity`: shelves stocked with TRUMP |
| **15:06:47** | [`4q2uYTeY…`](https://solscan.io/tx/4q2uYTeYzJFVuJB9Nqgs54rJUZEPYdBMpvVxyt2Tf3KYSkXVAqissNvR8QD7P2D98Jm5DSPSGnqdWXuaWT5BXVdg) | `TogglePairStatus` by Meteora admin: **pool switched OFF** |
| 18 Jan **02:01:32** | [`4SMUTho7…`](https://solscan.io/tx/4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt) | `TogglePairStatus` by Meteora admin: **pool switched ON** |

That 15:06 "admin touches a fully stocked TRUMP/USDC pool" transaction is the public leak the
sniper later described: *"we spotted an official Meteora address interacting with a TRUMP-USDC pool
a day before launch."*

Sampling blocks in between confirms it. Hundreds of swaps per block fail with

```
AnchorError ... Error Code: PoolDisabled. Error Number: 6042. Error Message: Pool disabled.
```

So the 22:30 activation time didn't matter. The on/off switch was the real gate, and
**`4SMUTho7…` is the transaction that made trading possible**. ✅

### Step 5: Find the very first snipe attempt

Now we page backwards through the pool's history, but only inside the window between the "OFF"
toggle and the flood of spam. `getSignaturesForAddress` accepts both `before` and `until`, so we
can ask for everything between a transaction at 22:31 and the 15:06 toggle:

```python
before = "4Z9KREiBDL1DHP6ZDTkByUbB18p3xJS3jGGx1BCXuzZbRuBqJCsPFy3nQwHLssLeG5CqCnjBreA28sPpGxfjtVaC"  # a pool tx at 22:31
until  = "4q2uYTeYzJFVuJB9Nqgs54rJUZEPYdBMpvVxyt2Tf3KYSkXVAqissNvR8QD7P2D98Jm5DSPSGnqdWXuaWT5BXVdg"  # the OFF toggle
while True:
    page = rpc("getSignaturesForAddress", [POOL, {"limit": 1000, "before": before, "until": until}])["result"]
    ...  # save, then before = page[-1]["signature"]
```

Only about 2,300 transactions sit in that window. Nobody touched the pool for 7 hours after it was
switched off, until:

| Time (UTC) | Slot | Signer | What it is |
|---|---|---|---|
| **17 Jan 22:05:52** | 314,658,584 (1st in block) | `8QxqUZgVf3r63sfkvgmNAwwaUjieS2B5wXkKixDHYfPG` | **[`41h3CuLH…`](https://solscan.io/tx/41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv)** |
| 22:05:52 | 314,658,584 (2nd) | same bot | `3QBCKibf…` |
| 22:23:06 | 314,661,149 | `CGVpySPUyt29cShujYB2UJf3US4mnFpELEjBPNFMbKRW` | first *plain* Meteora `Swap`, fails with `PoolDisabled` |

The earliest one, `41h3CuLH…`, succeeded, yet it bought nothing. Looking inside:

- It calls a private sniper program `2eRJBK8bkcsK3WfAG8D3K4p6PsWDQtdyv67j3Tudkpw1`.
- It carries **every account a Meteora swap on this pool needs**: the DLMM program, the pool,
  the oracle, both reserves, and the TRUMP and USDC mints.
- The program logs `NS` (read it as "not started"), pays a 55,000-lamport tip, and exits cleanly.

This is a smarter sniper design. The bot checks "is the pool open yet?" onchain and, if not,
**exits successfully instead of failing**, so it can spam cheaply until the door opens. It is still
an attempt to buy TRUMP from this pool, and it is the first one. Within a slot, `getBlock` lists
transactions in execution order, which shows `41h3CuLH…` ran before `3QBCKibf…`.

**`41h3CuLH…` is the first snipe attempt.** ✅

### Step 6: Check

```
$ python alpha.py check 04
04-first-blood  [analysis, tier 2]
  first_snipe        correct
  trading_possible   correct
  100/100 points
```

---

## 4. Final answers

```
first_snipe      = 41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv
trading_possible = 4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt
```

---

## 5. Takeaways

- **"Secret" launches are not secret on a public chain.** Building and stocking a pool hours ahead,
  then flipping it off with an admin key, broadcast the plan to anyone watching Meteora's admin
  address.
- **The scheduled start time was not the real gate.** The pool said "open at 22:30", but the admin
  switch overrode it. When a question asks what *actually* enabled something, read the error
  messages. `PoolDisabled` pointed straight at the switch.
- **"First attempt" doesn't have to mean "failed transaction".** The best bots check state onchain
  and exit quietly, so their attempts show up as *successful* no-op transactions. Filtering for
  failed swaps alone would have missed the real first sniper by 17 minutes.
- **Investigation technique:** narrow the time window before paging (binary-search slots by
  `getBlockTime`, then use `before`/`until` bounds). Otherwise you end up crawling millions of spam
  transactions through a rate-limited public RPC.

Sources: [Bubblemaps thread on the sniper](https://x.com/bubblemaps/status/1891829612952551608),
[coincept: "Milliseconds to Millions"](https://coincept.substack.com/p/milliseconds-to-millions-snipers),
[Helius: TRUMP's weekend on Solana](https://www.helius.dev/blog/trump-solana-memecoin-records-trends-insights).
