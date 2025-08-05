# Review Log

## 2025.07.31 Alessandro De Carli

### acu.sol

line 148: we are limited to about 4B bridge operations. Which sounds like not a problem, but if this really takes off it could become a problem. Also because it could be attacked. Possible solution is to either have more bytes for the nonce or introduce a sender id and tehn have as nonce key the sender|nonce combination -> you can only attack yourself.

line 194 - 200: keccak256 is quite expensive for deriving a nonce, especially if the source is basically a single uint32. Just cast the thing...

Open question: deduplication of messages

### acu-erc20.sol


