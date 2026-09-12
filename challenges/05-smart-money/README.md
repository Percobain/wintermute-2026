# Smart Money - Tier 2

VCs move onchain like everyone else. That's why you often like looking at high value transactions flowing into fresh multisigs, token vestings, etc. You never know, maybe you find alpha.

One day you stumble upon `0xAf0970A06BD17AD57f63d633be7f7039EB69Dc95`, which looks like an address used in a fundraise, given inflows. While checking out the investors in the raise, you find `0xC29Af06142138F893e3f1C1D11Aa98C3313B8C1f`, an address used for a long time by some VC.

Can you identify the name of the protocol that the fundraise was for, and the name of this unknown investor?

You also remember that you saw a fresh address (`0xe53ec250fDF41e52d22fEF1f76DeE92A9377AC8f`) get $20M from various sources, but you never went deep into it. While looking for clues on the identity of this fundraise, you see inflows from `0x4c2c0F0bB2631B02aC9299C59690914ee7A200B8`, an address with billions in volume. Can you identify both the protocol that was funded, and the company behind this huge address?

Write your four answers into `answer.txt`, one per line:

```
protocol_one = ...   # protocol the first fundraise (0xAf09...Dc95) was for
investor_one = ...   # the VC behind 0xC29A...8C1f
protocol_two = ...   # protocol behind 0xe53e...AC8f
company = ...        # the company behind 0x4c2c...00B8
```

Then:

```
python alpha.py check 08
```

Answers are case-insensitive. Three of the answers are two words.
