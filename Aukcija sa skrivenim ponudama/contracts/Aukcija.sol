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

    mapping(address => Bid) public bids; // cuva ponudu za svaku adresu
    mapping(address => uint) public pendingReturns; // koliko ETH povlaci nakon aukcije (pull pattern)

    address public highestBidder; // trenutna najveca ponuda
    uint public highestBid;

    // Uslovi
    modifier onlyBefore(uint time) {
        require(block.timestamp < time, "Kasno je!"); // trenutno vreme posle zadatog timestampa
        _;
    }

    modifier onlyAfter(uint time) {
        require(block.timestamp > time, "Prerano je!"); // trenutno vreme pre zadatog timestampa
        _;
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Nisi vlasnik aukcije!");
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
    }

    // hash(vrednost + tajniKljuc) — prava cifra ostaje skrivena
    function bid(bytes32 bidHash) onlyBefore(biddingEnd) public payable {
        require(msg.value > 0, "Depozit mora biti veci od 0!");
        require(bidHash != bytes32(0), "Hash ne sme biti prazan");
        require(bids[msg.sender].deposit == 0, "Vec ste postavili ponudu!"); // provera da li je korisnik vec postavio ponudu
        require(msg.sender != beneficiary, "Vlasnik ne moze licitirati!"); // vlasnik ne moze postaviti ponudu

        // cuvanje ponude u mapping
        bids[msg.sender] = Bid({
            deposit: msg.value,
            blindedBid: bidHash
        });
    }

    // otkrivanje ponude nakon isteka biding faze
    function reveal(bytes32 secret) onlyAfter(biddingEnd) onlyBefore(revealEnd) public {
        Bid storage userBid = bids[msg.sender];

        require(userBid.deposit > 0, "Niste postavili ponudu!");
        require(userBid.blindedBid == keccak256(abi.encode(userBid.deposit, secret)), "Ponuda ne odgovara hashu!");

        uint amount = userBid.deposit;
        userBid.deposit = 0;

        if (amount > highestBid) {
            if (highestBidder != address(0)) {
                pendingReturns[highestBidder] += highestBid;
            }

            highestBidder = msg.sender; // novi pobednik
            highestBid = amount; // nova najveca ponuda
        } 
            else {
                pendingReturns[msg.sender] += amount; // ako nije pobedio, dobija povrat depozita
        }
    }
    // Gubitnici sami povlače ETH, bezbedniji od automatskog slanja
    function withdraw() public {
        require(pendingReturns[msg.sender] > 0, "Nema ponuda");

        uint amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Slanje ETH nije uspelo!");
    }
        
    function endAuction() public onlyAfter(revealEnd) onlyBeneficiary {
            require(!ended, "Aukcija je zavrsena");
            ended = true;
            if (highestBidder == address(0)) {
                return;
            }
            
            if (highestBid >= reservePrice) {
                require(
                    nft.getApproved(nftTokenId) == address(this) ||
                    nft.isApprovedForAll(beneficiary, address(this)),
                    "Ugovor nema dozvolu za transfer NFT-a!"
                );
                (bool success, ) = payable(beneficiary).call{value: highestBid}(""); // beneficiary dobija ETH
                require(success, "Neuspesno.");
                nft.transferFrom(beneficiary, highestBidder, nftTokenId); // pobednik dobija NFT
            }
            else {
                pendingReturns[highestBidder] += highestBid; // pobedniku se vraca depozit jer rezervna cena nije dostignuta
            }
    }
}