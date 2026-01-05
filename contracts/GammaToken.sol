// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GammaToken
 * @notice ERC20 token for Gamma swap protocol
 */
contract GammaToken is ERC20, Ownable {
    constructor() ERC20("Gamma Token", "GAMMA") Ownable(msg.sender) {
        _mint(msg.sender, 10_000_000 * 10**18); // 10M tokens
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}