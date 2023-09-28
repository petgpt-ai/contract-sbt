// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./PETGPTMarket.sol";

contract PETGPTMarketLogic is PETGPTMarket(address(this)) {

    function upgrade(address newImplementation) external onlyOwner {
        require(newImplementation.code.length != 0, "The `implementation` of the beacon is invalid");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    modifier checkAccept(address petgptNFTAddress){
        require(petgptNFTAddressAccept[petgptNFTAddress], 'This address is not allowed to use this contract');
        _;
    }

    modifier checkOwnerOfAndApproved(address petgptNFTAddress, address seller, uint tokenId){
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        require(petgptNFT.ownerOf(tokenId) == seller, 'The token owner is not the seller');
        require(petgptNFT.isApprovedForAll(seller, address(this)), 'Not yet approved');
        _;
    }

    function setAccept(address petgptNFTAddress, bool accept) public onlyOwner {
        petgptNFTAddressAccept[petgptNFTAddress] = accept;
        emit SetAccept(petgptNFTAddress, accept);
    }

    function setIsRoyalty(address petgptNFTAddress, bool isRoyalty_) public onlyOwner checkAccept(petgptNFTAddress) {
        isRoyalty[petgptNFTAddress] = isRoyalty_;
        emit SetIsRoyalty(petgptNFTAddress, isRoyalty_);
    }

    function transferToken(address petgptNFTAddress, uint tokenId, uint price, address to, bool isBid) private checkAccept(petgptNFTAddress) {
        require(to != address(0), 'Cannot transfer to the zero address');
        uint royaltyAmount;
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        if (isRoyalty[petgptNFTAddress]) {
            address receiver;
            (receiver, royaltyAmount) = petgptNFT.royaltyInfo(tokenId, price);
            if (royaltyAmount > 0) {
                payable(receiver).transfer(royaltyAmount);
                emit PayableToReceiver(petgptNFTAddress, receiver, royaltyAmount);
            }
        }
        address ownerOfToken = petgptNFT.ownerOf(tokenId);
        uint ownerOfTokenAmount = price - royaltyAmount;
        if (ownerOfTokenAmount > 0)
            payable(ownerOfToken).transfer(ownerOfTokenAmount);
        petgptNFT.safeTransferFrom(ownerOfToken, to, tokenId);
        emit TransactionToken(petgptNFTAddress, ownerOfToken, to, tokenId, price, isBid);
        if (tokenOfferedForSale[petgptNFTAddress][tokenId].price > 0)
            tokenOfferedForSale[petgptNFTAddress][tokenId] = Offer(address(0), 0);
    }

    function offerTokenForSale(address petgptNFTAddress, uint tokenId, uint price) public checkAccept(petgptNFTAddress) checkOwnerOfAndApproved(petgptNFTAddress, msg.sender, tokenId) {
        address seller = msg.sender;
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        uint bidPrice = bid.price;
        bool priceEQ0 = price == 0;
        require(priceEQ0 || bidPrice == 0 || price > bidPrice, 'Same or higher bid already available, can choose to accept');
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        require(priceEQ0 || seller != offer.seller || price != offer.price, 'Cannot set the same price');
        tokenOfferedForSale[petgptNFTAddress][tokenId] = Offer(seller, price);
        emit OfferTokenForSale(petgptNFTAddress, tokenId, seller, price);
    }

    function buyToken(address petgptNFTAddress, uint tokenId) payable public checkAccept(petgptNFTAddress) checkOwnerOfAndApproved(petgptNFTAddress, tokenOfferedForSale[petgptNFTAddress][tokenId].seller, tokenId) {
        address buyer = msg.sender;
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        require(buyer != offer.seller, 'You can not buy your own token');
        uint price = offer.price;
        require(price > 0, 'This token is not on sale');
        uint value = msg.value;
        require(value >= price, 'Insufficient payment amount');
        if (value > price)
            payable(buyer).transfer(value - price);
        transferToken(petgptNFTAddress, tokenId, price, buyer, false);
    }

    function enterBidForToken(address petgptNFTAddress, uint tokenId) payable public checkAccept(petgptNFTAddress) {
        address bidder = msg.sender;
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        address currentBidder = bid.bidder;
        uint price = msg.value;
        uint currentPrice = bid.price;
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        address ownerOfTokenId = petgptNFT.ownerOf(tokenId);
        require(bidder != ownerOfTokenId, 'You can not buy your own token');
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        uint tokenOfferedForSalePrice = offer.price;
        require(ownerOfTokenId != offer.seller || tokenOfferedForSalePrice == 0 || price < tokenOfferedForSalePrice, 'Same or lower price already available, can choose to buy');
        require(bidder == currentBidder || price > currentPrice, 'Same or higher bid already available');
        require(bidder != currentBidder || price != currentPrice, 'Cannot set the same bid');
        tokenBids[petgptNFTAddress][tokenId] = Bid(bidder, price);
        emit EnterBidForToken(petgptNFTAddress, tokenId, bidder, price);
        if (currentBidder != address(0) && currentPrice > 0)
            payable(currentBidder).transfer(currentPrice);
    }

    function acceptBidForToken(address petgptNFTAddress, uint tokenId, uint minPrice) public checkAccept(petgptNFTAddress) checkOwnerOfAndApproved(petgptNFTAddress, msg.sender, tokenId) {
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        uint price = bid.price;
        require(price > 0, 'This token has not be bid');
        require(price >= minPrice, 'This current bid is lower than the minimum expectation price');
        transferToken(petgptNFTAddress, tokenId, price, bid.bidder, true);
        if (tokenBids[petgptNFTAddress][tokenId].price > 0)
            tokenBids[petgptNFTAddress][tokenId] = Bid(address(0), 0);
    }
}