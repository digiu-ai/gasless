const { expect } = require("chai");
const {constants, utils} = require("ethers");


describe("Greeter", function() {
  it("Should test Paymaster", async function() {

    let alp888 = "0x8aAFC440A5057cF8728c1C23fd74C25314c156ac"
    let uniswapRinkeby = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

    const Paymaster = await ethers.getContractFactory("TokenPaymasterPermitPaymaster");
    const paymaster = await Paymaster.deploy(uniswapRinkeby, alp888);

    console.log("TokenPaymasterPermitPaymaster deployed to:", paymaster.address);

    await paymaster.deployed();
    const ethAmount =  constants.WeiPerEther.mul(1)/10000;
    var tx = await paymaster.getTokenToEthOutputPrice(ethAmount)
    console.log("Token Precharge will be", tx)

  });
});
