// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./IERC5192.sol";

interface PetGenesis {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract Pet is Ownable, ERC721URIStorage,ERC721Enumerable, IERC5192 {

    bool private isLocked;
    PetGenesis private petGenesis;

    uint256 public price = 0.005 ether;
    uint256 public commission = 30;

    constructor(address petGenesisAddress) ERC721("Pet", "PET") {
        petGenesis = PetGenesis(petGenesisAddress);
        isLocked = true;
    }

    event PayForScientistOwner(address scientistOwner, uint256 amount);

    function mint(uint256 scientistId, string memory url) payable external {
        address scientistOwner = petGenesis.ownerOf(scientistId);

        require(scientistOwner != address(0), 'Scientist Id is ineffective');
        uint256 value = msg.value;

        require(value >= price, 'Insufficient payment amount');
        address sender = msg.sender;
   
        if (value > price)
            payable(sender).transfer(value - price);

        uint256 scientistOwnerCommission = price / 100 * commission;
        if (scientistOwnerCommission > 0) {
            payable(scientistOwner).transfer(scientistOwnerCommission);
            emit PayForScientistOwner(scientistOwner, scientistOwnerCommission);
        }

        uint256 ownerIncome = price - scientistOwnerCommission;
        if (ownerIncome > 0)
            payable(owner()).transfer(ownerIncome);

        uint256 tokenId = totalSupply()+1;
        _safeMint(sender, tokenId);
        _setTokenURI(tokenId,url);

        if (isLocked) emit Locked(tokenId);
    }

    function setPrice(uint256 _price,uint256 _commission) external onlyOwner {
        price = _price;
        commission = _commission;
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
