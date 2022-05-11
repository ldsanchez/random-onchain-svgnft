require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")
require('hardhat-deploy')

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

require('dotenv').config()
const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL
const KOVAN_RPC_URL = process.env.KOVAN_RPC_URL
const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL
const MNEMONIC = process.env.MNEMONIC
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // allowUnlimitedContractSize: true
    },
    rinkeby: {
      url: RINKEBY_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC
      },
      saveDeployments: true
    },
    kovan: {
      url: KOVAN_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC
      },
      saveDeployments: true
    },
    polygon: {
      url: POLYGON_RPC_URL,
      accounts: {
        mnemonic: MNEMONIC
      },
      saveDeployments: true
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  solidity: {
    compilers: [
      {version: "0.8.13", 
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }, {version: "0.4.24"}, {version: "0.6.6"} ]}
  ,
  namedAccounts: {
    deployer: {
      default: 0 // first account
    }
  }
};
