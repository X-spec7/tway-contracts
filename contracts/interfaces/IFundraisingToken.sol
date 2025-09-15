// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IFundraisingToken
 * @author FundraisingToken Team
 * @notice Interface for the FundraisingToken contract
 * @dev This interface defines the external functions available for the ERC20 token
 *      with whitelist functionality and frozen mint authority
 */
interface IFundraisingToken {
    // ============ Events ============
    
    /**
     * @notice Emitted when an address is added to the whitelist
     * @param account The address that was whitelisted
     */
    event AddressWhitelisted(address indexed account);
    
    /**
     * @notice Emitted when an address is removed from the whitelist
     * @param account The address that was removed from whitelist
     */
    event AddressRemovedFromWhitelist(address indexed account);
    
    /**
     * @notice Emitted when the mint authority is frozen
     */
    event MintAuthorityFrozen();
    
    /**
     * @notice Emitted when the reward tracking address is updated
     * @param newAddress The new reward tracking address
     */
    event RewardTrackingAddressUpdated(address indexed newAddress);
    
    /**
     * @notice Emitted when reward tracking is enabled/disabled
     * @param enabled True if enabled, false if disabled
     */
    event RewardTrackingEnabled(bool enabled);

    // ============ View Functions ============
    
    /**
     * @notice Returns the name of the token
     * @return The name of the token
     */
    function name() external view returns (string memory);
    
    /**
     * @notice Returns the symbol of the token
     * @return The symbol of the token
     */
    function symbol() external view returns (string memory);
    
    /**
     * @notice Returns the number of decimals used to get its user representation
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);
    
    /**
     * @notice Returns the total supply of tokens
     * @return The total supply
     */
    function totalSupply() external view returns (uint256);
    
    /**
     * @notice Returns the balance of the specified address
     * @param account The address to query the balance of
     * @return The balance of the specified address
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @notice Returns the amount of tokens that an owner allowed to a spender
     * @param owner The address which owns the funds
     * @param spender The address which will spend the funds
     * @return The amount of tokens still available for the spender
     */
    function allowance(address owner, address spender) external view returns (uint256);
    
    /**
     * @notice Returns the address of the reward tracking contract
     * @return The reward tracking contract address
     */
    function rewardTrackingAddress() external view returns (address);
    
    /**
     * @notice Returns the owner of the contract
     * @return The address of the owner
     */
    function owner() external view returns (address);
    
    /**
     * @notice Returns whether the mint authority is frozen
     * @return True if mint authority is frozen, false otherwise
     */
    function isMintAuthorityFrozen() external view returns (bool);
    
    /**
     * @notice Returns whether an address is whitelisted
     * @param account The address to check
     * @return True if the address is whitelisted, false otherwise
     */
    function isWhitelisted(address account) external view returns (bool);
    
    /**
     * @notice Returns whether reward tracking is enabled
     * @return True if reward tracking is enabled, false otherwise
     */
    function isRewardTrackingEnabled() external view returns (bool);

    // ============ State-Changing Functions ============
    
    /**
     * @notice Transfers tokens from the caller to a specified address
     * @dev Both sender and recipient must be whitelisted
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return True if the transfer was successful
     */
    function transfer(address to, uint256 amount) external returns (bool);
    
    /**
     * @notice Transfers tokens from one address to another using allowance
     * @dev Both sender and recipient must be whitelisted
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param amount The amount to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    /**
     * @notice Approves a spender to spend tokens on behalf of the caller
     * @dev Both caller and spender must be whitelisted
     * @param spender The address to approve
     * @param amount The amount to approve
     * @return True if the approval was successful
     */
    function approve(address spender, uint256 amount) external returns (bool);
    
    /**
     * @notice Burns tokens from the caller's balance
     * @dev Caller must be whitelisted
     * @param amount The amount to burn
     */
    function burn(uint256 amount) external;

    // ============ Owner Functions ============
    
    /**
     * @notice Adds an address to the whitelist
     * @dev Only callable by the owner
     * @param account The address to whitelist
     */
    function addToWhitelist(address account) external;
    
    /**
     * @notice Removes an address from the whitelist
     * @dev Only callable by the owner
     * @param account The address to remove from whitelist
     */
    function removeFromWhitelist(address account) external;
    
    /**
     * @notice Adds multiple addresses to the whitelist in a single transaction
     * @dev Only callable by the owner
     * @param accounts Array of addresses to whitelist
     */
    function batchAddToWhitelist(address[] memory accounts) external;
    
    /**
     * @notice Removes multiple addresses from the whitelist in a single transaction
     * @dev Only callable by the owner
     * @param accounts Array of addresses to remove from whitelist
     */
    function batchRemoveFromWhitelist(address[] memory accounts) external;
    
    /**
     * @notice Mints new tokens to a specified address
     * @dev Only callable by the owner, and only if mint authority is not frozen
     * @param to The address to mint tokens to
     * @param amount The amount to mint
     */
    function mint(address to, uint256 amount) external;
    
    /**
     * @notice Sets the reward tracking contract address
     * @dev Only callable by the owner
     * @param _rewardTrackingAddress The address of the reward tracking contract
     */
    function setRewardTrackingAddress(address _rewardTrackingAddress) external;
    
    /**
     * @notice Transfers ownership of the contract to a new owner
     * @dev Only callable by the current owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external;
    
    /**
     * @notice Renounces ownership of the contract
     * @dev Only callable by the current owner
     */
    function renounceOwnership() external;
}