// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PRND.sol";

contract CardBurn is ERC721, Ownable, PRNG{
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;
    uint256 private randSeed = 0;
    uint256 private randBase = 9999999;

    struct cardAttributes{
        string value;       
        uint32 cardSequenceNo;                      //该张卡片是整副牌中的哪一张；注意区别于tokenID
        uint32 cardLevel;                            //该卡片是属于那一层的
        bool isElite;                               //是否是精英卡片,精英卡片的设定应该是非常稀有
    }
    cardAttributes[] private items;

    struct SysParams{
        uint32  maxCardsNo;                     //整副卡片的张数；（不重复）
        uint32  maxCardsCanBeBurned;            //一次最多能烧几张卡片，默认值为5
        uint32  elitePossibility;               //2张普通卡片升级为Elite的几率：elitePossibility*10 / 1000    【elitePossibility和extraElitePossibility取值：0-100】
        uint32  extraElitePossibility;          //如果烧掉的2张卡片中有elite卡片，则生成的卡片升级为elite的几率为（elitePossibility+extraElitePossibility）*10/ 1000

        uint32 levelCount;
        //卡片最小序列号从1开始，比如level 1卡片区间[1 - 5], levle 2 卡片区间[6 - 9], level 3卡片区间[10 - 12], level 4卡片区间[13 - 14],level 5卡片区间[15 -15]
        uint32[] levelIntervalsStartIndex;        
        uint32[] levelIntervalsEndIndex;
    }
    SysParams private _sysParams;  

    //正常：焚烧卡片后，没有生成新卡片；
    event BurnAndCreate_NotCreateCard();
    //正常：焚烧卡片完成；
    event BurnAndCreate_CardsBurned();  
    //生成了新卡片
    event NewCard(address indexed from, address indexed to , uint256 tokenID, uint32 cardSequenceNo);
    //用户付款生成卡片后触发
    event PaytoGenerate(address indexed from, address indexed to , uint256 tokenID);

    //设置每一层的区间起始和终止下标；设置MaxCardNo；
    //length: 每层的卡片数量，【默认为相同】
    function initSysParams_LevelIntervalIndexAndMaxCardsNo(uint32 levelCount, uint32 length) private {
        uint32 cardsNum = 0;
        uint32 intervalLength = length;
        uint32 start = 1;
        uint32 end;
        for(uint256 i = 1; i <= levelCount; i++){
            _sysParams.levelIntervalsStartIndex.push(start);
            end = start + intervalLength - 1;
            _sysParams.levelIntervalsEndIndex.push(end);
            start = end + 1;

            cardsNum += (_sysParams.levelIntervalsEndIndex[i - 1] - _sysParams.levelIntervalsStartIndex[i - 1] + 1);
        }
        _sysParams.maxCardsNo = cardsNum;
    } 

    //初始化系统参数,只在合约构造函数中被调用一次
    function initSysParams(uint32 maxCardsCanBeBurned, uint32 elitePossibility, uint32 extraElitePossibility, uint32 levelCount) private {
        //_sysParams.maxCardsNo = maxCardsNo;
        _sysParams.maxCardsCanBeBurned = maxCardsCanBeBurned;
        _sysParams.elitePossibility = elitePossibility;
        _sysParams.extraElitePossibility = extraElitePossibility;
        if(levelCount == 0) _sysParams.levelCount = 10;
        else _sysParams.levelCount = levelCount;
        initSysParams_LevelIntervalIndexAndMaxCardsNo(_sysParams.levelCount, 11);
    }

    //随机生成某一个level的卡片，cardLevel下标从1开始
    //siElite：新卡片是否是精英卡片
    //currentCardsLevel:新卡片的level等级
    function randomGenerateCertainLevelCard(bool isElite, uint32 currentCardsLevel, uint256 seed) private returns(uint256 cardIndex){
        uint32 cardSequenceNo = randCardSequenceNo(currentCardsLevel, seed);
        string memory value = randCardValue(currentCardsLevel, isElite, seed);

        cardAttributes memory card;
        card.value = value;
        card.cardSequenceNo = cardSequenceNo;
        card.cardLevel = currentCardsLevel;
        card.isElite = isElite;
        items.push(card);

        if(items.length == 0)   return 0;
        else    return items.length - 1;
    }

    //焚烧掉卡片组tokenIDs;
    function burnCards(uint256[] memory tokenIDs ) private{
        for(uint i = 0; i < tokenIDs.length; i++){
            _burn(tokenIDs[i]);
        }
        emit BurnAndCreate_CardsBurned();
    }

    function awardItem(address player, string memory tokenURI) private returns (uint256){
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    //烧掉卡片组tokenIDs，并按规则生成另一张卡片
    //tokenIDs: 被烧掉卡片的tokenID数组
    //player: 新生产卡片的owner；
    function burnAndCreate(address player, uint256[] memory tokenIDs, uint256 seed) public returns(bool, uint256){
        require(msg.sender == player, "player must be the msg.sender!");
        require(ownedCards(tokenIDs), "Player do not own all the selected cards!");
        require(isLegalCardsCount(tokenIDs), "Illegal Cards Amount which are to be burned!");
        require(!containHighestLevelCard(tokenIDs), "Contain Highest Level Cards!");
        bool same = true;
        (same,) = allTheSameLevel(tokenIDs);
        require(same, "Different Cards Level!");

        bool isHigherLevelCardGenerated;
        bool isElite;
        uint32 currentCardsLevel;
        (isHigherLevelCardGenerated,isElite,currentCardsLevel) = lotery(tokenIDs, seed);

        //1. 焚烧卡片
        burnCards(tokenIDs);

        //2. 判断是否有新卡片（更高级）生成，如果没有，返回false（第一个返回值）
        if(!isHigherLevelCardGenerated){
            emit BurnAndCreate_NotCreateCard();      
            return (false, 0);
        }       

        //3.生成token
        uint256 createdTokenID = randGenerateToken(player, isElite, currentCardsLevel, seed);
        return (true, createdTokenID);
    }

    //uint32 maxCardsCanBeBurned, uint32 elitePossibility, uint32 extraElitePossibility, uint32 levelCount
    constructor(string memory basicURI) public ERC721("BURNIT", "BURN") {
        //设置系统参数
        initSysParams(4,5, 1, 10);
        //设置BaseURI
        super._setBaseURI(basicURI);
    }

    //随机生成一张卡片，指定isElite和Level
    function randGenerateToken(address player, bool isElite, uint32 currentCardsLevel, uint256 seed) public returns (uint256) {
        //1. 生成新的卡片属性
        uint256 cardIndex = 0;
        cardIndex = randomGenerateCertainLevelCard(isElite, currentCardsLevel, seed);
        //2. 组装成新的ERC721 token
        string memory tokenURI = randCreateTokenURI(seed);
        uint256 createdTokenID = awardItem(player, tokenURI);                   //attension: 此处理论上cardIndex == createdTokenID - 1
        //3. 判断结果，并触发对应的事件
        emit NewCard(msg.sender, player, createdTokenID, items[tokenIdToItemId(createdTokenID)].cardSequenceNo);

        return createdTokenID;   
    }

    function payToGetRandToken(uint256 seed) public payable returns (uint256) {
        require(msg.value >= 0.05 ether,"At Least 0.05 Eth is Needed to Generate New Card!");
        
        uint32 level  = setCardLevelAccordingToPayment();
        uint256 tokenID = randGenerateToken(msg.sender, false, level, seed);
        emit PaytoGenerate(msg.sender, msg.sender, tokenID);
        //只随机产生非精英、等级为1的卡片
        return tokenID;

    }

    function airdropItems(address[] memory players, uint256 round, uint256 randN) public onlyOwner{ 
        uint256 t = round;
        uint256 seed = randN;
        while(t > 0){
            seed = seed.add(t);
            bool elite;
            uint32 level;
            for(uint256 i = 0; i < players.length; i++){
                elite = getRandNum(seed + i,2) == 0 ? true : false;
                seed += seed.add(1);
                level = uint32(getRandNum(seed + i, _sysParams.levelCount)) + 1;
                seed += seed.add(1);
                randGenerateToken(players[i], elite, level,seed);
                seed += seed.add(1);
            }
            t--;
        }
    }

    function contractURI() public pure returns (string memory) {
        return "http://10.34.131.234/genesis/genesis.aspx/";
    }

    function tokenIdToItemId(uint256 tokenID) private pure returns(uint256 itemID){
        return tokenID.sub(1);
    }

    function getSysParams() public view returns(uint32,uint32,uint32,uint32,uint32){ 
        return (_sysParams.maxCardsNo, _sysParams.maxCardsCanBeBurned, _sysParams.elitePossibility, _sysParams.extraElitePossibility, _sysParams.levelCount);
    }

    function getSysParams_intervalEdge(uint32 level) public view returns(uint32, uint32){
        return (_sysParams.levelIntervalsStartIndex[level-1], _sysParams.levelIntervalsEndIndex[level-1]);
    }

    function getItemAttributes(uint256 tokenID) public view returns(string memory, uint32, uint32, bool){
        require(_exists(tokenID), "Query For Non-exist Token!");
        return (items[tokenIdToItemId(tokenID)].value, items[tokenIdToItemId(tokenID)].cardSequenceNo, items[tokenIdToItemId(tokenID)].cardLevel, items[tokenIdToItemId(tokenID)].isElite);
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

    ///**************************************************************  Start: Game Rules ******************************************************************/
    ///**************************************************************  Start: Game Rules ******************************************************************/
    ///**************************************************************  Start: Game Rules ******************************************************************/
    //根据给定的level，随机产生该level级别的一张卡片
    function randCardSequenceNo(uint32 level, uint256 seed) private view returns(uint32 cardSequenceNo){
        uint32 levelLength = _sysParams.levelIntervalsEndIndex[level - 1] - _sysParams.levelIntervalsStartIndex[level - 1] + 1;
        uint32 sequenceNo = uint32(getRandNum(seed, levelLength) + _sysParams.levelIntervalsStartIndex[level - 1]);
        return sequenceNo;
    }

    //根据level和isElite生成某张卡片的value值
    function randCardValue(uint32 level, bool isElite, uint256 seed)  private view returns(string memory){
        string memory returnString;
        uint256 rand = getRandNum(seed, randBase);
        if(level == 1 || level == 2){     //1-2
            rand = rand % 2 + 1;
            isElite ? rand + 1 : rand;
            returnString = rand.toString();
        }
        else if(level == 3 || level == 4){//3-5
            rand = rand % 3 + 3;
            isElite ? rand + 1 : rand;
            returnString = rand.toString();
        }
        else if(level == 5 || level == 6){//6-7
            rand = rand % 2 + 6;
            isElite ? rand + 1 : rand;
            returnString = rand.toString();
        }
        else if(level == 7 || level == 8){//8-9
            rand = rand % 2 + 8;
            isElite ? rand + 1 : rand;
            returnString = rand.toString();
        }
        else if(level == 9 || level == 10){//SS,S,A
            rand %= 3;
            if(rand == 0)    returnString = "SS";
            else if(rand == 1)  returnString = "S";
            else    returnString = "A";
        }
        else{
            returnString = "ERROR";
        }
        return returnString;
    }

    //根据用户的付款，判断生成的卡片等级
    function setCardLevelAccordingToPayment() private returns(uint32){
        uint32 level  = 0;
        if(msg.value <= 0.1 ether && msg.value > 0.05 ether)    level = 1;
        else if(msg.value <= 0.15 ether && msg.value > 0.1 ether)   level = 2;
        else if(msg.value <= 0.2 ether && msg.value > 0.15 ether)   level = 3;
        else if(msg.value <= 0.25 ether && msg.value > 0.2 ether)   level = 4;
        else if(msg.value <= 0.3  ether&& msg.value > 0.25 ether)   level = 5;
        else if(msg.value <= 0.35 ether && msg.value > 0.3 ether)   level = 6;      
        else if(msg.value <= 0.6 ether && msg.value > 0.35 ether)   level = 7;

        else if(msg.value <= 0.8 ether && msg.value > 0.6 ether)   level = 8;
        else if(msg.value <= 0.9 ether && msg.value > 0.8 ether)   level = 9;
        else level = 10;

        return level;
    }

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
        uint256 randNum = getRandNum(seed, randBase);
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
        isHigherLevelCardGenerated = isInInterval(randNum % 100, 0, possibilityOfHeightLevelCard);
        if(!isHigherLevelCardGenerated)  return (false, false, 0);
        
        currentCardsLevel++;
        randNum %= 1000;
        bool containElite = containEliteCard(tokenIDs);
        if(containElite){
            isEliteCard = isInInterval(randNum % 1000, 0, _sysParams.elitePossibility * possibilityOfEliteCard + _sysParams.extraElitePossibility*10);
        }
        else{
            isEliteCard = isInInterval(randNum % 1000, 0, _sysParams.elitePossibility * possibilityOfEliteCard);
        }
        
        return (true, isEliteCard, currentCardsLevel);
    }

    //生成新卡片时调用，生成的tokenURI作为服务器item数据库中该item记录的ID，用于返回http接口的查询；【用event向前台返回tokenURI和cardSequenceNo】
    function randCreateTokenURI(uint seed) private view returns (string memory){
        uint256 tokenURI = getRandNum(seed, seed + 1);
        return tokenURI.toString();
    }

    function isLegalCardsCount(uint256[] memory tokenIDs) view private returns(bool){
        if(tokenIDs.length > _sysParams.maxCardsCanBeBurned || tokenIDs.length == 1)    return false;
        return true;
    }

    function allTheSameLevel(uint256[] memory tokenIDs) view private returns(bool, uint32){
        if(tokenIDs.length == 0 || tokenIDs.length == 1)  return (true, _sysParams.levelCount);

        uint32 level = items[tokenIdToItemId(tokenIDs[0])].cardLevel;
        for(uint i = 1; i < tokenIDs.length; i++){
            if(level != items[tokenIdToItemId(tokenIDs[i])].cardLevel)  return (false, 0);     
           
        }
        return (true, level);
    }

    function containHighestLevelCard(uint256[] memory tokenIDs) view private returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(items[tokenIdToItemId(tokenIDs[i])].cardLevel == _sysParams.levelCount)    return true;
        }
        return false;
    }
    
    function containEliteCard(uint256[] memory tokenIDs) private view returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(items[tokenIdToItemId(tokenIDs[i])].isElite)    return true;
        }
        return false;
    }

    //判断这组卡片(tokenIDs)是否可以被烧掉，即，这组卡片是否属于msg.sender
    function ownedCards(uint256[] memory tokenIDs ) private view returns(bool){
        for(uint i = 0; i < tokenIDs.length; i++){
            if(msg.sender != ownerOf(tokenIDs[i]))    return false;
        }
        return true;
    }

    //判断等待被烧掉的卡片是否合法：1.卡片是否都属于msg.sender;2.卡片的数量是否合法；3.不能包含最高级别的卡片；4.卡片是否属于同一个level；
    function isAbleToBurn(uint256[] memory tokenIDs) private view returns (bool){
        bool same;
        (same,) = allTheSameLevel(tokenIDs);
        if(ownedCards(tokenIDs) && isLegalCardsCount(tokenIDs) && !containHighestLevelCard(tokenIDs) && same) return true;

        return false;
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
        uint256 rand = importSeedFromThird(seed + now);
        return rand % index;
    }
    //*************end:通用方法****************/

    //查询合约中的ether余额
    function getContractBalance() public view returns (uint256) {
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