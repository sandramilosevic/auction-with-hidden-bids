// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BlindAuction {

    event BidPlaced(address indexed bidder, uint deposit); // Emituje se pri slanju ponude
    event BidRevealed(address indexed bidder, uint value, bool isHighest); // Emituje se pri otkrivanju ponude
    event AuctionEnded(address indexed winner, uint amount, uint256 nftTokenId); // Emituje se po zavrsetku aukcije 
    event ReservePriceNotMet(uint highestBid, uint reservePrice); // Emituje se u slucaju kada rezervna cena nije dostignuta
    event FundsWithdrawn(address indexed bidder, uint amount); // Emituje se kada se povlaci ETH iz ugovora

    struct Bid {
        bytes32 blindedBid; // keccak256(vrednost, tajniKljuc)
        uint deposit;
    }

    address payable public beneficiary;

    uint public biddingEnd; 
    uint public revealEnd;
    bool public ended; // zastita od dvostrukog zavrsavanja aukcije

    uint public reservePrice; // rezervna cena

    IERC721 public nft; // referenca na NFT ugovor
    uint256 public nftTokenId;

    mapping(address => Bid) public bids; // cuva ponudu za svaku adresu
    mapping(address => uint) public pendingReturns; // koliko ETH povlaci nakon aukcije (pull pattern)

    address public highestBidder; // trenutna najveca ponuda
    uint public highestBid;

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
        uint _reservePrice,
        address _nftContract,
        uint256 _nftTokenId
    ) {
        beneficiary = payable(msg.sender); // vlasnik NFT-a, koji je objavio aukciju

        biddingEnd = block.timestamp + biddingDuration;
        revealEnd = biddingEnd + revealDuration; 

        reservePrice = _reservePrice; 

        nft = IERC721(_nftContract); 
        nftTokenId = _nftTokenId;
    }

    function bid(bytes32 bidHash) onlyBefore(biddingEnd) public payable {
        require(msg.value > 0, "Depozit mora biti veci od 0!");
        require(bidHash != bytes32(0), "Hash ne sme biti prazan");
        require(bids[msg.sender].deposit == 0, "Vec ste postavili ponudu!"); // provera da li je korisnik vec postavio ponudu
    
        // cuvanje ponude u mapping
        bids[msg.sender] = Bid({
        deposit: msg.value,
        blindedBid: bidHash
        });
        emit BidPlaced(msg.sender, msg.value); // obavestimo sve da je ponuda primljena
    
    }
    }
