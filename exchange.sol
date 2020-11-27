// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Exchange is IERC721Receiver{
    mapping (address => mapping(uint256 => address)) beneficialOwner;

    function deposit(ERC721 nftContract, uint256 tokenId) external {
        require(beneficialOwner[address(nftContract)][tokenId] == msg.sender);
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    // Deposit an asset and start an auction
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    )
        external virtual override 
        returns(bytes4)
    {
        beneficialOwner[msg.sender][tokenId] = from;
        return 0x150b7a02;
    }




}