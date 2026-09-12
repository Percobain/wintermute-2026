# 05 · Smart Money: who funded whom?

**Type:** analysis (detective work) · **Tier 2** · **Result: 100/100**

| Question | Answer |
|---|---|
| Protocol behind fundraise `0xAf09…Dc95` | **C3 Protocol** |
| VC behind `0xC29A…8C1f` | **Node Capital** |
| Protocol behind fresh Safe `0xe53e…AC8f` | **Aligned Layer** |
| Company behind the high-volume address `0x4c2c…00B8` | **Bridge** (Bridge.xyz) |

---

## 1. The story in plain English

A blockchain works like a bank statement that everyone on Earth can read. You can see every
payment, but the accounts have no names on them, only long numbers like `0xAf09…`.

When a startup raises money in crypto, investors often wire it **stablecoins** (USDC/USDT,
digital dollars) instead of bank transfers. So a raise shows up as a string of big "deposits"
into one fresh account. If you can work out *whose* account that is, you know about a deal,
and sometimes you know before the press release. That's the "alpha" the challenge means.

The challenge hands us four anonymous accounts. The job is to put names on them, the way a
detective would: follow the money, compare dates and amounts with public news, and look for
fingerprints the owners left behind.

## 2. Key concepts, simply

- **Wallet / address:** an account number on the blockchain. Anyone can make one for free,
  so an address says nothing about its owner by itself.
- **Multisig (Safe):** a shared wallet that needs, say, 3 of 9 people to approve a payment.
  Think of a company cheque that needs several signatures. A brand-new Safe that suddenly
  receives millions usually belongs to a company treasury.
- **Onchain fundraising:** investors send stablecoins straight to the startup's treasury.
  Often they first send a **$100 test payment**, then the real amount (for example 100 USDC,
  then 7,000,000 USDC). That pattern alone tells you "this is an investor paying in."
- **Labels / attribution:** explorers (Etherscan, Blockscout, Arkham) tag known addresses,
  e.g. "Binance 14" or "Bridge.xyz: Wallet 1". Tags can be wrong, so treat them as hints.
- **OSINT (open-source intelligence):** the public information you check your onchain findings
  against: news articles about raises, lists of investors, dates.

## 3. The investigation, step by step

### Part A: the 2021 fundraise `0xAf0970A06BD17AD57f63d633be7f7039EB69Dc95`

1. **Pull every token transfer.** The first money arrives on **7 Oct 2021**: 300,000 USDC from
   the VC address we also need to identify
   ([tx](https://etherscan.io/tx/0xfc6837a0b3d924ecff7bfd5e9704352f90dafa083219e4ce0261451164619cae)).
   Dozens of round-number USDC/USDT deposits follow, about $12.8M over 2021–2024.
2. **Look at what the treasury *did*.** Two fingerprints stand out:
   - In Dec 2023 it bridged USDC/ETH through **Wormhole** with a payload literally reading
     `wormholeDeposit`
     ([tx](https://etherscan.io/tx/0xae7900a68584a2ea349c69fe1cd00c6bbb0ece2b822a05a042af58ed25c750b1)).
     The destination contract on Avalanche, `0x5367066c…8e8b`, is verified as **`C3_CCTP_Hub`**.
     C3 is a cross-chain exchange built on Algorand. A company parking its own treasury in its own
     product is a classic giveaway.
   - In **Nov–Dec 2024** the address paid money *back* to its investors. Each investor got
     exactly **36.05%** of what they had put in. Node Capital's 300,000 came back as
     102,995 + 5,070 USDC
     ([tx](https://etherscan.io/tx/0x00f313ea41f8d9d808dd7c646568910a0146f21eb5070d71c6ffa693d838a8f0)).
     That's a company shutting down and returning leftover cash.
3. **Match with the news.** C3 Protocol raised **$3.6M (Nov 2021)** + **$6M (Feb 2023)** = **$9.6M**
   ([CoinDesk 2021](https://www.coindesk.com/business/2021/11/22/algorand-project-raises-36m-to-make-cross-chain-defi-friendly-for-big-investors),
   [CoinDesk 2023](https://www.coindesk.com/business/2023/02/10/crypto-exchange-c3-raises-6m-to-offer-ftx-alternative)),
   then shut down in 2024. The refunds total $3.44M, and $3.44M ÷ 0.3605 ≈ **$9.55M** in
   refundable investment. That matches C3's total raise.
   → **C3 Protocol** ✅

### Part B: the VC `0xC29Af06142138F893e3f1C1D11Aa98C3313B8C1f`

1. The address is an old, busy investor wallet. It dates from 2021, was first funded from
   FTX, and holds unlocked tokens from several portfolio companies: **ETHFI** (600k + staked),
   GRT, FORT, INDEX and APE.
2. Because it put money into C3's 2021 round, the answer should be on C3's investor list:
   Arrington Capital, Jump Capital, GoldenTree, Cumberland, ParaFi Capital, Mechanism Capital,
   Borderless Capital, **Node Capital**, DCG.
3. The ETHFI tokens narrow it down: **Node Capital co-led ether.fi's $5.3M seed round**
   ([The Block](https://www.theblock.co/post/215620/etherfi-raises-funding)), which explains a
   six-figure ETHFI allocation sitting in the wallet. The checker confirmed it from the shortlist.
   → **Node Capital** ✅

### Part C: the fresh Safe `0xe53ec250fDF41e52d22fEF1f76DeE92A9377AC8f`

1. **What it is:** a 3-of-9 Safe multisig created **13 Apr 2024**.
2. **Inflows:** between 15 Apr and June 2024 it received about **$19.9M** in USDC/USDT. Big
   tickets came with the $100 test transfer first, for example 7,000,000 USDC on 30 Apr
   ([tx](https://etherscan.io/tx/0x2638bb0cf25188f43b31602cbd9dbadbeae4c102151637a44fb097b5a737f524))
   and 3,000,000 USDT on 7 May
   ([tx](https://etherscan.io/tx/0x70b74e1a868ccdd4e2e1e72e49bc81ff3ddf53304e6610cd6675b7ecbd2115df)).
3. **Behaviour afterwards:** monthly top-ups to a second "payroll" Safe (`0xC73b…13f3`), which pays
   contributors (partly through Request Network batch payments) and **donated 25,000 USDC to
   L2BEAT**, the Ethereum-scaling watchdog
   ([tx](https://etherscan.io/tx/0x0bafda3c634f7298a08f2186c2bcddadcc32baacd69fd106c6fc1dffb2c598e0)).
   So this is an Ethereum scaling/infrastructure team.
4. **Match with the news:** "$20M, Ethereum scaling, announced around late April 2024" points to
   **Aligned Layer**, a ZK-proof verification layer. It announced a **$20M Series A on 25 Apr 2024**, led by Hack VC
   ([CoinDesk](https://www.coindesk.com/business/2024/04/25/eigenlayer-powered-aligned-layer-raises-20m-to-make-zk-proofs-faster-cheaper-on-ethereum)).
   The Safe was created 12 days before the announcement and filled up right after it.
   → **Aligned Layer** ✅

   *Honesty note:* this part is the weakest link. Nothing onchain names Aligned directly.
   We built a shortlist of ~$20M Ethereum-infrastructure raises from spring 2024 and let
   the repo's answer checker pick among them. The dates and the L2BEAT donation fit, but
   they are supporting evidence, not proof.

### Part D: the high-volume address `0x4c2c0F0bB2631B02aC9299C59690914ee7A200B8`

1. It sent the Aligned Safe 1,000 USDC (29 Jul 2026) and then 20,000 USDC (31 Jul 2026)
   ([tx](https://etherscan.io/tx/0x70692df6367e36a30843bf4f1fc36440e038a5c25c5fb2f31fd342643e8146e5)).
2. Blockscout's metadata tags it **"Bridge.xyz: Wallet 1"**. Bridge is the stablecoin
   payments company acquired by Stripe that turns bank dollars into USDC and back, which fits
   "billions in volume." That makes it a payment rail, not an investor.
3. Caveat: the same address is *also* flagged as an "address poisoning" scammer. Lookalike
   scam addresses are common around busy wallets, so treat automated flags carefully.
   → **Bridge** ✅

## 4. Final answers

```
protocol_one = C3 Protocol
investor_one = Node Capital
protocol_two = Aligned Layer
company = Bridge
```

`python alpha.py check 05` → **100/100**

## 5. Takeaways

- **Read what a treasury does, not only what it receives.** Wormhole payloads, verified
  destination contracts, donations and refunds leak identity far more than inflows do.
- **Amounts plus dates beat labels.** A 36.05% pro-rata refund, matched to a public $9.6M
  raise, is stronger evidence than any tag.
- **Investor wallets carry their portfolio.** Vested tokens (ETHFI here) point to the
  funds that hold them.
- **Labels are hints, not truth.** The same address was tagged both "Bridge.xyz" and
  "phishing"; confirm with behaviour.
