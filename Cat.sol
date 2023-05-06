// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./IERC5192.sol";

interface CatScientist {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract Cat is Ownable, ERC721URIStorage,ERC721Enumerable, IERC5192 {

    bool private isLocked;
    CatScientist private catScientist;

    uint256 public price = 0.05 ether;
    uint256 public commission = 30;
    uint256 public bonus = 20;
    address public bonusAddress;

    string private _baseURIextended;

    constructor(address catScientistAddress) ERC721("Cat", "CAT") {
        catScientist = CatScientist(catScientistAddress);
        isLocked = true;
    }

    function mint(uint256 scientistId, string memory url) payable external {
        address scientistOwner = catScientist.ownerOf(scientistId);

        require(scientistOwner != address(0), 'Scientist Id is ineffective');
        uint256 value = msg.value;

        require(value >= price, 'Insufficient payment amount');
        address sender = msg.sender;
   
        if (value > price)
            payable(sender).transfer(value - price);

        uint256 scientistOwnerCommission = price / 100 * commission;

        if (scientistOwnerCommission > 0) {
            payable(scientistOwner).transfer(scientistOwnerCommission);
        }

        uint256 rewardBonus = price / 100 * bonus;

        if (rewardBonus > 0 && bonusAddress != address(0)) {
            payable(bonusAddress).transfer(rewardBonus);
        }

        uint256 ownerIncome = price - scientistOwnerCommission - rewardBonus;
        if (ownerIncome > 0)
            payable(owner()).transfer(ownerIncome);

        uint256 tokenId = totalSupply()+1;
        _safeMint(sender, tokenId);
        _setTokenURI(tokenId,url);

        if (isLocked) emit Locked(tokenId);
    }

    function setPrice(uint price_) public onlyOwner {
        price = price_;
    }

    function setCommission(uint commission_) public onlyOwner {
        require(commission_ <= 100, 'Commission cannot be greater than 100%');
        commission = commission_;
    }

    function setBonus(uint bonus_) public onlyOwner {
        require(bonus_ <= 100, 'bonus cannot be greater than 100%');
        bonus = bonus_;
    }

    function setBonusAddress(address bonusAddress_) public onlyOwner {
        bonusAddress = bonusAddress_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721,ERC721Enumerable) returns (bool) {
        return (interfaceId == type(IERC5192).interfaceId ||
            super.supportsInterface(interfaceId));
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override(ERC721,ERC721URIStorage) {
        super._burn(tokenId);
    }
    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721,ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /* begin ERC-5192 spec functions */
    /**
     * @inheritdoc IERC5192
     * @dev All valid tokens are locked: Relics are soul-bound/non-transferrable
     */
    function locked(uint256 id) external view returns (bool) {
        return ownerOf(id) != address(0);
    }

    /*
     * @dev All valid tokens are locked: Relics are soul-bound/non-transferrable
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721,ERC721Enumerable){

        require(from == address(0), "Soul Bound Token");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }



}
