const BN = require("bn.js");
const { default: Web3 } = require("web3");
const Genesis = artifacts.require("Genesis");

var baseURI = "http://10.34.131.234/genesis/Handlers/TokenUrlHandler.ashx/";
var expect = require('chai').expect;
const utils = require("./utils.js");

contract("Genesis", (accounts) => {
    let [alice, bob] = accounts;
    let contractInstance;
    var minRandPayment = 5000000000000000;
    var BN0 = new BN(0);
    var BN1 = new BN(1);
    beforeEach(async () => {
        contractInstance = await Genesis.new(baseURI);
    });

    context("测试一：randToken。参数1类型：address;参数2类型：uint256(seed)", async () => {
        it("1.alice支付0.005 eth调用了合约方法后，alice拥有的ERC721 token数量增加了1。", async () => {
            var c1 = await contractInstance.getTokensCount(alice, 0, false, false);
            const result = await contractInstance.randToken(alice, 1, {value:minRandPayment}); 
            var c2 = await contractInstance.getTokensCount(alice, 0, false, false);
            expect(c2.sub(c1).eq(BN1)).to.be.true;
        })
        it("2.alice支付0.005 eth调用了合约方法，并将生成的token赋予了bob;bob拥有的token数量增加了1。", async () => {
            var c1 = await contractInstance.getTokensCount(bob, 0, false, false);
            const result = await contractInstance.randToken(bob, 2,{from:alice,value:minRandPayment});  
            var c2 = await contractInstance.getTokensCount(bob, 0, false, false);  
            expect(c2.sub(c1).eq(new BN(1))).to.be.true;
        })
        it("3.alice连续调用该合约方法300次，生成的200个token中，包含1-10级卡片、elite卡片和element卡片。", async () => {           
            for(var i = 0; i < 200; i++){
                contractInstance.randToken(alice, i+1,  {value:minRandPayment});
            }
            //elite
            var c1 = await contractInstance.getTokensCount(alice, 0, true, true);
            expect(c1.gt(BN0)).to.be.true;
            //element
            var c2 = await contractInstance.getTokensCount_element(alice, 0, false, true, 0);
            expect(c2.lt(new BN(300))).to.be.true;
            //level 1 
            var l = await contractInstance.getTokensCount(alice, 1, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 2, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 3, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 4, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 5, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 6, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 7, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 8, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 9, false, true);
            expect(l.gt(BN0)).to.be.true;
            l = await contractInstance.getTokensCount(alice, 10, false, true);
            expect(l.gt(BN0)).to.be.true;
        })
    })
    context("测试二：increaseNumberOfCardsInLevel。参数1类型：uint32(level)", async () => {
        it("1.alice调用了increaseNumberOfCardsInLevel(1),level 1的卡槽数量+1；接着alice连续调用200次randToken方法，希望能得到level1的第12种（新增）token", async () => {
            var c1 = await contractInstance.getNumberOfCardsInLevel(1);
            const resugt = await contractInstance.increaseNumberOfCardsInLevel(1);  
            var c2 = await contractInstance.getNumberOfCardsInLevel(1);
            expect(c2.sub(c1).eq(new BN(1))).to.be.true;
            for(var i = 0; i < 100; i++){
                contractInstance.randToken(alice, i+1,  {value:minRandPayment});
            }
            var c3 = await contractInstance.getTokensCount_indexInLevel(alice, 1, false, false, 12);
            expect(c3.gte(new BN(1))).to.be.true;           
        })
    })
    context("测试三：issueToken(address player, bool isElite, uint32 level, uint32 index, uint32 element, uint32 up, uint32 down, uint32 left, uint32 right)", async () => {
        it("1.alice（contract owner）调用了issueToken()，入参player == alice,生成的token的owner是alice", async () => {
            var tokenID = await contractInstance.issueToken(alice, false, 1, 1, 0, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.ownerOf(id);
            expect(o == alice).to.be.true; 
        })
        it("2.alice（contract owner）调用了issueToken()，入参player == bob,生成的token的owner是bob", async () => {
            var tokenID = await contractInstance.issueToken(bob, false, 1, 1, 0, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.ownerOf(id);
            expect(o == bob).to.be.true; 
        })
        it("3.alice（contract owner）调用了issueToken()，入参level == 5,生成的token的level是5", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 1, 0, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_exceptBattleValues(id);
            expect(o[0].eq(new BN(5))).to.be.true; 
        })
        it("4.alice（contract owner）调用了issueToken()，入参levelIndex == 5,生成的token的indexInLevel是5", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 0, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_exceptBattleValues(id);
            expect(o[1].eq(new BN(6))).to.be.true; 
        })
        it("5.alice（contract owner）调用了issueToken()，入参element == 7,生成的token的element是7", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_exceptBattleValues(id);
            expect(o[2].eq(new BN(7))).to.be.true; 
        })
        it("6.alice（contract owner）调用了issueToken()，入参isElite == true,生成的token的isElite是true", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 1,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_exceptBattleValues(id);
            expect(o[3]).to.be.true; 
        })
        it("7.alice（contract owner）调用了issueToken()，入参up == 8,生成的token的up是8", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 8,1,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_battleValues(id);
            expect(o[0].eq(new BN(8))).to.be.true; 
        })
        it("8.alice（contract owner）调用了issueToken()，入参down == 9,生成的token的up是9", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 8,9,1,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_battleValues(id);
            expect(o[1].eq(new BN(9))).to.be.true; 
        })
        it("9.alice（contract owner）调用了issueToken()，入参left == 10,生成的token的up是10", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 8,9,10,1);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_battleValues(id);
            expect(o[2].eq(new BN(10))).to.be.true; 
        })
        it("10.alice（contract owner）调用了issueToken()，入参right == 11,生成的token的up是11", async () => {
            var tokenID = await contractInstance.issueToken(alice, true, 5, 6, 7, 8,9,10,11);
            var id = tokenID.logs[1].args.tokenID;
            const o = await contractInstance.getItemAttributes_battleValues(id);
            expect(o[3].eq(new BN(11))).to.be.true; 
        })
    })
    context("测试四：burnAndCreate(uint256[] memory tokenIDs, uint256 seed)", async () => {
        it("1. alice调用issue()2次生成了2个1级token，然后燃烧掉。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 1, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 1, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;
            var result = await contractInstance.burnAndCreate([id1, id2], 1, {from:alice});
            expect(result.receipt.status).to.equal(true);
            
        })
        it("2. alice调用issue()3次生成了3个2级token，然后燃烧掉。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;
            var tokenID3 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id3 = tokenID3.logs[1].args.tokenID;
            var result = await contractInstance.burnAndCreate([id1, id2,id3], 1, {from:alice});
            expect(result.receipt.status).to.equal(true);
            
        })
        it("3. alice调用issue()4次生成了4个2级token，然后燃烧掉;100%生成了一张更高级的卡片", async () => {
            var l3Count = await contractInstance.getTokensCount(alice, 3, false, false);
            var tokenID1 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;
            var tokenID3 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id3 = tokenID3.logs[1].args.tokenID;
            var tokenID4 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id4 = tokenID4.logs[1].args.tokenID;
            var result = await contractInstance.burnAndCreate([id1, id2,id3, id4], 1, {from:alice});
            expect(result.receipt.status).to.equal(true);

            var l3Count2 = await contractInstance.getTokensCount(alice, 3, false, false);
            expect(l3Count2.sub(BN1).eq(l3Count)).to.be.true;
            
        })
        it("4. alice试图燃烧掉属于bob的token，但是alice失败了。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 1, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(bob, true, 1, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;            
            await utils.shouldThrow(contractInstance.burnAndCreate([id1, id2], 1, {from:alice}));         
        })
        it("5. alice试图燃烧掉不同level的token，但是alice失败了。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 1, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;            
            await utils.shouldThrow(contractInstance.burnAndCreate([id1, id2], 1, {from:alice}));           
        })
        it("6. alice试图燃烧掉单个的token，但是alice失败了。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;           
            await utils.shouldThrow(contractInstance.burnAndCreate([id1], 1, {from:alice}));          
        })
        it("7. alice试图燃烧掉5个的token，但是alice失败了。", async () => {
            var l3Count = await contractInstance.getTokensCount(alice, 3, false, false);
            var tokenID1 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;
            var tokenID3 = await contractInstance.issueToken(alice, false, 2, 1, 0, 1,1,1,1);
            var id3 = tokenID3.logs[1].args.tokenID;
            var tokenID4 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id4 = tokenID4.logs[1].args.tokenID;     
            var tokenID5 = await contractInstance.issueToken(alice, true, 2, 1, 0, 1,1,1,1);
            var id5 = tokenID4.logs[1].args.tokenID;      
            await utils.shouldThrow(contractInstance.burnAndCreate([id1,id2,id3,id4,id5], 1, {from:alice}));          
        })
        it("8. alice试图燃烧掉含最高等级token的token组，但是alice失败了。", async () => {
            var tokenID1 = await contractInstance.issueToken(alice, false, 10, 1, 0, 1,1,1,1);
            var id1 = tokenID1.logs[1].args.tokenID;
            var tokenID2 = await contractInstance.issueToken(alice, true, 1, 1, 0, 1,1,1,1);
            var id2 = tokenID2.logs[1].args.tokenID;            
            await utils.shouldThrow(contractInstance.burnAndCreate([id1, id2], 1, {from:alice}));         
        })
    })



})