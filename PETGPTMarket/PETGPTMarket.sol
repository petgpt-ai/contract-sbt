// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Ownable.sol";
import "./Proxy.sol";

interface PETGPTNFT {
    function totalSupply() external view returns (uint);

    function ownerOf(uint tokenId) external view returns (address);

    function safeTransferFrom(address from, address to, uint tokenId) external payable;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function royaltyInfo(uint _tokenId, uint _salePrice) external view returns (address, uint);
}

contract PETGPTMarket is Ownable, Proxy {
    address public implementation; // 逻辑合约地址
    event Upgraded(address indexed implementation);
    // 构造函数，初始化admin和逻辑合约地址
    constructor(address i){
        implementation = i;
    }
    function _implementation() internal view virtual override returns (address) {
        return implementation;
    }

    receive() external payable {}

    struct Offer {
        address seller;
        uint price;
    }

    mapping(address => mapping(uint => Offer)) public tokenOfferedForSale;

    struct Bid {
        address bidder;
        uint price;
    }

    mapping(address => mapping(uint => Bid)) public tokenBids;

    struct OfferBid {
        uint tokenId;
        address owner;
        address seller;
        uint offerPrice;
        address bidder;
        uint bidPrice;
    }

    mapping(address => bool) public petgptNFTAddressAccept;
    mapping(address => bool) public isRoyalty;

    event PayableToReceiver(address petgptNFTAddress, address receiver, uint amount);
    event TransactionToken(address petgptNFTAddress, address from, address to, uint tokenId, uint price, bool isBid);
    event OfferTokenForSale(address petgptNFTAddress, uint tokenId, address offer, uint price);
    event EnterBidForToken(address petgptNFTAddress, uint tokenId, address bidder, uint price);
    event SetAccept(address petgptNFTAddress, bool accept);
    event SetIsRoyalty(address petgptNFTAddress, bool isRoyalty);

    function getOfferBid(address petgptNFTAddress, uint tokenId) public view returns (OfferBid memory offerBid)  {
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        offerBid = OfferBid(tokenId, PETGPTNFT(petgptNFTAddress).ownerOf(tokenId), offer.seller, offer.price, bid.bidder, bid.price);
        return offerBid;
    }

    function getOfferBids(address petgptNFTAddress, uint start, uint end) public view returns (OfferBid[] memory)  {
        require(start != 0 && end != 0 && end >= start);
        uint end1 = end + 1;
        OfferBid[] memory offerBids = new OfferBid[](end1 - start);
        uint index;
        for (uint tokenId = start; tokenId < end1; tokenId++) {
            Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
            Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
            offerBids[index++] = OfferBid(tokenId, PETGPTNFT(petgptNFTAddress).ownerOf(tokenId), offer.seller, offer.price, bid.bidder, bid.price);
        }
        return offerBids;
    }

    function getOwnerOf(address petgptNFTAddress, uint start, uint end) public view returns (address[] memory)  {
        require(start != 0 && end != 0 && end >= start);
        uint end1 = end + 1;
        address[] memory owners = new address[](end1 - start);
        uint index;
        for (uint tokenId = start; tokenId < end1; tokenId++) {
            owners[index++] = PETGPTNFT(petgptNFTAddress).ownerOf(tokenId);
        }
        return owners;
    }
}