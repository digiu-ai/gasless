const  {constants, Contract, Signer, utils} = require("ethers");
const hre = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();


    const paymaster = "0x453b804eF21eB1C021ed0D6E40bFAd77655721bD"

    // const token = "0x8aAFC440A5057cF8728c1C23fd74C25314c156ac"
    // const uniswap = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

    await hre.run("verify:verify", {
        address: paymaster,
        constructorArguments: [
        ],
    })

}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
