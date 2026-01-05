// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GammaSwap
 * @notice Simple AMM DEX for Gamma token (GAMMA/ETH pair)
 * @dev Constant product formula: x * y = k
 */
contract GammaSwap is ReentrancyGuard {
    IERC20 public immutable gammaToken;
    
    uint256 public reserveGamma;
    uint256 public reserveETH;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;
    
    event LiquidityAdded(address indexed provider, uint256 gammaAmount, uint256 ethAmount);
    event LiquidityRemoved(address indexed provider, uint256 gammaAmount, uint256 ethAmount);
    event Swap(address indexed user, uint256 gammaIn, uint256 ethIn, uint256 gammaOut, uint256 ethOut);
    
    constructor(address _gammaToken) {
        gammaToken = IERC20(_gammaToken);
    }
    
    /**
     * @notice Add liquidity to the pool
     */
    function addLiquidity(uint256 gammaAmount) external payable nonReentrant returns (uint256 liquidityMinted) {
        require(gammaAmount > 0 && msg.value > 0, "Invalid amounts");
        
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(gammaAmount * msg.value);
            require(liquidityMinted > MINIMUM_LIQUIDITY, "Insufficient liquidity");
        } else {
            uint256 liquidityFromGamma = (gammaAmount * totalLiquidity) / reserveGamma;
            uint256 liquidityFromETH = (msg.value * totalLiquidity) / reserveETH;
            liquidityMinted = min(liquidityFromGamma, liquidityFromETH);
        }
        
        require(gammaToken.transferFrom(msg.sender, address(this), gammaAmount), "Transfer failed");
        
        reserveGamma += gammaAmount;
        reserveETH += msg.value;
        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += liquidityMinted;
        
        emit LiquidityAdded(msg.sender, gammaAmount, msg.value);
    }
    
    /**
     * @notice Remove liquidity from the pool
     */
    function removeLiquidity(uint256 liquidityAmount) external nonReentrant returns (uint256 gammaAmount, uint256 ethAmount) {
        require(liquidityAmount > 0 && liquidity[msg.sender] >= liquidityAmount, "Invalid liquidity");
        
        gammaAmount = (liquidityAmount * reserveGamma) / totalLiquidity;
        ethAmount = (liquidityAmount * reserveETH) / totalLiquidity;
        
        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        reserveGamma -= gammaAmount;
        reserveETH -= ethAmount;
        
        require(gammaToken.transfer(msg.sender, gammaAmount), "Transfer failed");
        (bool success,) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit LiquidityRemoved(msg.sender, gammaAmount, ethAmount);
    }
    
    /**
     * @notice Swap GAMMA for ETH
     * @dev VULNERABLE: No slippage protection, can be manipulated
     */
    function swapGammaForETH(uint256 gammaIn) external nonReentrant returns (uint256 ethOut) {
        require(gammaIn > 0, "Invalid input");
        
        // Calculate output with 0.3% fee
        uint256 gammaInWithFee = gammaIn * 997;
        ethOut = (gammaInWithFee * reserveETH) / (reserveGamma * 1000 + gammaInWithFee);
        
        require(ethOut > 0 && ethOut < reserveETH, "Insufficient output");
        
        require(gammaToken.transferFrom(msg.sender, address(this), gammaIn), "Transfer failed");
        
        reserveGamma += gammaIn;
        reserveETH -= ethOut;
        
        (bool success,) = msg.sender.call{value: ethOut}("");
        require(success, "ETH transfer failed");
        
        emit Swap(msg.sender, gammaIn, 0, 0, ethOut);
    }
    
    /**
     * @notice Swap ETH for GAMMA
     * @dev VULNERABLE: No slippage protection, can be manipulated
     */
    function swapETHForGamma() external payable nonReentrant returns (uint256 gammaOut) {
        require(msg.value > 0, "Invalid input");
        
        // Calculate output with 0.3% fee
        uint256 ethInWithFee = msg.value * 997;
        gammaOut = (ethInWithFee * reserveGamma) / (reserveETH * 1000 + ethInWithFee);
        
        require(gammaOut > 0 && gammaOut < reserveGamma, "Insufficient output");
        
        reserveETH += msg.value;
        reserveGamma -= gammaOut;
        
        require(gammaToken.transfer(msg.sender, gammaOut), "Transfer failed");
        
        emit Swap(msg.sender, 0, msg.value, gammaOut, 0);
    }
    
    /**
     * @notice Get current spot price (GAMMA per ETH)
     * @dev VULNERABLE: Can be manipulated in single transaction
     */
    function getSpotPrice() external view returns (uint256) {
        require(reserveETH > 0, "No liquidity");
        return (reserveGamma * 1e18) / reserveETH;
    }
    
    /**
     * @notice Get reserves
     */
    function getReserves() external view returns (uint256, uint256) {
        return (reserveGamma, reserveETH);
    }
    
    // Helper functions
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    receive() external payable {}
}