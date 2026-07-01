# Blind NFT Auction System

A Solidity smart contract project that implements a sealed-bid auction for an NFT using a commit-reveal mechanism.

## Overview

This project contains two smart contracts:

- `Aukcija` — a blind auction contract for selling an NFT.
- `UgovorNFT` — an ERC721 NFT contract used for minting the auctioned token.

The auction follows a two-phase flow:
1. Bidding phase, where bidders submit blinded bids.
2. Reveal phase, where bidders reveal their actual bids and secrets.

At the end of the auction, the NFT is transferred to the highest bidder if the reserve price is met. Otherwise, the NFT is returned to the seller.

## Features

- Blind bidding with keccak256 hash commitments.
- Commit-reveal auction design.
- Reserve price support.
- Pull-payment pattern for refunds.
- Secure NFT transfer using ERC721.
- Protection against double auction ending.
- Separation of bidding, reveal, and settlement phases.

## Contracts

### Aukcija

Main auction contract that handles:
- NFT deposit by the seller.
- Bid submission with hashed commitments.
- Bid reveal and validation.
- Tracking the highest bid.
- Refunds for losing bidders.
- Final auction settlement.

### UgovorNFT

Simple ERC721 NFT contract used to mint auction assets.

## How It Works

### 1. Mint NFT
The NFT is minted using the `UgovorNFT` contract.

### 2. Deposit NFT
The seller transfers the NFT to the auction contract using `depositNFT()`.

### 3. Submit Blinded Bids
Bidders call `bid()` with a hash of:
- bid value,
- secret phrase,
- bidder address.

### 4. Reveal Bids
After bidding ends, bidders call `reveal()` with:
- the actual bid values,
- the corresponding secrets.

### 5. Withdraw Refunds
Unsuccessful bidders can withdraw their refundable ETH using `withdraw()`.

### 6. End Auction
After the reveal period ends, anyone can call `endAuction()` to finalize the auction.

## Security Patterns Used

- **Commit-reveal scheme** to prevent bid copying.
- **Pull over push** for ETH refunds.
- **Checks-Effects-Interactions** pattern to reduce reentrancy risk.
- Auction can only be ended once.

## Example Hash Generation

The following script generates the hash used for `bid()` and the values used for `reveal()`:

```javascript
async function main() {
    const stvarnaPonudauEth = "1"; 
    const mojaTajnaRec = "tajna1"; 
    const adresaNovcanika = "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"; 

    const value = ethers.utils.parseEther(stvarnaPonudauEth); 
    const hexString = ethers.utils.hexlify(ethers.utils.toUtf8Bytes(mojaTajnaRec));
    const secret = hexString.padEnd(66, "0"); 

    const encodedData = ethers.utils.defaultAbiCoder.encode(
        ["uint256", "bytes32", "address"],
        [value, secret, adresaNovcanika]
    );

    const hash = ethers.utils.keccak256(encodedData);

    console.log("bidHash:", hash);
    console.log("values:", `[${value.toString()}]`);
    console.log("secrets:", `["${secret}"]`);
}

main();
```

## Technologies Used

- Solidity
- OpenZeppelin Contracts
- ERC721
- Hardhat or Remix
- JavaScript
- ethers.js

## Project Structure

```text
├── contracts/
│   ├── Aukcija.sol
│   └── UgovorNFT.sol
│   └── generateHash.js
├── README.md
└── remix.config.js
```

## Notes

- The seller cannot participate in bidding.
- The NFT must be deposited before the auction starts.
- Reveal data must match the original blinded bid exactly.
- If the reserve price is not met, the NFT is returned to the seller.


<img width="545" height="876" alt="image" src="https://github.com/user-attachments/assets/39a1f5b1-3f29-4971-a2d8-2783c14faf74" />
<img width="542" height="875" alt="image" src="https://github.com/user-attachments/assets/89fec7d5-a0bc-4f5e-ad37-d9149e355427" />
<img width="412" height="518" alt="06 funkcija bid u okviru koje unosimo hahs" src="https://github.com/user-attachments/assets/50126fca-74e2-40b1-a8eb-c906600443d1" />
<img width="426" height="530" alt="07 reveal" src="https://github.com/user-attachments/assets/0bee1449-9da3-47fc-9773-b107f6d287fb" />
<img width="453" height="533" alt="08 endAuction" src="https://github.com/user-attachments/assets/9c09da42-1356-4674-a510-a5964fccb9ea" />
<img width="466" height="632" alt="10 NFT se prebaca na acount 2" src="https://github.com/user-attachments/assets/26274b9d-354b-47b4-bd99-00954c452852" />
<img width="453" height="107" alt="11 vlasniku je prosledjen eth" src="https://github.com/user-attachments/assets/ac873dea-62e0-475f-acef-06daedf35d2f" />

## License

MIT
