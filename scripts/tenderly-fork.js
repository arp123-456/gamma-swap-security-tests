/**
 * Tenderly Fork Creation and Management
 * Creates a Tenderly fork for testing Gamma swap attacks
 */

const axios = require('axios');
require('dotenv').config();

const TENDERLY_API_KEY = process.env.TENDERLY_API_KEY;
const TENDERLY_USER = process.env.TENDERLY_USER;
const TENDERLY_PROJECT = process.env.TENDERLY_PROJECT;

async function createTenderlyFork() {
    console.log('🔧 Creating Tenderly fork for Gamma swap testing...\n');
    
    const forkConfig = {
        network_id: '1', // Ethereum mainnet
        block_number: 18500000, // Recent block
        chain_config: {
            chain_id: 1
        },
        alias: `gamma-swap-test-${Date.now()}`
    };
    
    try {
        const response = await axios.post(
            `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`,
            forkConfig,
            {
                headers: {
                    'X-Access-Key': TENDERLY_API_KEY,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        const fork = response.data.simulation_fork;
        
        console.log('✅ Fork created successfully!\n');
        console.log('Fork Details:');
        console.log('- Fork ID:', fork.id);
        console.log('- RPC URL:', fork.rpc_url);
        console.log('- Network:', 'Ethereum Mainnet');
        console.log('- Block:', forkConfig.block_number);
        console.log('\n📝 Add this to your .env file:');
        console.log(`TENDERLY_FORK_RPC=${fork.rpc_url}`);
        
        return fork;
    } catch (error) {
        console.error('❌ Error creating fork:', error.response?.data || error.message);
        throw error;
    }
}

async function deleteFork(forkId) {
    try {
        await axios.delete(
            `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork/${forkId}`,
            {
                headers: {
                    'X-Access-Key': TENDERLY_API_KEY
                }
            }
        );
        console.log('✅ Fork deleted successfully');
    } catch (error) {
        console.error('❌ Error deleting fork:', error.message);
    }
}

async function listForks() {
    try {
        const response = await axios.get(
            `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/forks`,
            {
                headers: {
                    'X-Access-Key': TENDERLY_API_KEY
                }
            }
        );
        
        console.log('📋 Active Forks:\n');
        response.data.simulation_forks.forEach((fork, index) => {
            console.log(`${index + 1}. ${fork.alias || fork.id}`);
            console.log(`   RPC: ${fork.rpc_url}`);
            console.log(`   Created: ${new Date(fork.created_at).toLocaleString()}\n`);
        });
        
        return response.data.simulation_forks;
    } catch (error) {
        console.error('❌ Error listing forks:', error.message);
    }
}

module.exports = {
    createTenderlyFork,
    deleteFork,
    listForks
};

// CLI usage
if (require.main === module) {
    const command = process.argv[2];
    
    switch (command) {
        case 'create':
            createTenderlyFork();
            break;
        case 'list':
            listForks();
            break;
        case 'delete':
            const forkId = process.argv[3];
            if (!forkId) {
                console.error('Usage: node tenderly-fork.js delete <fork-id>');
                process.exit(1);
            }
            deleteFork(forkId);
            break;
        default:
            console.log('Usage:');
            console.log('  node tenderly-fork.js create  - Create new fork');
            console.log('  node tenderly-fork.js list    - List active forks');
            console.log('  node tenderly-fork.js delete <fork-id> - Delete fork');
    }
}