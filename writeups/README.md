# Wintermute Alpha Challenge 2026: plain-English writeups

> **New here? Start with [MASTER.md](MASTER.md)**: one sequential, in-depth walkthrough of everything (setup, intuition, mechanics, solutions).

One file per challenge. Each starts with the story in everyday language, explains only the
concepts it needs, then shows exactly how it was solved, so you can repeat it yourself.

| # | Challenge | Kind | What it's really about | Result |
|---|---|---|---|---|
| 01 | [Out of Nowhere](01-out-of-nowhere.md) | find | A $1.5M bridge payout on Ethereum. Trace it back to the deposit on Stacks. | ✅ 25/25 |
| 02 | [Falling Dutchman](02-falling-dutchman.md) | code | A forgotten Dutch auction had fallen to ~2% of market price. Buy it and sell on Uniswap. | ✅ 0.1 → 8.65 ETH |
| 03 | [Too Big To Fail](03-too-big-to-fail.md) | code | A $1B Liquity loan was liquidatable under the little-known "Recovery Mode" rule. | ✅ 2,504 ETH |
| 04 | [First Blood](04-first-blood.md) | find | The TRUMP memecoin launch on Solana: first sniper tx and the tx that opened trading. | ✅ 100/100 |
| 05 | [Smart Money](05-smart-money.md) | find | Identify VC fundraises and investors from wallet flows (OSINT). | ✅ 100/100 |
| 06 | [Cold Start](06-cold-start.md) | code | Buy a token on a brand-new L2 using only its Ethereum "mailbox" (Delayed Inbox). | ✅ 3.09M CASHCAT |
| 07 | [Firepit](07-firepit.md) | code | Sweep uncollected Uniswap fees into the jar, burn UNI to claim them, sell for USD₮0. | ✅ 55,176 USD₮0 |
| 08 | [First Move](08-first-move.md) | find | Compute the honest first counter-claim in Optimism/Ink fault-dispute games. | ✅ 150/150 |

## 60-second crypto glossary

- **Blockchain:** a public ledger everyone can read. Every transfer and every program call is visible forever.
- **Transaction (tx) / hash / signature:** one ledger entry, and its unique ID.
- **Smart contract:** a program living on the chain that holds money and follows fixed rules. Anyone can call it.
- **Token:** a balance tracked by a contract (USDC, KNC, UNI...). **ETH** is Ethereum's native coin, and **WETH** is ETH wrapped as a token.
- **L1 / L2:** Ethereum is the L1 ("layer 1"). L2s (Optimism, Arbitrum, Robinhood Chain, Ink, X Layer) are cheaper chains that post their records back to Ethereum.
- **DEX / pool:** an automated exchange (Uniswap). A pool of two tokens sets a price by formula.
- **Liquidation:** force-closing an under-collateralized loan. Whoever triggers it earns a reward.
- **MEV / searcher / bot:** people running programs that watch the chain for profitable actions like these.
- **Fork test:** Foundry copies a real chain's state at an old block into a sandbox, so you can run "what if I had done X then?" without spending real money.

## How to run it yourself

```bash
# 1. tools: Python 3 and Foundry (https://book.getfoundry.sh)
forge install foundry-rs/forge-std

# 2. .env (free public archive RPCs that worked for us)
ETH_RPC_URL=https://eth.drpc.org
ROBINHOOD_RPC_URL=https://robinhood.drpc.org
XLAYER_RPC_URL=https://rpc.xlayer.tech
USER_ADDRESS=0x6937971feb0fe24f963d3431eebb39d75c2087bf

# 3. score
python alpha.py check        # everything
python alpha.py check 03     # one challenge
```

Free public RPCs are rate-limited. If a fork test fails with a 429 / "rate limit" error,
just rerun it or plug in your own Alchemy/Infura/dRPC key.
