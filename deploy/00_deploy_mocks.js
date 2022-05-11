const { DECIMALS, INITIAL_PRICE } = require("../helper-hardhat-config")

module.exports = async ({
  getNamedAccounts,
  deployments,
  getChainId
}) => {
  const {deploy, log} = deployments
  const {deployer} = await getNamedAccounts()
  const chainId = await getChainId()

  if (chainId == 31337) {
    log("Local network detected! Deploying Mocks...")
    const MockV3Aggregator = await deploy("MockV3Aggregator", {from: deployer, log: true, args: [DECIMALS, INITIAL_PRICE],})
    const LinkToken = await deploy('LinkToken', {from: deployer, log: true})
    const VRFCoordinatorMock = await deploy('VRFCoordinatorMock', {from: deployer, log: true, args: [LinkToken.address]})
    log("Mocks deployed!")


  }
}
module.exports.tags = ['all', 'rsvg']
