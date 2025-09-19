// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPriceOracle {
    /**
     * @notice Gets the current price and timestamp for a token
     * @param token The token address to get price for
     * @return price The current price of the token
     * @return decimals The number of decimals for the price
     * @return timestamp The timestamp when this price was last updated
     */
    function getPrice(address token) external view returns (uint256 price, uint256 decimals, uint256 timestamp);
}