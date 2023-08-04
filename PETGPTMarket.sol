// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface PETGPTNFT {
    //token拥有者
    function ownerOf(uint tokenId) external view returns (address);
    //token转移，安全转移(如果接收方是合约地址，会要求其实现 ERC721Receiver 接口)
    function safeTransferFrom(address from, address to, uint tokenId) external payable;
    //判断是否已经全部授权给当前合约
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    //通过token售价获取版税价格
    function royaltyInfo(uint _tokenId, uint _salePrice) external view returns (address, uint);
}

contract PETGPTMarket {
    //检查token拥有者和授权
    modifier checkOwnerOfTokenIdApproved(address petgptNFTAddress, address seller, uint tokenId){
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        //token拥有者不是出售者
        require(petgptNFT.ownerOf(tokenId) == seller, 'The token owner is not the seller');
        //token拥有者未授权给此合约
        require(petgptNFT.isApprovedForAll(seller, address(this)), 'The owner of this token is not authorized to this contract');
        _;
    }

    //token对应的售价，大于0就是出售中
    struct Offer {
        //出售者
        address seller;
        //售价
        uint price;
        //tokenId，用于查询
        uint tokenId;
    }
    //合约地址对应的售价mapping
    mapping(address => mapping(uint => Offer)) public tokenOfferedForSale;

    //token对应的报价，大于0就是报价中
    struct Bid {
        //报价者
        address bidder;
        //出售者
        address seller;
        //报价
        uint price;
        //tokenId，用于查询
        uint tokenId;
    }
    //合约地址对应的报价mapping
    mapping(address => mapping(uint => Bid)) public tokenBids;

    //遍历获取出售信息，size最多488
    function getTokenOfferedForSale(address petgptNFTAddress, uint page, uint size) public view returns (Offer[] memory)  {
        Offer[] memory offers = new Offer[](size);
        uint index;
        for (uint i = (page - 1) * size; i < page * size; i++) {
            uint tokenId = i + 1;
            Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
            offers[index++] = Offer(offer.seller, offer.price, tokenId);
        }
        return offers;
    }
    //遍历获取报价信息，size最多351
    function getTokenBids(address petgptNFTAddress, uint page, uint size) public view returns (Bid[] memory)  {
        Bid[] memory bids = new Bid[](size);
        uint index;
        for (uint i = (page - 1) * size; i < page * size; i++) {
            uint tokenId = i + 1;
            Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
            bids[index++] = Bid(bid.bidder, bid.seller, bid.price, tokenId);
        }
        return bids;
    }

    //交版税、转账、转移token
    event PayableToReceiver(address receiver, uint amount);
    event TransactionToken(address from, address to, uint tokenId, uint price, bool isBid);

    function transferToken(address petgptNFTAddress, uint tokenId, uint price, address to, bool isBid) private {
        //空地址，无法转移到零地址
        require(to != address(0), 'Cannot transfer to the zero address');
        address receiver;
        uint royaltyAmount;
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        //获取版税接收者和版税费用
        (receiver, royaltyAmount) = petgptNFT.royaltyInfo(tokenId, price);
        //交版税
        if (royaltyAmount > 0) {
            payable(receiver).transfer(royaltyAmount);
            emit PayableToReceiver(receiver, royaltyAmount);
        }
        //向token拥有者转账
        address ownerOfToken = petgptNFT.ownerOf(tokenId);
        uint ownerOfTokenAmount = price - royaltyAmount;
        if (ownerOfTokenAmount > 0)
            payable(ownerOfToken).transfer(ownerOfTokenAmount);
        //转移token
        petgptNFT.safeTransferFrom(ownerOfToken, to, tokenId);
        emit TransactionToken(ownerOfToken, to, tokenId, price, isBid);
        //下架
        if (tokenOfferedForSale[petgptNFTAddress][tokenId].price > 0)
            tokenOfferedForSale[petgptNFTAddress][tokenId] = Offer(address(0), 0, tokenId);
        if (tokenBids[petgptNFTAddress][tokenId].price > 0)
            tokenBids[petgptNFTAddress][tokenId] = Bid(address(0), address(0), 0, tokenId);
    }

    //出售，设置token价格
    event OfferTokenForSale(uint tokenId, address offer, uint price);

    function offerTokenForSale(address petgptNFTAddress, uint tokenId, uint price) public checkOwnerOfTokenIdApproved(petgptNFTAddress, msg.sender, tokenId) {
        address seller = msg.sender;
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        uint bidPrice = bid.price;
        //如果token拥有者依然是当前报价的出售者，且当前报价不为0，且售价低于等于当前报价，报错：已有相同或更高报价，可选择接受报价
        require(seller != bid.seller || bidPrice == 0 || price > bidPrice, 'Same or higher bid already available, can choose to accept');
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        //不能设置相同的价格
        require(seller != offer.seller || price != offer.price, 'Cannot set the same price');
        tokenOfferedForSale[petgptNFTAddress][tokenId] = Offer(seller, price, tokenId);
        emit OfferTokenForSale(tokenId, seller, price);
    }
    //购买出售中的token
    function buyToken(address petgptNFTAddress, uint tokenId) payable public checkOwnerOfTokenIdApproved(petgptNFTAddress, tokenOfferedForSale[petgptNFTAddress][tokenId].seller, tokenId) {
        address buyer = msg.sender;
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        //你不能购买自己的token
        require(buyer != offer.seller, 'You can not buy your own token');
        uint price = offer.price;
        //token未出售
        require(price > 0, 'This token is not on sale');
        uint value = msg.value;
        //低于当前价格
        require(value >= price, 'Insufficient payment amount');
        //多余退款
        if (value > price)
            payable(buyer).transfer(value - price);
        //向当前报价者退款
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        address currentBidder = bid.bidder;
        uint currentPrice = bid.price;
        if (currentBidder != address(0) && currentPrice > 0)
            payable(currentBidder).transfer(currentPrice);
        transferToken(petgptNFTAddress, tokenId, price, buyer, false);
    }

    //报价，向token报价
    event EnterBidForToken(uint tokenId, address bidder, address seller, uint price);

    function enterBidForToken(address petgptNFTAddress, uint tokenId) payable public {
        address bidder = msg.sender;
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        address currentBidder = bid.bidder;
        uint price = msg.value;
        uint currentPrice = bid.price;
        PETGPTNFT petgptNFT = PETGPTNFT(petgptNFTAddress);
        address ownerOfTokenId = petgptNFT.ownerOf(tokenId);
        //你不能购买自己的token
        require(bidder != ownerOfTokenId, 'You can not buy your own token');
        //token拥有者不是当前报价的出售者
        Offer storage offer = tokenOfferedForSale[petgptNFTAddress][tokenId];
        uint tokenOfferedForSalePrice = offer.price;
        //如果token拥有者依然是当前出售者，售价不为0且报价高于等于售价，报错：已有相同或更低售价，可选择直接购买
        require(ownerOfTokenId != offer.seller || tokenOfferedForSalePrice == 0 || price < tokenOfferedForSalePrice, 'Same or lower price already available, can choose to buy');
        bool ownerIsNotCurrentSeller = ownerOfTokenId != bid.seller;
        //如果token拥有者依然是当前报价的出售者，且报价者不是当前报价者或报价低于等于当前报价，报错：已有相同或更高报价
        require(ownerIsNotCurrentSeller || bidder == currentBidder || price > currentPrice, 'Same or higher bid already available');
        //如果token拥有者依然是当前报价的出售者，且报价者和报价与当前相同，报错：不能设置相同的报价
        require(ownerIsNotCurrentSeller || bidder != currentBidder || price != currentPrice, 'Cannot set the same bid');
        tokenBids[petgptNFTAddress][tokenId] = Bid(bidder, ownerOfTokenId, price, tokenId);
        emit EnterBidForToken(tokenId, bidder, ownerOfTokenId, price);
        //向当前报价者退款
        if (currentBidder != address(0) && currentPrice > 0)
            payable(currentBidder).transfer(currentPrice);
    }
    //接受报价
    function acceptBidForToken(address petgptNFTAddress, uint tokenId, uint minPrice) public checkOwnerOfTokenIdApproved(petgptNFTAddress, msg.sender, tokenId) {
        Bid storage bid = tokenBids[petgptNFTAddress][tokenId];
        uint price = bid.price;
        //token没有报价
        require(price > 0, 'This token has not be bid');
        //操作者虽然是token拥有者，但不是当前报价中的出售者
        require(msg.sender == bid.seller, 'The caller is not this seller');
        //当前报价低于最低预期价格
        require(price >= minPrice, 'This current bid is lower than the minimum expectation price');
        transferToken(petgptNFTAddress, tokenId, price, bid.bidder, true);
    }
}