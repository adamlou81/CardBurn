// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Genesis.sol";

contract Exchange is Genesis{
    struct listedToken{
        uint256 tokenID;
        uint256 bid;        //以ETH为单位
        address tokenOwner;
        bool isSold;
    }
    listedToken[] list;
    mapping(uint256 => address) private canWithDraw;    //谁有提取这个token的权利
    mapping(uint256 => uint256) private fromTokenIdToListedTokenIndex;

    event ListComplete(address indexed from, uint256 tokenID, uint256 bid);

    constructor(string memory basicURI) public Genesis("123") {

    }

    //在去中心化交易所里发布token进行售卖
    function deposit(uint256 tokenID, uint256 bid) public {
        //记录谁能从交易场所中提取这个token
        canWithDraw[tokenID] = msg.sender;
        //将tokenID塞入拍卖列表list中
        list.push(listedToken(tokenID, bid, msg.sender, false));
        //将tokenID关联该token在拍卖列表中的指针；
        fromTokenIdToListedTokenIndex[tokenID] = list.length - 1;
        emit ListComplete(msg.sender, tokenID, bid);
    }

    function purchase(uint256 tokenID) public payable{
        uint index = fromTokenIdToListedTokenIndex[tokenID];
        require(!list[index].isSold, "Token already has been sold!");
        require(list[index].bid < msg.value, "asdf");
    }
}