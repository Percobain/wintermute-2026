# Cold Start - Tier 3

A new L2 has just gone live: Robinhood Chain, an Arbitrum-style rollup settling
to Ethereum. There is a very early token on it you want, CASHCAT. Your friend already sent you the CA which you have in [`Constants.sol`](./Constants.sol). Issue is, the chain only just
started: no public RPC, no bridge front-end, no explorer (well, none that you can find). You cannot
send it a transaction directly. The one thing you can reach is the
chain's Delayed Inbox.

Can you make your user address hold at least 1,000,000 CASHCAT on the L2?

`setUp()` and `checkSolve()` are the specification.

## Setup

This challenge forks two chains, so it needs a second archive RPC. Add it to
`.env`:

```
ROBINHOOD_RPC_URL=...
```

Then:

```
python alpha.py check 05
```
