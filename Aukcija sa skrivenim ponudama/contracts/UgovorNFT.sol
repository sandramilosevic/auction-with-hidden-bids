// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // biblioteka za generisanje NFT tokena

contract UgovorNFT is ERC721URIStorage {
    uint256 public tokenCounter; // brojac za generisane tokene - id

    constructor() ERC721('AuctionNFT', 'ANFT') {
        tokenCounter = 0; // pocetna vrednost brojaca
    }

    function mint(address owner, string memory tokenURI) public returns (uint256) {
        uint256 id = tokenCounter;
        tokenCounter++;
        _mint(owner, id); // kreiranje tokena
        _setTokenURI(id, tokenURI); // postavljanje URI-a tokena
        return id;
    }
}