# First Move - Tier 3

Two fault dispute games are created on Ethereum, one for Optimism and one for Ink. Each game has the same root claim:

~~~text
0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
~~~

This might seem unusual, given it's an invalid claim (right?!), but is actually [a frequent sight](https://disputes.slopo.net/). Being first to dispute this might make us some money...

For each game, find the valid `bytes32 _claim` value for the first root attack:

~~~solidity
attack(rootClaim, 0, claim)
~~~

Both hypothetical creation transactions are included in Ethereum L1 block `25785479`.

## Ink Game

Creation transaction:

~~~text
blockNumber: 25785479
blockHash:   0x0e1fae20aea76b89f7d8e773ac860a8e37806219f0bd7108213437006acd0ab3
from:        0x0976D8e6f4c6D7e4Be101988C680BA7736B6E294
to:          0x10d7B35078d3baabB96Dd45a9143B94be65b12CD
gameType:    8
rootClaim:   0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
extraData:   0x000000000000000000000000000000000000000000000000000000006a84f493
~~~

Game contract reads immediately after creation:

~~~text
l1Head():              0xd74f339891bc1c4af93bf4bb55c03fc3feb62da272a1f7aa3eabb9e2410126f4
l2BlockNumber():       1787098259
startingBlockNumber(): 52959235
splitDepth():          30
~~~

## Optimism Game

Creation transaction:

~~~text
blockNumber: 25785479
blockHash:   0x0e1fae20aea76b89f7d8e773ac860a8e37806219f0bd7108213437006acd0ab3
from:        0xaA08d45476DA6831E03b707DbD4d473e1a0f9288
to:          0xe5965Ab5962eDc7477C8520243A95517CD252fA9
gameType:    8
rootClaim:   0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
extraData:   0x000000000000000000000000000000000000000000000000000000006a84f493
~~~

Game contract reads immediately after creation:

~~~text
l1Head():              0xd74f339891bc1c4af93bf4bb55c03fc3feb62da272a1f7aa3eabb9e2410126f4
l2BlockNumber():       1787098259
startingBlockNumber(): 155446493
splitDepth():          30
~~~

[remember that these transactions are not real]

Write your correct counterclaim answers into `answer.txt`:

~~~text
ink_claim = 0x...
op_claim = 0x...
~~~

Each answer is a `bytes32` value. The checker reads them like 32-byte hex strings; it is not asking for transaction hashes.
