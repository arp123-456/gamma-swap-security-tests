// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./GammaSwap.sol";

/**
 * @title SecureGammaOracle
 * @notice Hardened oracle with multiple protections against manipulation
 */
contract SecureGammaOracle {
    GammaSwap public immutable gammaSwap;
    AggregatorV3Interface public immutable chainlinkFeed;
    
    // TWAP configuration
    uint32 public constant TWAP_WINDOW = 1800; // 30 minutes
    uint256 public constant MAX_PRICE_DEVIATION = 500; // 5%
    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour
    
    struct Observation {
        uint256 timestamp;
        uint256 price;
        uint256 cumulativePrice;
    }
    
    Observation[] public observations;
    uint256 public lastObservationIndex;
    
    event PriceUpdated(uint256 spotPrice, uint256 twapPrice, uint256 chainlinkPrice);
    event PriceDeviationDetected(uint256 deviation);
    
    constructor(address _gammaSwap, address _chainlinkFeed) {
        gammaSwap = GammaSwap(_gammaSwap);
        chainlinkFeed = AggregatorV3Interface(_chainlinkFeed);
        
        // Initialize first observation
        observations.push(Observation({
            timestamp: block.timestamp,
            price: gammaSwap.getSpotPrice(),
            cumulativePrice: 0
        }));
    }
    
    /**
     * @notice Get secure price with multiple validations
     * @return price Validated price
     */
    function getPrice() external view returns (uint256 price) {
        uint256 twapPrice = getTWAP();
        uint256 chainlinkPrice = getChainlinkPrice();
        uint256 spotPrice = gammaSwap.getSpotPrice();
        
        // Use TWAP as primary, validate against Chainlink
        price = twapPrice;
        
        // Check deviation from Chainlink
        uint256 deviation = abs(twapPrice, chainlinkPrice) * 10000 / chainlinkPrice;
        require(deviation < MAX_PRICE_DEVIATION, "Price deviation too high");
        
        // Check deviation from spot
        uint256 spotDeviation = abs(twapPrice, spotPrice) * 10000 / spotPrice;
        if (spotDeviation > MAX_PRICE_DEVIATION * 2) {
            // If spot deviates significantly, possible manipulation
            // Use Chainlink as fallback
            price = chainlinkPrice;
        }
        
        return price;
    }
    
    /**
     * @notice Get Time-Weighted Average Price
     */
    function getTWAP() public view returns (uint256) {
        require(observations.length > 0, "No observations");
        
        uint256 currentTime = block.timestamp;
        Observation memory latest = observations[observations.length - 1];
        
        // If not enough time has passed, return latest price
        if (currentTime - latest.timestamp < TWAP_WINDOW) {
            return latest.price;
        }
        
        // Find observation from TWAP_WINDOW ago
        uint256 targetTime = currentTime - TWAP_WINDOW;
        Observation memory old = findObservation(targetTime);
        
        // Calculate TWAP
        uint256 timeDelta = latest.timestamp - old.timestamp;
        uint256 priceDelta = latest.cumulativePrice - old.cumulativePrice;
        
        return priceDelta / timeDelta;
    }
    
    /**
     * @notice Get price from Chainlink
     */
    function getChainlinkPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 price,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = chainlinkFeed.latestRoundData();
        
        require(price > 0, "Invalid Chainlink price");
        require(answeredInRound >= roundId, "Stale Chainlink data");
        require(block.timestamp - updatedAt < MAX_PRICE_AGE, "Chainlink price too old");
        
        return uint256(price);
    }
    
    /**
     * @notice Update price observation
     * @dev Should be called regularly to maintain TWAP
     */
    function updatePrice() external {
        uint256 currentPrice = gammaSwap.getSpotPrice();
        Observation memory latest = observations[observations.length - 1];
        
        uint256 timeDelta = block.timestamp - latest.timestamp;
        uint256 newCumulativePrice = latest.cumulativePrice + (currentPrice * timeDelta);
        
        observations.push(Observation({
            timestamp: block.timestamp,
            price: currentPrice,
            cumulativePrice: newCumulativePrice
        }));
        
        // Keep only last 24 hours of observations
        if (observations.length > 48) { // ~30 min intervals
            // Remove old observations (simplified, in production use circular buffer)
            delete observations[0];
        }
        
        emit PriceUpdated(currentPrice, getTWAP(), getChainlinkPrice());
    }
    
    /**
     * @notice Find observation closest to target time
     */
    function findObservation(uint256 targetTime) internal view returns (Observation memory) {
        for (uint256 i = observations.length - 1; i > 0; i--) {
            if (observations[i].timestamp <= targetTime) {
                return observations[i];
            }
        }
        return observations[0];
    }
    
    /**
     * @notice Calculate absolute difference
     */
    function abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
    
    /**
     * @notice Get observation count
     */
    function getObservationCount() external view returns (uint256) {
        return observations.length;
    }
}