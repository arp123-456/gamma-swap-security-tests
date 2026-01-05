// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GammaSwap.sol";

/**
 * @title GammaOracle
 * @notice Price oracle for Gamma token
 * @dev VULNERABLE: Uses spot price from single DEX
 */
contract GammaOracle {
    GammaSwap public immutable gammaSwap;
    
    uint256 public lastPrice;
    uint256 public lastUpdateTime;
    
    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    
    constructor(address _gammaSwap) {
        gammaSwap = GammaSwap(_gammaSwap);
    }
    
    /**
     * @notice Get current price from DEX
     * @dev VULNERABLE: Returns spot price, can be manipulated
     */
    function getPrice() external view returns (uint256) {
        return gammaSwap.getSpotPrice();
    }
    
    /**
     * @notice Update stored price
     * @dev VULNERABLE: Can be called during manipulation
     */
    function updatePrice() external {
        lastPrice = gammaSwap.getSpotPrice();
        lastUpdateTime = block.timestamp;
        emit PriceUpdated(lastPrice, block.timestamp);
    }
    
    /**
     * @notice Get last stored price
     * @dev VULNERABLE: May be stale or manipulated
     */
    function getLastPrice() external view returns (uint256) {
        return lastPrice;
    }
    
    /**
     * @notice Check if price is fresh
     */
    function isPriceFresh(uint256 maxAge) external view returns (bool) {
        return block.timestamp - lastUpdateTime <= maxAge;
    }
}