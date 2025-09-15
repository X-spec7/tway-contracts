// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRewardTracking
 * @notice Interface for the RewardTracking contract
 * @dev This interface defines the external functions for managing reward distribution
 *      based on token holdings and USDC deposits
 */
interface IRewardTracking {
    // ============ Structs ============
    
    /**
     * @notice Structure to track user reward information
     * @param balance The user's current token balance
     * @param rewardDebt The user's reward debt (prevents double-claiming)
     */
    struct UserRewardTracking {
        uint256 balance;
        uint256 rewardDebt;
    }
    
    /**
     * @notice Structure to track pool information
     * @param totalTokenSold Total amount of tokens sold through IEO
     * @param accumulatedRewardPerToken Accumulated reward per token (in USDC)
     * @param lastRewardBlock Last block number when pool was updated
     */
    struct PoolInfo {
        uint256 totalTokenSold;
        uint256 accumulatedRewardPerToken;
        uint256 lastRewardBlock;
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when USDC rewards are deposited
     * @param amount The amount of USDC deposited
     * @param newAccumulatedRewardPerToken The new accumulated reward per token
     */
    event RewardDeposited(uint256 amount, uint256 newAccumulatedRewardPerToken);
    
    /**
     * @notice Emitted when a user claims rewards
     * @param user The address of the user claiming rewards
     * @param amount The amount of USDC claimed
     */
    event RewardClaimed(address indexed user, uint256 amount);
    
    /**
     * @notice Emitted when a user's balance is updated
     * @param user The address of the user
     * @param newBalance The new token balance
     * @param newRewardDebt The new reward debt
     */
    event UserBalanceUpdated(address indexed user, uint256 newBalance, uint256 newRewardDebt);
    
    /**
     * @notice Emitted when total tokens sold is updated
     * @param newTotalTokenSold The new total amount of tokens sold
     */
    event TokensSoldUpdated(uint256 newTotalTokenSold);
    
    /**
     * @notice Emitted when the IEO contract address is updated
     * @param newIEOContract The new IEO contract address
     */
    event IEOContractUpdated(address indexed newIEOContract);

    // ============ Constants ============
    
    /**
     * @notice USDC token address
     * @return The USDC token address
     */
    function USDC_ADDRESS() external view returns (address);
    
    /**
     * @notice Precision constant for calculations (1e18)
     * @return The precision constant
     */
    function PRECISION() external view returns (uint256);

    // ============ View Functions ============
    
    /**
     * @notice Returns the token address
     * @return The address of the token contract
     */
    function tokenAddress() external view returns (address);
    
    /**
     * @notice Returns the IEO contract address
     * @return The address of the IEO contract
     */
    function ieoContract() external view returns (address);
    
    /**
     * @notice Returns the owner of the contract
     * @return The address of the owner
     */
    function owner() external view returns (address);
    
    /**
     * @notice Returns the current pool information
     * @return poolInfo The current pool information
     */
    function getPoolInfo() external view returns (PoolInfo memory poolInfo);
    
    /**
     * @notice Returns the reward tracking information for a user
     * @param user The address of the user
     * @return userTracking The user's reward tracking information
     */
    function getUserRewardTracking(address user) external view returns (UserRewardTracking memory userTracking);
    
    /**
     * @notice Returns the pending reward for a user
     * @param user The address of the user
     * @return The amount of pending USDC rewards
     */
    function getPendingReward(address user) external view returns (uint256);

    // ============ State-Changing Functions ============
    
    /**
     * @notice Updates the reward pool when USDC is deposited
     * @dev This function should be called before any reward calculations
     */
    function updatePool() external;
    
    /**
     * @notice Called when tokens are sold through IEO
     * @dev Only callable by the IEO contract
     * @param user The address of the user who bought tokens
     * @param amount The amount of tokens sold
     */
    function onTokenSold(address user, uint256 amount) external;
    
    /**
     * @notice Called when tokens are transferred between users
     * @dev Only callable by the token contract
     * @param from The address tokens are transferred from
     * @param to The address tokens are transferred to
     * @param amount The amount of tokens transferred
     */
    function onTokenTransfer(address from, address to, uint256 amount) external;
    
    /**
     * @notice Allows a user to claim their pending rewards
     * @dev User must have pending rewards to claim
     */
    function claimReward() external;

    // ============ Owner Functions ============
    
    /**
     * @notice Sets the IEO contract address
     * @dev Only callable by the owner
     * @param _ieoContract The address of the IEO contract
     */
    function setIEOContract(address _ieoContract) external;
    
    /**
     * @notice Emergency function to withdraw USDC from the contract
     * @dev Only callable by the owner
     * @param amount The amount of USDC to withdraw
     */
    function emergencyWithdrawUSDC(uint256 amount) external;
    
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