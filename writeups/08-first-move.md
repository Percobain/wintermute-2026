# 08 · First Move (Tier 3, 150 pts)

> Two fake "dispute games" were opened on Ethereum, one about Optimism and one about Ink.
> Both make the same nonsense claim, `0xdeadbeef…`. Your job is to work out the exact
> 32-byte counter-claim an honest challenger would post as the first move against each.

**Answers**

```
ink_claim = 0x82c941153a9de14c4533b301799ee33206b6a475d7c4fdbe7cd2f1c9d7271b6f
op_claim  = 0x192f163548d61d555a282e1ffcec8ec7b1e4cf9deced7e910b87292f0aeab5f1
```

`python alpha.py check 08` gives `150/150`.

---

## 1. The story in plain English

**Rollups send summaries to Ethereum.** Optimism (OP Mainnet) and Ink are *rollups*: separate
blockchains that run their own transactions, then report back to Ethereum. Ethereum doesn't
re-run all that work. Instead, someone posts a one-line summary to Ethereum: *"after block N,
the chain's state fingerprint is X."* People use these summaries to withdraw money from the rollup
back to Ethereum. A false summary could let someone steal funds.

**Anyone can post a summary, and anyone can dispute it.** Posting one opens a **fault dispute
game**, which works like a court case. Posting a claim requires a bond (a cash deposit). If
someone proves the claim wrong, they take the deposit. That's why the README says "being first
to dispute this might make us some money."

**The game is 20 questions with a timeline.** The claim covers millions of blocks, so nobody
re-checks all of it at once. The two sides narrow the disagreement by halving:

> Proposer: "From block S to block N, the final state is X."
> Challenger: "Wrong. And I say that halfway through, the state was Y." *(this is an **attack**)*
> …and so on, halving the range each time, until they disagree about a single step
> that Ethereum can check by itself.

This challenge asks only for the **first** counter-move: *"what was the state halfway?"*

---

## 2. Key concepts

| Term | Plain meaning |
|---|---|
| **Output root** | The 32-byte fingerprint of a rollup at one block. It's `keccak256(version ‖ stateRoot ‖ messagePasserStorageRoot ‖ blockHash)`. The version is 32 zero bytes. `messagePasserStorageRoot` is the storage root of contract `0x4200…0016`, which records withdrawals. |
| **Root claim** | The proposer's opening claim. Here it's `0xdeadbeef…`, which is garbage. |
| **startingBlockNumber** | The last block everyone already agrees on. It's the start of the disputed range. |
| **l2BlockNumber** | The block the root claim is about. It's the end of the range. |
| **Position / gindex** | Every move sits at a spot in a binary tree. The root is gindex 1. Its left child is 2, right child 3, then 4–7, and so on. A child of gindex `g` is `2g` (left, an **attack**) or `2g+1` (right, a **defend**). |
| **Split depth (30)** | The tree has two halves. Depths 0–30 argue about **output roots of L2 blocks**. Below that, they argue about single machine-execution steps. Depth 30 has 2³⁰ leaves, each standing for one block after the start. |
| **Trace index** | For any spot in the tree, it's the index of the right-most leaf below it at split depth. That leaf tells you which block the claim at that spot is about. |
| **Safe head** | The newest rollup block that can be fully rebuilt from data already posted to Ethereum. Newer blocks exist, but Ethereum can't vouch for them yet. |
| **l1Head** | An Ethereum block hash frozen into the game when it's created. The game may only use Ethereum data up to that block. |

---

## 3. Solving it step by step

### Step 1: which block is the "halfway" claim about?

`attack(rootClaim, 0, claim)` attacks the root (index 0), so the new claim goes to the root's
left child: **depth 1, gindex 2, index 0 at that depth**.

The block it talks about comes from the right-most leaf below it at depth 30
(`op-challenger/game/fault/types/position.go`, `TraceIndex`):

```
remaining depth  = 30 - 1 = 29
traceIndex       = (0 << 29) | (2^29 - 1) = 536,870,911
claimed block    = startingBlockNumber + traceIndex + 1 = startingBlockNumber + 2^29
```

| | startingBlockNumber | + 2²⁹ |
|---|---|---|
| Ink | 52,959,235 | 589,830,147 |
| OP  | 155,446,493 | 692,317,405 |

Both blocks are far in the future, since neither chain has reached them. So what does an honest
challenger post?

### Step 2: the honest challenger lowers the block number twice

The official Optimism challenger bot answers this. The code is in
`op-challenger/game/fault/trace/outputs/provider.go`:

```go
func (o *OutputTraceProvider) ClaimedBlockNumber(pos types.Position) (uint64, error) {
    traceIndex := pos.TraceIndex(o.gameDepth)
    outputBlock := traceIndex.Uint64() + o.prestateBlock + 1
    if outputBlock > o.poststateBlock {           // clamp 1: not past the game's l2BlockNumber
        outputBlock = o.poststateBlock
    }
    return outputBlock, nil
}

func (o *OutputTraceProvider) HonestBlockNumber(ctx context.Context, pos types.Position) (uint64, error) {
    outputBlock, _ := o.ClaimedBlockNumber(pos)
    resp, _ := o.rollupProvider.SafeHeadAtL1Block(ctx, o.l1Head.Number)
    if outputBlock > resp.SafeHead.Number {        // clamp 2: not past the safe head at l1Head
        outputBlock = resp.SafeHead.Number
    }
    return outputBlock, nil
}
```

Game type 8 is `CannonKonaGameType` (`op-challenger/game/types/game_type.go`). It's registered
with this same output-root provider for the top half of the tree, so no special rule applies.

* **Limit 1:** the game's `l2BlockNumber` is 1,787,098,259, which is still bigger, so nothing changes.
* **Limit 2:** the challenger can't honestly vouch for a block that Ethereum data (up to `l1Head`)
  doesn't back up. The answer drops to the **safe head as of the `l1Head` block**.

A fun detail: `l2BlockNumber` (1,787,098,259) equals the **timestamp** of the creation block. The
proposer probably confused a time with a block number. That's part of why these games show up so
often.

### Step 3: find the l1Head block

```
cast block 0xd74f3398…26f4 --rpc-url $ETH_RPC_URL
-> number 25785478, timestamp 1787098247   (parent of the creation block 25785479)
```

### Step 4: find each rollup's safe head at L1 block 25,785,478

Normally you'd ask a rollup node (`optimism_safeHeadAtL1Block`), but no public endpoint offers
that. Instead:

1. **Estimate where to look.** Both chains make blocks on a fixed clock (OP every 2 s, Ink every 1 s):
   - OP: `ts = 1475598777 + 2n`, so the L2 block at the l1Head time is about 155,749,735.
   - Ink: `ts = 1733498411 + n`, so it's about 53,599,836.

   The safe head sits a few minutes before that, because batches are posted to Ethereum in bursts.
2. **Compute output roots for the blocks just before that point.** Since the Isthmus upgrade, each
   L2 block header's `withdrawalsRoot` *is* the message-passer storage root, so one
   `eth_getBlockByNumber` call per block is enough. There's no need for `eth_getProof`.
3. **Check the formula first.** I took a real OP game from the factory (`gameAtIndex(19800)`,
   block 156,813,149) and rebuilt its root claim `0x0fa01c59…ff1a` exactly.
4. **Scan the window.** I walked backwards from the estimate and compared each output root to
   the challenge hash:

```python
# outroot.py
from Crypto.Hash import keccak as _k
def keccak(b): return _k.new(digest_bits=256, data=b).digest()
def output_root(h):
    data = bytes(32) + bytes.fromhex(h["stateRoot"][2:]) \
         + bytes.fromhex(h["withdrawalsRoot"][2:]) + bytes.fromhex(h["hash"][2:])
    return "0x" + keccak(data).hex()

# search.py: batch-fetch headers from `top` downward; stop when sha256(root) == target hash
```

Results:

| Chain | Safe head block | L2 timestamp | Lag behind l1Head | Output root |
|---|---|---|---|---|
| OP  | 155,749,670 | 1787098117 | 130 s | `0x192f1635…b5f1` |
| Ink | 53,599,386  | 1787097797 | 450 s | `0x82c94115…1b6f` |

**Checking this against Ethereum.** I listed the batch-data (blob) transactions just before
`l1Head`:

* OP's batcher (`0x6887…2985` → inbox `0xff00…0010`) posts every 12 L1 blocks. The last post at
  or before 25,785,478 is in block **25,785,468** (about 12:08:47 UTC). The OP safe head block is from 12:08:37.
* Ink's batcher (`0x6db6…6b98` → inbox `0x0059…be97`) last posted in block **25,785,442**
  (about 12:03:35 UTC). The Ink safe head block is from 12:03:17.

In both cases, the safe head is the last L2 block covered by the newest batch Ethereum had seen
by `l1Head`. That's exactly what "safe head at l1Head" means.

---

## 4. Final answers

```
ink_claim = 0x82c941153a9de14c4533b301799ee33206b6a475d7c4fdbe7cd2f1c9d7271b6f   # Ink block 53,599,386
op_claim  = 0x192f163548d61d555a282e1ffcec8ec7b1e4cf9deced7e910b87292f0aeab5f1   # OP block 155,749,670
```

---

## 5. Takeaways

* **The tree position decides which block you're talking about.** Attacking the root always
  lands halfway through the range, at `start + 2^(splitDepth-1)`.
* **Honest doesn't mean "the true state at block X".** It means "the newest state that the
  game's Ethereum data can back up." If you post an output for a block past the safe head, a
  counter-challenger can beat you even when your root is correct.
* **You need speed and the right data.** To be first, you need the game's `l1Head`, the rollup's
  safe head at that L1 block, and the block's header, all before the other bots. The math is easy;
  getting there first is the hard part.
