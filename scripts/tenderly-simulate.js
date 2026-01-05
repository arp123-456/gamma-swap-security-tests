/**
 * Tenderly Transaction Simulation
 * Simulates flash loan attack on Tenderly fork
 */

const axios = require('axios');
const { ethers } = require('hardhat');
require('dotenv').config();

const TENDERLY_API_KEY = process.env.TENDERLY_API_KEY;
const TENDERLY_USER = process.env.TENDERLY_USER;
const TENDERLY_PROJECT = process.env.TENDERLY_PROJECT;

async function simulateAttack(forkId, attackParams) {
    console.log('🎯 Simulating flash loan attack on Tenderly...\n');
    
    const simulation = {
        network_id: '1',
        from: attackParams.attacker,
        to: attackParams.attackerContract,
        input: attackParams.calldata,
        gas: 8000000,
        gas_price: '0',
        value: attackParams.value || '0',
        save: true,
        save_if_fails: true,
        simulation_type: 'full'
    };
    
    try {
        const response = await axios.post(
            `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork/${forkId}/simulate`,
            simulation,
            {
                headers: {
                    'X-Access-Key': TENDERLY_API_KEY,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        const result = response.data;
        
        console.log('✅ Simulation completed!\n');
        console.log('Transaction Details:');
        console.log('- Status:', result.transaction.status ? '✅ SUCCESS' : '❌ FAILED');
        console.log('- Gas Used:', result.transaction.gas_used);
        console.log('- Block Number:', result.transaction.block_number);
        
        console.log('\nState Changes:');
        if (result.transaction.transaction_info?.state_diff) {
            const stateDiff = result.transaction.transaction_info.state_diff;
            console.log('- Contracts affected:', Object.keys(stateDiff).length);
        }
        
        console.log('\nView in Tenderly:');
        console.log(`https://dashboard.tenderly.co/${TENDERLY_USER}/${TENDERLY_PROJECT}/fork/${forkId}/simulation/${result.simulation.id}`);
        
        // Analyze attack success
        if (result.transaction.status) {
            console.log('\n🚨 ATTACK SUCCESSFUL - Vulnerability Confirmed!');
            analyzeAttackImpact(result);
        } else {
            console.log('\n✅ Attack Failed - Mitigations Working');
        }
        
        return result;
    } catch (error) {
        console.error('❌ Simulation error:', error.response?.data || error.message);
        throw error;
    }
}

function analyzeAttackImpact(simulationResult) {
    console.log('\n📊 Attack Impact Analysis:');
    
    const logs = simulationResult.transaction.transaction_info?.logs || [];
    
    // Look for price manipulation events
    const priceEvents = logs.filter(log => 
        log.name === 'PriceUpdated' || log.name === 'Swap'
    );
    
    if (priceEvents.length > 0) {
        console.log('- Price manipulation detected:', priceEvents.length, 'events');
    }
    
    // Look for borrow events
    const borrowEvents = logs.filter(log => log.name === 'Borrowed');
    if (borrowEvents.length > 0) {
        console.log('- Unauthorized borrows:', borrowEvents.length);
    }
    
    // Calculate profit
    const balanceChanges = simulationResult.transaction.transaction_info?.balance_diff || [];
    if (balanceChanges.length > 0) {
        console.log('- Balance changes detected:', balanceChanges.length);
    }
}

async function simulateGammaAttack() {
    console.log('🔧 Setting up Gamma swap attack simulation...\n');
    
    // This would be called after deploying contracts to fork
    // For now, showing the structure
    
    const attackParams = {
        attacker: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
        attackerContract: '0x...', // Deployed attacker contract
        calldata: '0x...', // executeAttack() calldata
        value: ethers.parseEther('1').toString()
    };
    
    console.log('Attack Parameters:');
    console.log('- Attacker:', attackParams.attacker);
    console.log('- Target:', 'Gamma Swap Protocol');
    console.log('- Attack Type:', 'Flash Loan Oracle Manipulation');
    
    // Simulate would be called here with actual fork ID
    console.log('\n⚠️  To run simulation:');
    console.log('1. Create fork: npm run tenderly:fork');
    console.log('2. Deploy contracts to fork');
    console.log('3. Run: node scripts/tenderly-simulate.js <fork-id>');
}

module.exports = {
    simulateAttack,
    analyzeAttackImpact
};

if (require.main === module) {
    const forkId = process.argv[2];
    
    if (!forkId) {
        simulateGammaAttack();
    } else {
        console.log('Simulation requires deployed contracts.');
        console.log('Use the test suite for full attack simulation.');
    }
}