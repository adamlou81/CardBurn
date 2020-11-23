// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Genesis is ERC721, Ownable{
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;

    struct cardAttributes{
        //卡片4个方向的战斗数值；
        uint32 up;
        uint32 down;
        uint32 left;
        uint32 right; 

        uint32 indexInLevel;                      //该张卡片是卡片level层中的哪一张，比如level=3,indexInLevel=5,就是第三层的第5张卡片
        uint32 level;                             //该卡片是属于那一层的
        uint32 element;                            //0：无属性；1：Fire；2：Ice；3：Thunder；4：Earth；5：Water；6：Wind；7：Poison；8：Holy;【属性之间没有克制关系，只对卡牌游戏有影响】
        bool isElite;                             //是否是精英卡片,对实际战斗数值有影响，每个战斗值+1，战斗值颜色标红；同时卡片图片背景的变化，比如魔兽世界的精英怪银龙头像背景
    }
    cardAttributes[] private cards;             //********注意：cards下标从1开始，与tokenID对应*******

    struct SysParams{
        uint32  maxCardsCanBeBurned;            //一次最多能烧几张卡片，默认值为5
        uint32  elitePossibility;               //2张普通卡片升级为Elite的几率：elitePossibility*10 / 1000    
        uint32  extraElitePossibility;          //如果烧掉的2张卡片中有elite卡片，则生成的卡片升级为elite的几率为（elitePossibility+extraElitePossibility）*10/ 1000

        uint32 levelCount;                      //总共多少层卡片
        uint32[] NumberOfCardsInLevel;          //NumberOfCardsInLevel[2]：表示第二层（level=2）卡片的数量；新增卡片时需要修改该值；      
    }
    SysParams private _sysParams;  

    //正常：焚烧卡片后，没有生成新卡片；
    event BurnAndCreate_NotCreateCard(address indexed from, address indexed to, uint256[] burnedCards);
    //正常：焚烧卡片完成；
    event BurnAndCreate_CardsBurned();  
    //生成了新卡片
    event NewCard(address indexed from, address indexed to , uint256 tokenID);
    //用户付款生成卡片后触发
    event PaytoGenerate(address indexed from, address indexed to , uint256 tokenID);

    //初始化合约参数，只在合约初始化时调用
    function initSysParams(uint32 maxCardsCanBeBurned, uint32 elitePossibility, uint32 extraElitePossibility, uint32 levelCount, uint32[] memory NumberOfCardsInLevel) private {
        _sysParams.maxCardsCanBeBurned = maxCardsCanBeBurned;
        _sysParams.elitePossibility = elitePossibility;
        _sysParams.extraElitePossibility = extraElitePossibility;
        _sysParams.levelCount = levelCount;

        _sysParams.NumberOfCardsInLevel.push(0);    //第0层的卡片数量是0；
        for(uint256 i = 1; i < NumberOfCardsInLevel.length; i++){
            _sysParams.NumberOfCardsInLevel.push(NumberOfCardsInLevel[i]);
        }
    }

    //新增卡牌时，增加该卡牌所在level的长度
    function increaseNumberOfCardsInLevel(uint32 level) public onlyOwner{
        _sysParams.NumberOfCardsInLevel[level]++;
    }

    //返回：
    //1. 该level卡片的单个方向战斗值最小值
    //2. 该level卡片的单个方向战斗值最大值
    function setMaxAndMinBattleValue(uint32 level) private pure returns(uint32,uint32){
        return (level, level+2);
    }

    //根据卡片的level，随机4个方向的战斗值
    function rand4BattleValue(uint32 level, uint256 seed) private view returns(uint32,uint32,uint32,uint32){
        uint32 up;
        uint32 down;
        uint32 left;
        uint32 right;
        uint32 minValue;
        uint32 maxValue;
        (minValue, maxValue) = setMaxAndMinBattleValue(level);
        uint32 l = maxValue - minValue + 1;
        uint256 s = seed;
        
        up = uint32(getRandNum(s, l) + uint256(minValue));
        s += s.add(1);
        down = uint32(getRandNum(s, l) + uint256(minValue));
        s += s.add(1);
        left = uint32(getRandNum(s, l) + uint256(minValue));
        s += s.add(1);
        right = uint32(getRandNum(s, l) + uint256(minValue));

        return (up, down, left, right);
    }

    function randIndexInLevel(uint32 level, uint256 seed) private view returns(uint32){
        uint32 c = _sysParams.NumberOfCardsInLevel[level];
        return uint32(1 + getRandNum(seed, c));
    }

    function randElement(uint256 seed) private view returns(uint32){
        uint256 r = getRandNum(seed, 100);
        if(r <= 95)  return 0;
        return uint32(getRandNum(seed+1, 8) + 1);
    }

    //elite : nonElite = 1 : 9
    function randIsElite(uint256 seed) private view returns(bool){
        return getRandNum(seed, 10) == 0 ? true : false;
    }

    //几率：10级卡：1%；9级卡：2%，8级卡：3%；7级卡：4%；6级卡：5%；5级卡：6%；4级卡：7%；3级卡：8%；2级卡：14%；1级卡:50%
    //随机值区间说明：10级卡：[1]；9级卡：[2,3]；8级卡：[4,6]；7级卡：[7,10]；
    //               6级卡：[11-15]；5级卡：[16-21];4级卡：[22,28]；3级卡：[29,36]
    //               2级卡：[37,50],1级卡：[51-100]
    function randLevel(uint256 seed) private view returns(uint32){
        uint256 r = getRandNum(seed, 100) + 1;
        if(r == 1)  return 10;
        else if(r >= 2 && r <= 3)   return 9;
        else if(r >= 4 && r <= 6)   return 8;
        else if(r >= 7 && r <= 10)  return 7;
        else if(r >= 11 && r <= 15) return 6;
        else if(r >= 16 && r <= 21) return 5;
        else if(r >= 22 && r <= 28) return 4;
        else if(r >= 29 && r <= 36) return 3;
        else if(r >= 37 && r <= 50) return 2;
        else if(r >= 51 && r <= 100)    return 1;
    }

    //随机生成一张卡片，并push进cards数组;
    //如果入参level == 0, 则卡片level也随机；
    //如果入参isElite == false, 则卡片的isElite属性随机；
    function randCard(uint32 level, bool isElite, uint256 seed) private returns(uint256){
        cardAttributes memory card;                           

        card.level = level == 0 ? randLevel(seed) : level;
        seed += seed.add(1);
        (card.up, card.down, card.left, card.right) = rand4BattleValue(card.level, seed);
        seed += seed.add(1);
        card.indexInLevel = randIndexInLevel(card.level, seed);
        seed += seed.add(1);
        card.element = randElement( seed);
        seed += seed.add(1);
        card.isElite = isElite ? true : randIsElite(seed);
        cards.push(card);
    }

    //随机生成token
    //如果入参level == 0, 则卡片level也随机；
    //如果入参isElite == false, 则卡片的isElite属性随机；
    //用户每次随机价格是0.005，多付不退；
    function randToken(address player, uint256 seed) public payable returns (uint256) {
        require(msg.value >= 0.005 ether,"At Least 0.005 Eth is Needed to Generate New Card!");

        //1. 生成新的卡片属性
        randCard(0, false, seed);
        //2. 组装成新的ERC721 token
        uint256 createdTokenID = awardItem(player);                   //attension: 此处理论上cards数组的长度 == createdTokenID，即cards数组根据下标一一对应tokenID
        //3. 判断结果，并触发对应的事件
        emit NewCard(msg.sender, player, createdTokenID);
        return createdTokenID; 
    }

    function randTokenForBurn(address player, uint256 seed) private returns (uint256) {
        //require(msg.value >= 0.005 ether,"At Least 0.005 Eth is Needed to Generate New Card!");

        //1. 生成新的卡片属性
        randCard(0, false, seed);
        //2. 组装成新的ERC721 token
        uint256 createdTokenID = awardItem(player);                   //attension: 此处理论上cards数组的长度 == createdTokenID，即cards数组根据下标一一对应tokenID
        //3. 判断结果，并触发对应的事件
        emit NewCard(msg.sender, player, createdTokenID);
        return createdTokenID; 
    }

    //发行token
    function issueToken(address player, bool isElite, uint32 level, uint32 index, uint32 element, uint32 up, uint32 down, uint32 left, uint32 right)
    public onlyOwner returns(uint256){
        cardAttributes memory card;
        card.up = up;
        card.down = down;
        card.left = left;
        card.right = right;
        card.level = level;
        card.isElite = isElite;
        card.element = element;
        card.indexInLevel = index;

        cards.push(card);
        uint256 createdTokenID = awardItem(player);
        emit NewCard(msg.sender, player, createdTokenID);
        return createdTokenID;
    }

    //焚烧掉卡片组tokenIDs;
    function burnCards(uint256[] memory tokenIDs ) private{
        for(uint i = 0; i < tokenIDs.length; i++){
            _burn(tokenIDs[i]);
        }
        emit BurnAndCreate_CardsBurned();
    }

    function awardItem(address player) private returns (uint256){
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        string memory tokenURI = newItemId.toString();

        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    //烧掉卡片组tokenIDs，并按规则生成另一张卡片
    //tokenIDs: 被烧掉卡片的tokenID数组
    function burnAndCreate(uint256[] memory tokenIDs, uint256 seed) public returns(bool, uint256){
        //require(msg.sender == player, "player must be the msg.sender!");
        require(ownedCards(tokenIDs), "Player do not own all the selected cards!");
        require(isLegalCardsCount(tokenIDs), "Illegal Cards Amount which are to be burned!");
        require(!containHighestLevelCard(tokenIDs), "Contain Highest Level Cards!");
        bool same = true;
        (same,) = allTheSameLevel(tokenIDs);
        require(same, "Different Cards Level!");

        bool isHigherLevelCardGenerated;
        bool isElite;
        uint32 level;
        (isHigherLevelCardGenerated,isElite,level) = lotery(tokenIDs, seed);
        seed += seed.add(1);

        //1. 焚烧卡片
        burnCards(tokenIDs);

        //2. 判断是否有新卡片（更高级）生成，如果没有，返回false（第一个返回值）
        if(!isHigherLevelCardGenerated){
            emit BurnAndCreate_NotCreateCard(msg.sender, msg.sender, tokenIDs);      
            return (false, 0);
        }       

        //3.生成token
        uint256 createdTokenID = randTokenForBurn(msg.sender, seed);
        return (true, createdTokenID);
    }

    //uint32 maxCardsCanBeBurned, uint32 elitePossibility, uint32 extraElitePossibility, uint32 levelCount
    constructor(string memory basicURI) public ERC721("GENISIS", "GIS") {
        cardAttributes memory c;
        cards.push(c);
        //设置系统参数
        //function initSysParams(uint32 maxCardsCanBeBurned, uint32 elitePossibility, uint32 extraElitePossibility, uint32 levelCount, uint32[] NumberOfCardsInLevel)
        uint32 levelCount = 10;
        uint32[] memory n = new uint32[](levelCount+1);
        n[0] = 0;n[1]= 11;n[2]= 11;n[3]= 11;n[4]= 11;n[5]= 11;n[6]= 11;n[7]= 11;n[8]= 11;n[9]= 11;n[10]= 11;
        initSysParams(4,5, 1, levelCount, n);
        //设置BaseURI
        super._setBaseURI(basicURI);
    }

    function getSysParams() public view onlyOwner returns(uint32,uint32,uint32,uint32){   
        return ( _sysParams.maxCardsCanBeBurned, _sysParams.elitePossibility, _sysParams.extraElitePossibility, _sysParams.levelCount);
    }

    function getNumberOfCardsInLevel(uint32 level) public view onlyOwner returns(uint32){
        return _sysParams.NumberOfCardsInLevel[level];
    }

    function getItemAttributes_battleValues(uint256 tokenID) public view returns(uint32, uint32, uint32, uint32){
        require(_exists(tokenID), "Query For Non-exist Token!");

        return (cards[tokenID].up, cards[tokenID].down, cards[tokenID].left, cards[tokenID].right);
    }

    function getItemAttributes_exceptBattleValues(uint256 tokenID) public view returns(uint32, uint32, uint32, bool){
        return (cards[tokenID].level, cards[tokenID].indexInLevel, cards[tokenID].element, cards[tokenID].isElite);
    }

    //获取player拥有的所有token
    function getAllTokensOfPlayer(address player) public view returns(uint256[] memory){
        uint256 total = super.balanceOf(player);
        uint256[] memory tokenIDs = new uint256[](total);
        for(uint256 i = 0; i < total; i++){
            tokenIDs[i] = super.tokenOfOwnerByIndex(player, i);
        }

        return tokenIDs;
    }

    //test function
    function getItemLength() public onlyOwner view returns(uint256){
        return cards.length;
    }

    //admin tools
    //player == address(0):不过滤player;
    //level == 0:不过滤level；
    //containIsElite == false:不过滤isElite;
    function getToken(address player, uint32 level, bool containIsElite, bool isElite) public view onlyOwner returns(uint256[] memory){
        uint256[] memory tokenIDs;
        uint256 total;
        uint32 l;
        uint32 index;
        uint32 element;
        bool elite;

        uint256 count = 0;       
        if(player == address(0)){
            total = super.totalSupply();
            uint256[] memory temp = new uint256[](total);
            for(uint256 i = 0; i < total; i++){
                (l, index, element, elite) = getItemAttributes_exceptBattleValues(super.tokenByIndex(i));
                if(level != 0){
                    if(l != level)  continue;        
                }
                if(containIsElite){
                    if(elite != isElite)    continue;
                }
                temp[count] = super.tokenByIndex(i);
                count++;
            }
            tokenIDs = new uint256[](count);
            for(uint256 i = 0; i < count; i++){
                tokenIDs[i] = temp[i];
            }
        }
        else{
            total = super.balanceOf(player);
            uint256[] memory temp = new uint256[](total);
            for(uint256 i = 0; i < total; i++){
                (l, index, element, elite) = getItemAttributes_exceptBattleValues(super.tokenOfOwnerByIndex(player,i));
                if(level != 0){
                    if(l != level)  continue;        
                }
                if(containIsElite){
                    if(elite != isElite)    continue;
                }
                temp[count] = super.tokenOfOwnerByIndex(player,i);
                count++;
            }
            tokenIDs = new uint256[](count);
            for(uint256 i = 0; i < count; i++){
                tokenIDs[i] = temp[i];
            }
        }
        return tokenIDs;
    }

    function getTokensCount(address player, uint32 level, bool containIsElite, bool isElite) public view onlyOwner returns(uint256){
        uint256[] memory tokenIDs = getToken(player, level, containIsElite, isElite);
        return tokenIDs.length;
    }

    function getToken(address player, uint32 level, bool containIsElite, bool isElite, uint32 indexInLevel) public view onlyOwner returns(uint256){
        uint256[] memory tokenIDs = getToken(player, level, containIsElite, isElite);

        uint32 l;
        uint32 index;
        uint32 element;
        bool elite;
        uint256 count = 0;
        for(uint256 i = 0; i < tokenIDs.length; i++){
            (l, index, element, elite) = getItemAttributes_exceptBattleValues(tokenIDs[i]);
            if(index == indexInLevel)   count++;
        }
        return count;
    }



    ///**************************************************************  Start: Game Rules ******************************************************************/
    ///**************************************************************  Start: Game Rules ******************************************************************/
    ///**************************************************************  Start: Game Rules ******************************************************************/
    //焚烧卡片并生成新卡片的规则：
    //1. 只有数量为2，3，4的卡片数可以烧掉并生成另外一张卡片
    //2. 最高层的卡片不能被烧掉；
    //3. 只有同一层的卡片才能被烧掉；
    //4. 如果数量为2：50%生成高一级卡片一张，有elitePossibility%的几率升级为elite卡片；
    //5. 如果数量为3：75%生成高一级卡片一张，(有elitePossibility*13)%的几率升级为elite卡片;
    //6. 如果数量为4：100%生成高一级卡片一张，(有elitePossibility*16)%的几率升级为elite卡片;
    //7. 如果烧掉的卡片中有elite卡片，则生成的卡片升级为elite的几率额外提升 extraElitePossibility*10
    //8. 返回值(isHigherLevelCardGenerated, isEliteCard, currentCardsLevel)
    function lotery(uint256[] memory tokenIDs, uint seed) private view returns(bool, bool, uint32){
        uint256 randNum;// = getRandNum(seed, randBase);
        bool isHigherLevelCardGenerated;                //是否按概率生成了更高级的卡片
        bool isEliteCard;                               //烧掉的卡片中是否含有精英卡片
        bool isSameLevel;                               //是否都是同一个level的卡片
        uint32 currentCardsLevel;                          //烧掉的卡片属于哪一个level

        (isSameLevel, currentCardsLevel) = allTheSameLevel(tokenIDs);

        if(!isLegalCardsCount(tokenIDs)) return (false, false, 0);               //不存在序列号为0的卡片，没有烧掉原来卡片，也没有生产新卡片
        if(!isSameLevel)  return (false, false, 0);              
        if(containHighestLevelCard(tokenIDs))   return (false, false, 0);
        
        uint256 possibilityOfHeightLevelCard;
        uint256 possibilityOfEliteCard;
        //uint256 randSeed = randNum;
        if(tokenIDs.length == 2){
            possibilityOfHeightLevelCard = 50;
            possibilityOfEliteCard = 10;

        }
        else if(tokenIDs.length == 3){
            possibilityOfHeightLevelCard = 75;
            possibilityOfEliteCard = 13;
        }
        else if(tokenIDs.length == 4){
            possibilityOfHeightLevelCard = 100;
            possibilityOfEliteCard = 16;
        }
        else{
            return (false, false, 0);    
        } 
        randNum = getRandNum(seed, 100);
        isHigherLevelCardGenerated = isInInterval(randNum, 0, possibilityOfHeightLevelCard);
        if(!isHigherLevelCardGenerated)  return (false, false, 0);
        
        currentCardsLevel++;
        randNum = getRandNum(seed + 1, 1000);
        bool containElite = containEliteCard(tokenIDs);
        if(containElite){
            isEliteCard = isInInterval(randNum, 0, _sysParams.elitePossibility * possibilityOfEliteCard + _sysParams.extraElitePossibility*10);
        }
        else{
            isEliteCard = isInInterval(randNum, 0, _sysParams.elitePossibility * possibilityOfEliteCard);
        }
        
        return (true, isEliteCard, currentCardsLevel);
    }

    function isLegalCardsCount(uint256[] memory tokenIDs) view private returns(bool){
        if(tokenIDs.length > _sysParams.maxCardsCanBeBurned || tokenIDs.length == 1)    return false;
        return true;
    }

    function allTheSameLevel(uint256[] memory tokenIDs) view private returns(bool, uint32){
        if(tokenIDs.length == 0 || tokenIDs.length == 1)  return (true, _sysParams.levelCount);

        uint32 level = cards[tokenIDs[0]].level;
        for(uint i = 1; i < tokenIDs.length; i++){
            if(level != cards[tokenIDs[i]].level)  return (false, 0);     
           
        }
        return (true, level);
    }

    function containHighestLevelCard(uint256[] memory tokenIDs) view private returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(cards[tokenIDs[i]].level == _sysParams.levelCount)    return true;
        }
        return false;
    }
    
    function containEliteCard(uint256[] memory tokenIDs) private view returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(cards[tokenIDs[i]].isElite)    return true;
        }
        return false;
    }

    //判断这组卡片是否属于msg.sender
    function ownedCards(uint256[] memory tokenIDs ) private view returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(msg.sender != ownerOf(tokenIDs[i]))    return false;
        }
        return true;
    }
    ///**************************************************************  End: Game Rules ******************************************************************/
    ///**************************************************************  End: Game Rules ******************************************************************/
    ///**************************************************************  End: Game Rules ******************************************************************/



    //*************start:通用方法****************/
    function isInInterval(uint256 num, uint256 start, uint256 end) private pure returns(bool){
        if(start > end) return false;

        if(num >= start && num <= end)  return true;
        return false;
    }

    function getRandNum(uint256 seed, uint256 index) private view returns(uint256){
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, seed))) % index;
        return rand;
    }
    //*************end:通用方法****************/

    //查询合约中的ether余额
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    //提取合约中的ether余额至msg.sender
    function withdrawContractBalance() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    //提取合约中一半ether
    function withdrawContractBalanceHalf() public onlyOwner {
        msg.sender.transfer(address(this).balance / 2);
    }

}