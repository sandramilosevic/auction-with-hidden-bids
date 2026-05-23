// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BlindAuction {

    event BidPlaced(address indexed bidder, uint deposit); // Emituje se pri slanju ponude
    event BidRevealed(address indexed bidder, uint value, bool isHighest); // Emituje se pri otkrivanju ponude
    event AuctionEnded(address indexed winner, uint amount, uint256 nftTokenId); // Emituje se po zavrsetku aukcije 
    event ReservePriceNotMet(uint highestBid, uint reservePrice); // Emituje se u slucaju kada rezervna cena nije dostignuta
    event FundsWithdrawn(address indexed bidder, uint amount); // Emituje se kada se povlaci ETH iz ugovora

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
        emit BidPlaced(msg.sender, msg.value); // obavestimo sve da je ponuda primljena
    }

    // otkrivanje ponude nakon isteka biding faze
    function reveal(uint amount, bytes32 secret) onlyAfter(biddingEnd) onlyBefore(revealEnd) public {
        Bid storage userBid = bids[msg.sender];

        require(userBid.deposit > 0, "Niste postavili ponudu!");
        require(userBid.blindedBid == keccak256(abi.encodePacked(amount, secret)), "Ponuda ne odgovara hashu");
        require(userBid.deposit >= amount, "Depozit nije dovoljan za navedenu ponudu!");

        if (amount > highestBid) {
            if (highestBidder != address(0)) {
                pendingReturns[highestBidder] += bids[highestBidder].deposit; // stari pobednik dobija povrat
                bids[highestBidder].deposit = 0;
            }
            uint excess = userBid.deposit - amount;
            if (excess > 0) {
                pendingReturns[msg.sender] += excess;
            }
            highestBidder = msg.sender;
            highestBid = amount;
        }
        else {
            // ako nije pobedio, dobija povrat depozita
            pendingReturns[msg.sender] += userBid.deposit;
        }
        userBid.deposit = 0; // resetujemo depozit za korisnika
        emit BidRevealed(msg.sender, amount, highestBidder == msg.sender);
    }

    // Gubitnici sami povlače ETH — bezbedniji od automatskog slanja
    function withdraw() public {
        require(pendingReturns[msg.sender] > 0, "Nema ponuda");

        uint amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Slanje ETH nije uspelo!");

        emit FundsWithdrawn(msg.sender, amount);
    }
    
    function endAuction() public onlyAfter(revealEnd) {
        require(!ended, "Aukcija je zavrsena");

        ended = true;

        if (highestBidder == address(0)) {
            emit AuctionEnded(address(0), 0, nftTokenId);
            return;
        }

        if (highestBid >= reservePrice) {
            require(
                nft.getApproved(nftTokenId) == address(this) ||
                nft.isApprovedForAll(beneficiary, address(this)),
                "Ugovor nema dozvolu za transfer NFT-a!"
            );
            (bool success, ) = payable(beneficiary).call{value: highestBid}("");
            require(success, "Neuspesno.");
            nft.transferFrom(beneficiary, highestBidder, nftTokenId);
        }
        else {
            pendingReturns[highestBidder] += highestBid;
            emit ReservePriceNotMet(highestBid, reservePrice);
        }
        emit AuctionEnded(highestBidder, highestBid, nftTokenId);  
    }
}