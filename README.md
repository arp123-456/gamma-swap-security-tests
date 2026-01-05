# Gamma Swap Security Testing Suite

## Overview
Comprehensive flash loan oracle manipulation security testing for Gamma token and Gamma swap protocol using Tenderly simulation and Remix IDE.

## 🎯 Testing Focus

### Flash Loan Oracle Manipulation Vulnerabilities
This suite tests various oracle manipulation attack vectors on the Gamma swap protocol:

1. **Spot Price Manipulation** - Single DEX price manipulation
2. **Multi-Pool Manipulation** - Coordinated attacks across pools
3. **Sandwich Attacks** - Front-running with price manipulation
4. **Read-Only Reentrancy** - Exploiting view functions during callbacks
5. **TWAP Manipulation** - Time-weighted average price attacks

## 🏗️ Architecture

```
Gamma Swap Protocol
├── GammaToken.sol (ERC20)
├── GammaSwap.sol (AMM DEX)
├── GammaOracle.sol (Price Oracle - VULNERABLE)
├── GammaLending.sol (Lending Protocol using Oracle)
└── SecureGammaOracle.sol (Hardened Oracle)
```

## 🚨 Vulnerabilities Tested

### 1. Spot Price Oracle Manipulation
**Attack Vector:**
- Flash loan large amount of tokens
- Swap on Gamma swap to manipulate spot price
- Oracle reads manipulated price
- Exploit lending protocol with inflated collateral value
- Reverse swap and repay flash loan

**Impact:** Critical - Can drain lending protocol

### 2. Read-Only Reentrancy
**Attack Vector:**
- During swap callback, call oracle's view function
- Oracle returns stale/manipulated price
- Use manipulated price for exploit
- Complete swap

**Impact:** High - Bypass reentrancy guards

### 3. TWAP Manipulation
**Attack Vector:**
- Sustained price manipulation over multiple blocks
- Manipulate time-weighted average
- Exploit protocols relying on TWAP

**Impact:** Medium - Requires sustained attack

## 📦 Installation

```bash
# Clone repository
git clone https://github.com/arp123-456/gamma-swap-security-tests.git
cd gamma-swap-security-tests

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Configure Tenderly credentials in .env
```

## 🔧 Configuration

Edit `.env` file:
```bash
TENDERLY_API_KEY=your_tenderly_api_key
TENDERLY_USER=your_tenderly_username
TENDERLY_PROJECT=your_project_name
MAINNET_RPC_URL=your_alchemy_or_infura_url
```

## 🧪 Running Tests

### All Tests
```bash
npm test
```

### Specific Test Suites
```bash
# Flash loan oracle manipulation
npm run test:flashloan

# Read-only reentrancy
npm run test:reentrancy

# TWAP manipulation
npm run test:twap

# Comprehensive security audit
npm run test:audit
```

### Tenderly Simulation
```bash
# Create Tenderly fork
npm run tenderly:fork

# Run attack simulation on fork
npm run tenderly:simulate

# Analyze transaction traces
npm run tenderly:analyze
```

## 🎨 Remix IDE Testing

### Step 1: Deploy Contracts
1. Open [Remix IDE](https://remix.ethereum.org)
2. Copy contracts from `contracts/` folder
3. Compile with Solidity 0.8.20
4. Deploy in order:
   - GammaToken
   - GammaSwap (pass GammaToken address)
   - GammaOracle (pass GammaSwap address)
   - GammaLending (pass GammaToken and GammaOracle addresses)

### Step 2: Setup Initial Liquidity
```javascript
// Add liquidity to Gamma swap
gammaToken.approve(gammaSwap.address, 1000000 * 10**18);
gammaSwap.addLiquidity(1000000 * 10**18, {value: 100 * 10**18});
```

### Step 3: Execute Attack
1. Deploy `FlashLoanAttacker` contract
2. Fund attacker with tokens
3. Call `executeFlashLoanAttack()`
4. Observe price manipulation and profit

### Step 4: Verify Exploit
```javascript
// Check oracle price before attack
uint256 priceBefore = gammaOracle.getPrice();

// Execute attack
attacker.executeFlashLoanAttack();

// Check oracle price during attack
uint256 priceDuring = gammaOracle.getPrice();

// Verify manipulation
assert(priceDuring != priceBefore);
```

## 📊 Test Scenarios

### Scenario 1: Basic Flash Loan Attack
```
Initial State:
- Pool: 1,000,000 GAMMA / 100 ETH
- Price: 1 GAMMA = 0.0001 ETH

Attack:
1. Flash loan 5,000,000 GAMMA
2. Swap 5,000,000 GAMMA → ETH
3. Price drops to 1 GAMMA = 0.00001 ETH (90% drop)
4. Borrow max ETH from lending protocol
5. Reverse swap
6. Repay flash loan

Result:
- Profit: ~50 ETH
- Protocol loss: ~50 ETH
```

### Scenario 2: Multi-Block TWAP Manipulation
```
Block 1-10: Gradually manipulate price upward
Block 11: TWAP reflects manipulated average
Block 12: Exploit lending protocol
Block 13: Reverse manipulation
```

### Scenario 3: Read-Only Reentrancy
```
1. Call swap() function
2. During callback, call oracle.getPrice()
3. Oracle returns stale price (before swap completes)
4. Use stale price for exploit
5. Complete swap
```

## 🛡️ Mitigation Strategies

### 1. Use Chainlink Price Feeds
```solidity
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

function getSecurePrice() external view returns (uint256) {
    (, int256 price,,,) = priceFeed.latestRoundData();
    require(price > 0, "Invalid price");
    return uint256(price);
}
```

### 2. Implement TWAP with Sufficient Window
```solidity
uint32 constant TWAP_WINDOW = 1800; // 30 minutes

function getTWAP() external view returns (uint256) {
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = TWAP_WINDOW;
    secondsAgos[1] = 0;
    
    (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
    int56 avgTick = (tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(TWAP_WINDOW));
    
    return getQuoteAtTick(int24(avgTick));
}
```

### 3. Add Reentrancy Guards
```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureGammaOracle is ReentrancyGuard {
    function getPrice() external view nonReentrant returns (uint256) {
        // Price calculation
    }
}
```

### 4. Price Deviation Checks
```solidity
function validatePrice(uint256 newPrice) internal view {
    uint256 oldPrice = lastPrice;
    uint256 deviation = abs(newPrice - oldPrice) * 10000 / oldPrice;
    require(deviation < MAX_DEVIATION, "Price deviation too high");
}
```

### 5. Multi-Oracle Validation
```solidity
function getValidatedPrice() external view returns (uint256) {
    uint256 chainlinkPrice = getChainlinkPrice();
    uint256 uniswapTWAP = getUniswapTWAP();
    uint256 gammaPrice = getGammaSpotPrice();
    
    // Use median of three sources
    return median(chainlinkPrice, uniswapTWAP, gammaPrice);
}
```

## 📈 Expected Test Results

### Vulnerable Oracle Results
```
✓ Flash loan attack successful
  - Price manipulated: 90% drop
  - Attacker profit: 50 ETH
  - Protocol loss: 50 ETH
  - Attack duration: 1 block

✓ Read-only reentrancy successful
  - Stale price exploited
  - Attacker profit: 25 ETH
  
✗ TWAP manipulation (requires 30+ blocks)
```

### Secure Oracle Results
```
✗ Flash loan attack prevented
  - TWAP not affected by single block
  - Price deviation check triggered
  
✗ Read-only reentrancy prevented
  - Reentrancy guard active
  
✗ Multi-oracle validation passed
  - Chainlink price used as fallback
```

## 🔍 Tenderly Analysis Features

### Transaction Simulation
- Step-by-step execution trace
- State changes visualization
- Gas usage analysis
- Event logs inspection

### Debugger
- Line-by-line contract execution
- Variable inspection at each step
- Call stack analysis
- Storage slot changes

### Fork Testing
- Test on mainnet fork without spending real ETH
- Simulate large flash loans
- Test with real liquidity pools
- Analyze attack profitability

## 📚 Tools & Resources

### Testing Tools
- **Hardhat** - Smart contract development framework
- **Tenderly** - Transaction simulation and debugging
- **Remix IDE** - Browser-based Solidity IDE
- **Foundry** - Fast Solidity testing framework (optional)

### Security Resources
- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Sigma Prime Solidity Security](https://blog.sigmaprime.io/solidity-security.html)
- [Trail of Bits Security Guide](https://github.com/crytic/building-secure-contracts)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/4.x/api/security)

### Real Attack Examples
- **Cream Finance** - $130M oracle manipulation (Oct 2021)
- **Inverse Finance** - $15M TWAP manipulation (Apr 2022)
- **Mango Markets** - $110M oracle manipulation (Oct 2022)
- **Euler Finance** - $197M flash loan attack (Mar 2023)

## ⚠️ Security Warnings

1. **Never use spot price from single DEX** - Always use TWAP or Chainlink
2. **Always validate oracle prices** - Check freshness, deviation, and multiple sources
3. **Implement reentrancy guards** - Protect all state-changing functions
4. **Test with realistic attack scenarios** - Use mainnet fork with actual liquidity
5. **Get professional audit** - These tests don't replace professional security audit

## 🚀 Quick Start Guide

### 1. Local Testing
```bash
npm install
npm test
```

### 2. Tenderly Simulation
```bash
# Setup Tenderly
npm run tenderly:setup

# Run simulation
npm run tenderly:simulate
```

### 3. Remix Testing
1. Copy contracts to Remix
2. Deploy on Remix VM
3. Execute attack scenarios
4. Analyze results

## 📝 Test Reports

After running tests, reports are generated in:
- `reports/security-audit.json` - Comprehensive audit results
- `reports/attack-simulations.json` - Attack scenario results
- `reports/tenderly-traces/` - Transaction traces from Tenderly

## 🤝 Contributing

Found a vulnerability? Want to add more test scenarios?
1. Fork the repository
2. Create feature branch
3. Add tests and documentation
4. Submit pull request

## 📄 License

MIT License - Educational purposes only

## ⚠️ Disclaimer

**These contracts contain intentional vulnerabilities for educational and testing purposes. DO NOT deploy to mainnet or use with real funds!**

---

**Repository:** https://github.com/arp123-456/gamma-swap-security-tests
**Documentation:** [Full Docs](./docs/)
**Issues:** [Report Issues](https://github.com/arp123-456/gamma-swap-security-tests/issues)