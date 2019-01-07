const token = artifacts.require("WinWinCoinToken")
const whitelist = artifacts.require("WinWinCoinWhitelist")
const crowdsale = artifacts.require("WinWinCoinCrowdsale")

module.exports = (deployer) => {
    var wallet = "0x3dc8E9F63f857b4F6A014F741A2A95A8d3290fb6";

    return deployer.then(async () => {
        await deployer.deploy(token)
        await deployer.deploy(whitelist)
        await deployer.deploy(
            crowdsale,
            wallet,
            token.address,
            whitelist.address
        )        
        const tokenContract = await token.deployed()
        await tokenContract.freeze()
        await tokenContract.transferOwnership(crowdsale.address)
    })
}