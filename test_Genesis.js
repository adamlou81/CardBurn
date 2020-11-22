const { default: Web3 } = require("web3");

const Genesis = artifacts.require("Genesis");

contract("Genesis", (accounts) => {
    let [alice, bob] = accounts;
    let contractInstance;
    beforeEach(async () => {
        contractInstance = await Genesis.new();
    });


    it("随机生成一个token.", async () => {
        //const result = await contractInstance.randToken(alice, false, 2, 100, {value:Web3.utils.toWei("0.005","ether")});
        const result = await contractInstance.randToken(alice, false, 2, 100);
        assert.equal(result.receipt.status, true);
        //assert.equal(result.logs[0].args.createdTokenID, );
    })




})