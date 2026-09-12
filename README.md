# Wintermute Alpha Challenge 2026

An educational edition of the [Alpha Challenge](https://alpha.wintermute.com). Every challenge
in this repository is based on something that actually happened onchain, and every one of them
checks itself. There is no server, no registration and no deadline. Clone it and work through it.

There are two kinds of challenges.

**Analysis challenges** ask you to find something: an address, a transaction, a name.
You write the answer into `answer.txt` and the runner hashes it and compares it against the hash of the answer.

**Code challenges** ask you to make something happen. They fork Ethereum (or other chains) at the block where the
interesting thing occurred, hand you an address, and check the end state with `forge test`.

## Setup

You need Python 3.8 or newer for the analysis challenges. Check with `python3 --version`.

For the code challenges you also need [Foundry](https://book.getfoundry.sh/getting-started/installation)
and an **archive** RPC endpoint as the fork tests read state from
blocks that are months or years old.

```
git clone <this repo> && cd Alpha-Challenge-2026
forge install foundry-rs/forge-std
cp .env.example .env        # then fill in RPC URLs
python alpha.py list
```

The runner is a plain Python script. Run it with `python alpha.py <command>`
(or `python3 alpha.py` on macOS/Linux).

## Solving

```
python alpha.py list                 every challenge, in the order we suggest solving them
python alpha.py check 03             score one challenge
python alpha.py check                score everything
```

For an analysis challenge, open the challenge folder, read `README.md`, and fill in `answer.txt`:

```
input_tx = 0x1234...
```

Capitalisation, surrounding whitespace and a missing `0x` prefix are all handled for you. When an
answer is rejected the runner prints the exact string it hashed, so you can tell a formatting
mistake apart from a wrong answer:

```
  bridge             correct
  input_tx           wrong (read as: 0xdeadbeef...)
```

For a code challenge, write your solution into `test_Solution()` in that challenge's
`Solution.t.sol`. `checkSolve()` shows you exactly what end state is required, and it runs
automatically. Do not edit `checkSolve()` or `setUp()`.

## Scoring

Tier 1, 2 and 3 challenges are worth 75, 100 and 150 points respectively. Analysis challenges with
several parts award points per part, so a partial answer still scores. `python alpha.py check` prints your
running total.

Nothing is recorded anywhere. The score is for you.

## A note on the honour system

The answers are stored as plain SHA-256 hashes. That hides them from anyone casually reading the
repository, and nothing more. A short answer like a protocol name can be recovered from a wordlist
in seconds by anyone who wants to.

We are not trying to stop you. There is no prize and no leaderboard here, so the only person
affected is you.

## Rules

There are none worth enforcing. If you write up your solutions publicly, you can post about them and share with us and we will link back to them here.