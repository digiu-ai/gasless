const  {constants, Contract, Signer, utils} = require("ethers");
const hre = require("hardhat");

async function main() {

    const [deployer] = await ethers.getSigners();

    const relayHubRinkeby = "0x6650d69225CA31049DB7Bd210aE4671c0B1ca132"
    const forwarderRinkeby = "0x83A54884bE4657706785D7309cf46B58FE5f6e8a"

    const token = "0x8aAFC440A5057cF8728c1C23fd74C25314c156ac"
    const uniswap = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Paymaster = await ethers.getContractFactory("TokenPaymasterPermitPaymaster");
    const paymaster = await Paymaster.deploy();

    console.log("TokenPaymasterPermitPaymaster deployed to:", paymaster.address);

    await paymaster.setRelayHub(relayHubRinkeby)
    console.log("RelayHub set:", relayHubRinkeby);

    await paymaster.setTrustedForwarder(forwarderRinkeby, {gasLimit: 200000});
    console.log("forwarderRinkeby set:", forwarderRinkeby);

    await paymaster.addToken(token, uniswap, {gasLimit: 200000});
    console.log("Token set:", token);

    const RelayHub = await ethers.getContractFactory("RelayHub"); //todo how to get artifacts from libs
    const relayHub = RelayHub.attach(relayHubRinkeby);

    const amount =  constants.WeiPerEther.mul(2);

     await relayHub.depositFor(paymaster.address, { value: amount });
     console.log("Paymaster deposited for:", amount);

    await hre.run("verify:verify", {
        address: paymaster.address,
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
