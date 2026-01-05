require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();

module.exports = {
    solidity: {
        version: '0.8.20',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            },
            viaIR: true
        }
    },
    networks: {
        hardhat: {
            forking: {
                url: process.env.MAINNET_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/demo',
                enabled: true,
                blockNumber: 18500000
            },
            chainId: 1,
            accounts: {
                count: 10,
                accountsBalance: '10000000000000000000000'
            }
        },
        tenderly: {
            url: process.env.TENDERLY_FORK_RPC || 'http://localhost:8545',
            chainId: 1
        },
        sepolia: {
            url: process.env.SEPOLIA_RPC_URL || '',
            accounts: process.env.PRIVATE_KEY_ATTACKER ? [process.env.PRIVATE_KEY_ATTACKER] : []
        }
    },
    tenderly: {
        project: process.env.TENDERLY_PROJECT || '',
        username: process.env.TENDERLY_USER || '',
        privateVerification: false
    },
    gasReporter: {
        enabled: true,
        currency: 'USD',
        coinmarketcap: process.env.COINMARKETCAP_API_KEY
    },
    mocha: {
        timeout: 100000
    }
};