# Too Big To Fail - Tier 2

On 19 May 2021 the market fell about 30% in an afternoon. Lending protocols were liquidating
positions all day, and most of it was picked clean within seconds by bots. Gas prices reached thousands of gwei.

One position was not liquidated. On Liquity, one user was holding a $1B position, but even with the sharp drop, nothing happened, which led to the user being able to [rebalance](https://etherscan.io/tx/0x27964fe829e72020b66544df299f87ae6ee4202ff2394cdfe670d53754ca68fb) moments later. Was this too much for bots to process or did nobody notice?

Can you try to process this liquidation at block 12465029 and end with more than 2,500 ETH?

Run the test case with:

```
python alpha.py check 03
```
