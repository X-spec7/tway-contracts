// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    uint256 public constant MOCK_PRICE = 100 * 10**18;
    uint256 public constant MOCK_DECIMALS = 18;
    
    function getPrice(address token) 
        external 
        view 
        override 
        returns (uint256 price, uint256 decimals, uint256 timestamp) 
    {
        return (MOCK_PRICE, MOCK_DECIMALS, block.timestamp);
    }
    
    function getMockPrice() external pure returns (uint256) {
        return MOCK_PRICE;
    }
    
    function getMockDecimals() external pure returns (uint256) {
        return MOCK_DECIMALS;
    }
}
