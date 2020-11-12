// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Genesis is ERC721, Ownable{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct innerAttributes{
        //up,down,left,right取值：[1-9]||[SS,S,A,B]
        uint16 up;
        uint16 down;
        uint16 left;
        uint16 right;

        // uint8 itemLevel;    //item等级:item等级直接决定
        // uint8 itemScarcity; //item稀有度
        
                                            //套装卡牌的设计在链下进行
        // bool isAPartOfSuiteProduct;         //是否是套装卡牌中的一张
        // uint64 indexOfSuite;                //套装卡牌的ID；
        // uint8 indexOfSuitePart;             //该装备在套装卡牌中的ID
        // uint64 suiteLevel;                  //套装卡牌的等级
        // uint64 suiteScarcity;               //套装卡牌的稀有度
        // string suiteAttributeDescription;   //套装卡牌属性描述[套装属性]
    
    }

    innerAttributes[] cards;                //cards[i]:表示tokenID=i的卡牌的属性
    uint256 cardLength;                     //全副卡牌的数量，【item和card是有区别的，item是card中的一张，不同的item可能会是相同的card】
    uint256 suiteLength;                    //套装卡牌的套装数量，【比如有两个套装：野蛮人套装卡牌+魔法师套装卡牌，那么suiteLength=2】


    //由合约拥有者任意设计一个item的属性
    // function designItem(address player, string memory tokenURI, uint16 up, uint16 down, uint16 left, uint16 right, uint8 itemLevel, uint8 itemScarcity) 
    //     public onlyOwner
    //     returns(uint256,string memory){
        
    // }

    //随机一张卡牌，无任何限制
    //参数：player：卡牌发送地址；
    //返回值：（新卡牌ID，新卡牌tokenURI)
    // function randomItem(address player) public returns(uint256, string memory){
    //     _tokenIds.increment();
    //     uint256 newItemId = _tokenIds.current();
    //     _mint(player, newItemId);



    // }

    // function randomCard(uint256 tokenID, bool level, bool scarcity, bool suite, bool indexOfSuite, bool indexOfSuitePart) private {
        
    // }

    ///用户可以根据规则烧掉若干张卡牌，换取一张新卡片。规则链下制定，是否满足也是链下判定
    function burnCardsAndCreateAnother(address player, uint256[] memory tokenID_CardsBurned, string memory tokenURI_CardCreated) public payable returns(uint256) {
        for(uint256 i = 0; i < tokenID_CardsBurned.length; i++){
            super._burn(tokenID_CardsBurned[i]);
        }
        return awardItem(player, tokenURI_CardCreated);
    }

    constructor(string memory basicURI) public ERC721("LEGENDE OF BIBLE : GENESIS", "GENESIS") {
        super._setBaseURI(basicURI);
    }

    function contractURI() public pure returns (string memory) {
        return "http://10.34.131.234/genesis/genesis.aspx/";
    }

    function awardItem(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}