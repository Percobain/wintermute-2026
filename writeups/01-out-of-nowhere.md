# 01 · Out of Nowhere (Tier 1, 25 pts)

> You notice [a $1.5M transfer](https://etherscan.io/tx/0xe7b8d46c3f3e5f727cb42c9dfe7fc36855ab5092cf160e4c8812a2a27a84350b)
> to one of the liquidity providers. But what was the source?

**Answer:** `origin_tx = 0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc`
(a transaction on the **Stacks** blockchain). `python alpha.py check 01` → **correct**.

---

## 1. The story in plain English

Picture two banks in different countries that don't talk to each other. You want to move
$1.5M from Bank A to Bank B, so you use a courier service with a vault in each country:

1. At Bank A you put $1.5M into the courier's vault and fill in a slip: *"send this to
  account X in country B, reference #12345."*
2. The courier's office checks the slip and signs it.
3. At Bank B, someone brings the signed slip, and the courier's local vault pays out
  $1.5M to account X.

The Ethereum transaction we were given is **step 3**, the payout. It looks like it came
from nowhere because the money never really moved between chains. It was paid from a
vault that was already on Ethereum. Our job was to find **step 1**: the deposit on the
other chain. The reference number (`lockId`) printed on both "slips" ties them together.

## 2. Concepts you need (and nothing more)


| Term                                  | Plain meaning                                                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Blockchain / chain**                | A public ledger. Ethereum, Stacks, and Solana are separate ledgers that can't see each other.                                                                                   |
| **Transaction (tx) & hash**           | One entry in the ledger. Its hash (`0x…`) is its unique ID, like a receipt number.                                                                                              |
| **Smart contract**                    | A program that lives on the chain and holds money under fixed rules. The "vault" here is one.                                                                                   |
| **Bridge**                            | A service that moves value between chains. Usually it **locks** tokens on chain A and **unlocks** (or mints) the same amount on chain B after an off-chain validator signs off. |
| **Calldata / decoded input**          | The arguments someone sent to a contract function. Explorers can show them in readable form.                                                                                    |
| **Liquidity provider / market maker** | A trading firm that moves large sums across venues. Big bridge transfers to them are normal.                                                                                    |




## 3. How the investigation went (repeatable)



### Step 1: Read the Ethereum transaction

Tools: any explorer (Etherscan / Blockscout) or `cast tx <hash>` from Foundry.

- **To:** `0xBBbD1BbB4f9b936C3604906D7592A644071dE884`. The explorer labels it **"Allbridge: Bridge"** (Allbridge Classic).
- **From / recipient:** `0xEc5f2EFa1A13c81179dDb0f0d4385e99E275994b` (the liquidity provider, which also paid gas to collect the funds itself)
- **Function called:** `unlock(uint128 lockId, address recipient, uint256 amount, bytes4 lockSource, bytes4 tokenSource, bytes32 tokenSourceAddress, bytes signature)`
- **Token moved:** 1,498,500 USDC out of the bridge contract, to the recipient
- **Time:** 2026-01-28 17:56:59 UTC, block 24,334,977

That function name tells us most of the story: it's the **payout** half of a bridge.

### Step 2: Decode the clues in the arguments


| Argument      | Raw value                                                                      | Meaning                                                     |
| ------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| `lockId`      | `1796419105728715166915089084934490630` = `0x0159fa4cd496a40b6531521bb9138a06` | The shared reference number                                 |
| `lockSource`  | `0x53544b5a` → ASCII `STKZ`                                                    | The chain where the deposit happened                        |
| `tokenSource` | `0x45544800` → `ETH`                                                           | The token originally comes from Ethereum (USDC)             |
| `amount`      | `1498500000000000`                                                             | 1,498,500 USDC in the bridge's 9-decimal "system precision" |


`STKZ` isn't a well-known ticker, so we checked the Allbridge Classic web app. Its
JavaScript bundle (`app.allbridge.io/main.*.js`) contains a mapping of chain codes:
`n.STKS="STKZ"`, so **STKZ = Stacks**, a Bitcoin-anchored chain. The same bundle also names
the Stacks bridge contract: `SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge`.

(The verified Ethereum `Bridge.sol` confirms how this works. `unlock` checks a validator
signature, then pays out from the contract's own USDC balance. Nothing arrives from Stacks
during this transaction.)

### Step 3: Find the matching deposit on Stacks

Stacks has a free public API (Hiro). We listed the bridge contract's transactions and
paged back to late January 2026:

```
GET https://api.mainnet.hiro.so/extended/v1/address/SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge/transactions?limit=50&offset=…
```

Then we searched the function arguments for our `lockId`. Exactly one `lock` call matched:


| Field         | Value                                                                                                                                                                                  |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Stacks tx** | `[0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc](https://explorer.hiro.so/txid/0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc?chain=mainnet)` |
| Time | 2026-01-28 **17:41:06** UTC (Stacks block; its Bitcoin anchor block is 17:33:48), 16 minutes before the Ethereum payout |
| Sender        | `SP388WPTVQMET2Z7M3ANQ6VRR8AATBF8VDPH0RRF9`                                                                                                                                            |
| Function      | `lock`                                                                                                                                                                                 |
| lock-id       | `0x0159fa4cd496a40b6531521bb9138a06` ✅ same reference number                                                                                                                           |
| Token         | `…token-aeusdc` (Allbridge-wrapped USDC on Stacks)                                                                                                                                     |
| Amount        | `u1500000000000` = **1,500,000**                                                                                                                                                       |
| Recipient     | `0xec5f2efa1a13c81179dd…994b` ✅ the Ethereum address that got paid                                                                                                                     |
| Destination   | `0x45544800` = `ETH` ✅                                                                                                                                                                 |


Everything matches: same ID, same recipient, and 1.5M in minus a 1,500 USDC (0.1%) bridge
fee equals the 1,498,500 out.

Side note: a day later the same Stacks sender locked another 3,000,000 to the same Ethereum
address (tx `0x6348f103…8432`), so this is a repeat flow, not a one-off.

## 4. Final answer

```
origin_tx = 0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc
```



## 5. What to take away

- **Bridge payouts don't show where money came from.** On the destination chain you only see the vault paying out. The source is on another ledger.
- **Read the function arguments.** An ID (`lockId`, nonce, message hash) plus a source-chain code are usually printed right there.
- **Unknown codes can often be decoded from the protocol's own frontend.** A dapp's JavaScript bundle is public and often holds the chain list and contract addresses.
- **Check more than one field.** Amount minus fee, recipient, destination, and timestamps should all agree before you're confident.

