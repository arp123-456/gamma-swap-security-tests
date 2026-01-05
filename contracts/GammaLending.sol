// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GammaOracle.sol";

/**
 * @title GammaLending
 * @notice Lending protocol using Gamma oracle for collateral valuation
 * @dev VULNERABLE: Uses manipulable oracle for critical operations
 */
contract GammaLending is ReentrancyGuard {
    IERC20 public immutable gammaToken;
    GammaOracle public immutable oracle;
    
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization
    uint256 public constant LIQUIDATION_THRESHOLD = 120; // 120% liquidation threshold
    
    struct Position {
        uint256 collateralAmount; // GAMMA tokens
        uint256 borrowedAmount;    // ETH borrowed
    }
    
    mapping(address => Position) public positions;
    uint256 public totalBorrowed;
    
    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 amount);
    
    constructor(address _gammaToken, address _oracle) {
        gammaToken = IERC20(_gammaToken);
        oracle = GammaOracle(_oracle);
    }
    
    /**
     * @notice Deposit GAMMA as collateral
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(gammaToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        positions[msg.sender].collateralAmount += amount;
        emit Deposited(msg.sender, amount);
    }
    
    /**
     * @notice Borrow ETH against GAMMA collateral
     * @dev VULNERABLE: Uses manipulable oracle price
     */
    function borrow(uint256 ethAmount) external nonReentrant {
        require(ethAmount > 0, "Invalid amount");
        require(address(this).balance >= ethAmount, "Insufficient liquidity");
        
        Position storage pos = positions[msg.sender];
        require(pos.collateralAmount > 0, "No collateral");
        
        // VULNERABILITY: Oracle price can be manipulated
        uint256 gammaPrice = oracle.getPrice(); // GAMMA per ETH
        uint256 collateralValueInETH = (pos.collateralAmount * 1e18) / gammaPrice;
        
        uint256 maxBorrow = (collateralValueInETH * 100) / COLLATERAL_RATIO;
        uint256 newTotalBorrowed = pos.borrowedAmount + ethAmount;
        
        require(newTotalBorrowed <= maxBorrow, "Insufficient collateral");
        
        pos.borrowedAmount = newTotalBorrowed;
        totalBorrowed += ethAmount;
        
        (bool success,) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit Borrowed(msg.sender, ethAmount);
    }
    
    /**
     * @notice Repay borrowed ETH
     */
    function repay() external payable nonReentrant {
        Position storage pos = positions[msg.sender];
        require(pos.borrowedAmount > 0, "No debt");
        require(msg.value <= pos.borrowedAmount, "Overpayment");
        
        pos.borrowedAmount -= msg.value;
        totalBorrowed -= msg.value;
        
        emit Repaid(msg.sender, msg.value);
    }
    
    /**
     * @notice Withdraw collateral
     */
    function withdraw(uint256 amount) external nonReentrant {
        Position storage pos = positions[msg.sender];
        require(amount <= pos.collateralAmount, "Insufficient collateral");
        
        if (pos.borrowedAmount > 0) {
            uint256 gammaPrice = oracle.getPrice();
            uint256 remainingCollateralValue = ((pos.collateralAmount - amount) * 1e18) / gammaPrice;
            uint256 requiredCollateral = (pos.borrowedAmount * COLLATERAL_RATIO) / 100;
            require(remainingCollateralValue >= requiredCollateral, "Undercollateralized");
        }
        
        pos.collateralAmount -= amount;
        require(gammaToken.transfer(msg.sender, amount), "Transfer failed");
    }
    
    /**
     * @notice Liquidate undercollateralized position
     * @dev VULNERABLE: Can be exploited with price manipulation
     */
    function liquidate(address user) external nonReentrant {
        Position storage pos = positions[user];
        require(pos.borrowedAmount > 0, "No debt");
        
        uint256 gammaPrice = oracle.getPrice();
        uint256 collateralValueInETH = (pos.collateralAmount * 1e18) / gammaPrice;
        uint256 collateralRatio = (collateralValueInETH * 100) / pos.borrowedAmount;
        
        require(collateralRatio < LIQUIDATION_THRESHOLD, "Position healthy");
        
        // Liquidator gets collateral at discount
        uint256 liquidationAmount = pos.borrowedAmount;
        uint256 collateralToLiquidator = pos.collateralAmount;
        
        pos.collateralAmount = 0;
        pos.borrowedAmount = 0;
        totalBorrowed -= liquidationAmount;
        
        require(gammaToken.transfer(msg.sender, collateralToLiquidator), "Transfer failed");
        
        emit Liquidated(user, msg.sender, liquidationAmount);
    }
    
    /**
     * @notice Get position health
     */
    function getPositionHealth(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.borrowedAmount == 0) return type(uint256).max;
        
        uint256 gammaPrice = oracle.getPrice();
        uint256 collateralValueInETH = (pos.collateralAmount * 1e18) / gammaPrice;
        return (collateralValueInETH * 100) / pos.borrowedAmount;
    }
    
    receive() external payable {}
}