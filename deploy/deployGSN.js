async function main() {

    const [deployer] = await ethers.getSigners();

    const portal = "0x4671dcFE18901EfB6a5ce2F86a99e8D127B86de8"
    const token = "0xe88F64665CDAD494eD75F6783f278840B00e4C00"

    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());

    // We get the contract to deploy
    const SyntF = await ethers.getContractFactory("SyntFunction");
    const syntF = await SyntF.deploy(portal, token);

    console.log("SyntFunction deployed to:", syntF.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
