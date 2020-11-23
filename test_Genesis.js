const Genesis = artifacts.require("Genesis");

contract("Genesis", (accounts) => {
    let [alice, bob] = accounts;
    let contractInstance;
    beforeEach(async () => {
        contractInstance = await Genesis.new();
    });

    context("测试：randToken(address player, bool isElite, uint32 level, uint256 seed) public payable returns (uint256)", async () => {
        it("randToken合约方法调用成功", async () => {
            const result = await contractInstance.test_randToken(alice, {value:Web3.utils.toWei("0.005","ether")});    
            assert.equal(result.receipt.status, true);
        })
        // it("支付的ETH不足，合约方法调用失败", async () => {
        //     const result = await contractInstance.randToken(alice, false, 2, 100, {value:Web3.utils.toWei("0.004","ether")});    
        //     assert.equal(result.receipt.status, false);
        // })
        // it("should approve and then transfer a zombie when the owner calls transferFrom", async () => {
        //     const result = await contractInstance.createRandomZombie(zombieNames[0], {from: alice});
        //     const zombieId = result.logs[0].args.zombieId.toNumber();
        //     await contractInstance.approve(bob, zombieId, {from: alice});
        //     await contractInstance.transferFrom(alice, bob, zombieId, {from: alice});
        //     const newOwner = await contractInstance.ownerOf(zombieId);
        //     expect(newOwner).to.equal(bob);
        //  })
    })




    // it("随机生成一个token.", async () => {
    //     //const result = await contractInstance.randToken(alice, false, 2, 100, {value:Web3.utils.toWei("0.005","ether")});
    //     const result = await contractInstance.randToken(alice, false, 2, 100);
    //     assert.equal(result.receipt.status, true);
    //     //assert.equal(result.logs[0].args.createdTokenID, );
    // })




})