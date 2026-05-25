// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Aukcija {
    // struktura za cuvanje ponude
    // keccak256 hash vrednosti i tajnog kljuca
    // deposit je u ETH
    struct Bid {
        bytes32 blindedBid; 
        uint deposit;
    }

    address payable public beneficiary; // vlasnik NFT-a

    uint public biddingEnd; // timestamp - zatvaranje licitacije
    uint public revealEnd; 
    bool public ended; // zastita od dvostrukog zavrsavanja aukcije

    uint public reservePrice; // rezervna cena

    IERC721 public nft; // referenca na NFT ugovor
    uint256 public nftTokenId; // ID konkretnog NFT-a

    mapping(address => Bid[]) public bids; // cuva ponudu za svaku adresu
    mapping(address => uint) public pendingReturns; // koliko ETH povlaci nakon aukcije (pull pattern)

    address public highestBidder; // trenutna najveca ponuda
    uint public highestBid;

    // Uslovi
    modifier onlyBefore(uint time) {
        require(block.timestamp < time, "Kasno je!"); // trenutno vreme pre zadatog timestampa
        _;
    }

    modifier onlyAfter(uint time) {
        require(block.timestamp > time, "Prerano je!"); // trenutno vreme posle zadatog timestampa
        _;
    }

    constructor(
        uint biddingDuration, // trajanje u sekundama
        uint revealDuration,
        uint _reservePrice, // minimalna prihvatljiva cena
        address _nftContract, // adresa NFT ugovora
        uint256 _nftTokenId
    ) {
        beneficiary = payable(msg.sender); // vlasnik NFT-a, koji je objavio aukciju

        biddingEnd = block.timestamp + biddingDuration;
        revealEnd = biddingEnd + revealDuration; 

        reservePrice = _reservePrice; 

        nft = IERC721(_nftContract); 
        nftTokenId = _nftTokenId;

        require(nft.ownerOf(_nftTokenId) == msg.sender, "Niste vlasnik NFT-a");
        // Preduslov: vlasnik mora pozvati approve(address(this), _nftTokenId) na NFT ugovoru pre deployovanja
        nft.transferFrom(msg.sender, address(this), _nftTokenId);
    }
    
    // hash(vrednost + tajniKljuc) — prava cifra ostaje skrivena
    function bid(bytes32 bidHash) onlyBefore(biddingEnd) public payable {
        require(msg.value > 0, "Depozit mora biti veci od 0!");
        require(bidHash != bytes32(0), "Hash ne sme biti prazan");
        require(msg.sender != beneficiary, "Vlasnik ne moze licitirati!"); // vlasnik ne moze postaviti ponudu

        // cuvanje ponude u mapping
        bids[msg.sender].push(Bid({
            deposit: msg.value,
            blindedBid: bidHash
        })); 
    }

    // otkrivanje ponude nakon isteka biding faze
    function reveal(
        uint[] calldata values,
        bytes32[] calldata secrets
    ) onlyAfter(biddingEnd) onlyBefore(revealEnd) public {
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(secrets.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            Bid storage userBid = bids[msg.sender][i];
            (uint value, bytes32 secret) = (values[i], secrets[i]);

            if (userBid.blindedBid != keccak256(abi.encode(value, secret, msg.sender))) {
                continue;
            }

            refund += userBid.deposit;
            if (userBid.deposit >= value) {
                if (_updateHighestBid(msg.sender, value))
                    refund -= value;
            }
            userBid.blindedBid = bytes32(0); // stanje se menja pre slanja ETH-a (CEI pattern)
        }

        (bool success, ) = payable(msg.sender).call{value: refund}("");
        require(success, "Slanje ETH nije uspelo!");
    }

    function _updateHighestBid (address bidder, uint value) internal returns (bool) {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid; // novi pobednik
        }
        highestBid = value; // nova najveca ponuda
        highestBidder = bidder;
        return true;
    }

    // Gubitnici sami povlače ETH, bezbedniji od automatskog slanja
    function withdraw() public {
        require(pendingReturns[msg.sender] > 0, "Nema ponuda");

        uint amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Slanje ETH nije uspelo!");
    }
        
    function endAuction() public onlyAfter(revealEnd) {
        require(!ended, "Aukcija je zavrsena");
        ended = true;
        if (highestBidder == address(0)) {
            nft.transferFrom(address(this), beneficiary, nftTokenId); // niko nije licitirao, NFT se vraca vlasniku
            return;
        }
        
        if (highestBid >= reservePrice) {
            (bool success, ) = payable(beneficiary).call{value: highestBid}(""); // beneficiary dobija ETH
            require(success, "Neuspesno.");
            nft.transferFrom(address(this), highestBidder, nftTokenId); // pobednik dobija NFT
        }
        else {
            pendingReturns[highestBidder] += highestBid; // pobedniku se vraca depozit jer rezervna cena nije dostignuta
            nft.transferFrom(address(this), beneficiary, nftTokenId); // rezervna cena nije dostignuta, NFT se vraca vlasniku
        }
    }
}
