// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IIEO
 * @author FundraisingToken Team
 * @notice Interface for the IEO (Initial Exchange Offering) contract
 * @dev This interface defines the external functions for managing token sales
 *      with price oracle integration and time-based controls
 */
interface IIEO {
    // ============ Structs ============
    
    /**
     * @notice Structure to track user investment information
     * @param usdcAmount The amount of USDC invested
     * @param tokenAmount The amount of tokens purchased
     * @param investmentTime The timestamp when the investment was made
     * @param claimed Whether the tokens have been claimed
     * @param refunded Whether the investment has been refunded
     */
    struct Investment {
        uint256 usdcAmount;
        uint256 tokenAmount;
        uint256 investmentTime;
        bool claimed;
        bool refunded;
    }

    // ============ Events ============
    
    /**
     * @notice Emitted when IEO starts
     * @param startTime The timestamp when IEO started
     * @param endTime The timestamp when IEO ends
     */
    event IEOStarted(uint256 startTime, uint256 endTime);
    
    /**
     * @notice Emitted when IEO ends
     * @param totalRaised The total amount of USDC raised
     * @param totalTokensSold The total amount of tokens sold
     */
    event IEOEnded(uint256 totalRaised, uint256 totalTokensSold);
    
    /**
     * @notice Emitted when an investment is made
     * @param investor The address of the investor
     * @param usdcAmount The amount of USDC invested
     * @param tokenAmount The amount of tokens purchased
     */
    event InvestmentMade(address indexed investor, uint256 usdcAmount, uint256 tokenAmount);
    
    /**
     * @notice Emitted when tokens are claimed
     * @param investor The address of the investor
     * @param tokenAmount The amount of tokens claimed
     */
    event TokensClaimed(address indexed investor, uint256 tokenAmount);
    
    /**
     * @notice Emitted when an investment is refunded
     * @param investor The address of the investor
     * @param usdcAmount The amount of USDC refunded
     */
    event InvestmentRefunded(address indexed investor, uint256 usdcAmount);
    
    /**
     * @notice Emitted when the price oracle is updated
     * @param newOracle The address of the new price oracle
     */
    event PriceOracleUpdated(address indexed newOracle);
    
    /**
     * @notice Emitted when the admin is updated
     * @param newAdmin The address of the new admin
     */
    event AdminUpdated(address indexed newAdmin);
    
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
    
    /**
     * @notice Emitted when USDC is withdrawn by business admin
     * @param businessAdmin The address of the business admin
     * @param amount The amount of USDC withdrawn
     */
    event USDCWithdrawn(address indexed businessAdmin, uint256 amount);
    
    /**
     * @notice Emitted when price validation is updated
     * @param minPrice The minimum acceptable token price
     * @param maxPrice The maximum acceptable token price
     * @param enabled Whether price validation is enabled
     */
    event PriceValidationUpdated(uint256 minPrice, uint256 maxPrice, bool enabled);

    /**
     * @notice Emitted when circuit breaker is updated
     * @param stalenessThreshold The staleness threshold in seconds
     * @param maxDeviation The maximum price deviation percentage
     * @param enabled Whether circuit breaker is enabled
     */
    event CircuitBreakerUpdated(uint256 stalenessThreshold, uint256 maxDeviation, bool enabled);

    /**
     * @notice Emitted when circuit breaker is triggered
     * @param reason The reason for triggering
     */
    event CircuitBreakerTriggered(string reason);

    /**
     * @notice Emitted when circuit breaker is reset
     */
    event CircuitBreakerReset();

    /**
     * @notice Emitted when circuit breaker is enabled/disabled
     * @param enabled True if enabled, false if disabled
     */
    event CircuitBreakerEnabled(bool enabled);

    /**
     * @notice Emitted when IEO is paused
     */
    event IEOpaused();

    /**
     * @notice Emitted when IEO is unpaused
     */
    event IEOunpaused();

    // ============ Constants ============
    
    /**
     * @notice Returns the USDC token address
     * @return The USDC token address
     */
    function USDC_ADDRESS() external view returns (address);
    
    /**
     * @notice Returns the claim delay period
     * @return The claim delay in seconds
     */
    function CLAIM_DELAY() external view returns (uint256);
    
    /**
     * @notice Returns the refund period
     * @return The refund period in seconds
     */
    function REFUND_PERIOD() external view returns (uint256);
    
    /**
     * @notice Returns the minimum investment amount
     * @return The minimum investment amount in USDC
     */
    function MIN_INVESTMENT() external view returns (uint256);
    
    /**
     * @notice Returns the maximum investment amount
     * @return The maximum investment amount in USDC
     */
    function MAX_INVESTMENT() external view returns (uint256);

    // ============ View Functions ============
    
    /**
     * @notice Returns the token contract address
     * @return The token contract address
     */
    function tokenAddress() external view returns (address);
    
    /**
     * @notice Returns the reward tracking contract address
     * @return The reward tracking contract address
     */
    function rewardTrackingAddress() external view returns (address);
    
    /**
     * @notice Returns the price oracle address
     * @return The price oracle address
     */
    function priceOracle() external view returns (address);
    
    /**
     * @notice Returns the admin address
     * @return The admin address
     */
    function admin() external view returns (address);
    
    /**
     * @notice Returns the owner address
     * @return The owner address
     */
    function owner() external view returns (address);
    
    /**
     * @notice Returns whether the IEO is active
     * @return True if IEO is active, false otherwise
     */
    function isIEOActive() external view returns (bool);
    
    /**
     * @notice Returns whether the IEO is paused
     * @return True if IEO is paused, false otherwise
     */
    function isPaused() external view returns (bool);
    
    /**
     * @notice Returns the IEO start time
     * @return The IEO start timestamp
     */
    function ieoStartTime() external view returns (uint256);
    
    /**
     * @notice Returns the IEO end time
     * @return The IEO end timestamp
     */
    function ieoEndTime() external view returns (uint256);
    
    /**
     * @notice Returns the total amount raised
     * @return The total USDC raised
     */
    function totalRaised() external view returns (uint256);
    
    /**
     * @notice Returns the total tokens sold
     * @return The total tokens sold
     */
    function totalTokensSold() external view returns (uint256);
    
    /**
     * @notice Returns whether reward tracking is enabled
     * @return True if reward tracking is enabled, false otherwise
     */
    function isRewardTrackingEnabled() external view returns (bool);
    
    /**
     * @notice Returns investment information for a specific investor (latest investment for backward compatibility)
     * @param investor The address of the investor
     * @return investment The latest investment information
     */
    function getInvestment(address investor) external view returns (Investment memory investment);
    
    /**
     * @notice Returns all investments for a specific investor
     * @param investor The address of the investor
     * @return investments Array of all investments
     */
    function getUserInvestments(address investor) external view returns (Investment[] memory investments);
    
    /**
     * @notice Returns the number of investments for a specific investor
     * @param investor The address of the investor
     * @return The number of investments
     */
    function getUserInvestmentCount(address investor) external view returns (uint256);
    
    /**
     * @notice Returns a specific investment by index for a specific investor
     * @param investor The address of the investor
     * @param index The index of the investment
     * @return The investment information
     */
    function getUserInvestmentByIndex(address investor, uint256 index) external view returns (Investment memory);
    
    /**
     * @notice Returns the indices of refundable investments for a specific investor
     * @param investor The address of the investor
     * @return refundableIndices Array of refundable investment indices
     */
    function getRefundableInvestments(address investor) external view returns (uint256[] memory refundableIndices);
    
    /**
     * @notice Returns the indices of claimable investments for a specific investor
     * @param investor The address of the investor
     * @return claimableIndices Array of claimable investment indices
     */
    function getClaimableInvestments(address investor) external view returns (uint256[] memory claimableIndices);
    
    /**
     * @notice Returns the number of investors
     * @return The number of investors
     */
    function getInvestorCount() external view returns (uint256);
    
    /**
     * @notice Returns the investor at a specific index
     * @param index The index of the investor
     * @return The address of the investor
     */
    function getInvestor(uint256 index) external view returns (address);
    
    /**
     * @notice Returns the current IEO status
     * @return True if IEO is active and within time bounds
     */
    function getIEOStatus() external view returns (bool);
    
    /**
     * @notice Returns the USDC balance held by the contract
     * @return The USDC balance
     */
    function getUSDCBalance() external view returns (uint256);
    
    /**
     * @notice Returns the business admin address
     * @return The business admin address
     */
    function getBusinessAdmin() external view returns (address);
    
    /**
     * @notice Returns the withdrawal delay period
     * @return The withdrawal delay in seconds
     */
    function getWithdrawalDelay() external view returns (uint256);
    
    /**
     * @notice Returns the total amount deposited
     * @return The total USDC deposited
     */
    function getTotalDeposited() external view returns (uint256);
    
    /**
     * @notice Returns the total amount withdrawn
     * @return The total USDC withdrawn
     */
    function getTotalWithdrawn() external view returns (uint256);
    
    /**
     * @notice Returns the withdrawable amount (per-investment based)
     * @return The amount of USDC that can be withdrawn
     */
    function getWithdrawableAmount() external view returns (uint256);
    
    /**
     * @notice Returns the withdrawable amount for a specific investor
     * @param investor The address of the investor
     * @return The amount of USDC that can be withdrawn for this investor
     */
    function getInvestorWithdrawableAmount(address investor) external view returns (uint256);
    
    /**
     * @notice Returns the minimum acceptable token price
     * @return The minimum token price
     */
    function getMinTokenPrice() external view returns (uint256);
    
    /**
     * @notice Returns the maximum acceptable token price
     * @return The maximum token price
     */
    function getMaxTokenPrice() external view returns (uint256);
    
    /**
     * @notice Returns whether price validation is enabled
     * @return True if price validation is enabled, false otherwise
     */
    function isPriceValidationEnabled() external view returns (bool);

    /**
     * @notice Returns the price staleness threshold
     * @return The staleness threshold in seconds
     */
    function getPriceStalenessThreshold() external view returns (uint256);

    /**
     * @notice Returns the maximum price deviation percentage
     * @return The maximum price deviation in basis points
     */
    function getMaxPriceDeviation() external view returns (uint256);

    /**
     * @notice Returns the last valid price
     * @return The last valid price
     */
    function getLastValidPrice() external view returns (uint256);

    /**
     * @notice Returns whether circuit breaker is enabled
     * @return True if circuit breaker is enabled, false otherwise
     */
    function isCircuitBreakerEnabled() external view returns (bool);

    /**
     * @notice Returns whether circuit breaker is triggered
     * @return True if circuit breaker is triggered, false otherwise
     */
    function isCircuitBreakerTriggered() external view returns (bool);

    // ============ State-Changing Functions ============
    
    /**
     * @notice Invests USDC to purchase tokens
     * @dev Only callable during active IEO, supports multiple separate investments
     * @param usdcAmount The amount of USDC to invest
     */
    function invest(uint256 usdcAmount) external;
    
    /**
     * @notice Claims purchased tokens after the claim delay
     * @dev Only callable by investors after claim delay, claims all claimable investments
     */
    function claimTokens() external;
    
    /**
     * @notice Refunds a specific investment by index
     * @dev Only callable by investors within refund period
     * @param investmentIndex The index of the investment to refund
     */
    function refundInvestmentByIndex(uint256 investmentIndex) external;
    
    /**
     * @notice Refunds all refundable investments
     * @dev Only callable by investors within refund period
     */
    function refundInvestment() external;
    
    /**
     * @notice Withdraws USDC by business admin
     * @dev Only callable by business admin after per-investment delay
     * @param amount The amount of USDC to withdraw
     */
    function withdrawUSDC(uint256 amount) external;
    
    /**
     * @notice Withdraws all available USDC by business admin
     * @dev Only callable by business admin after per-investment delay
     */
    function withdrawAllUSDC() external;

    // ============ Owner Functions ============
    
    /**
     * @notice Starts the IEO
     * @dev Only callable by the owner
     * @param duration The duration of the IEO in seconds
     */
    function startIEO(uint256 duration) external;
    
    /**
     * @notice Ends the IEO
     * @dev Only callable by the owner
     */
    function endIEO() external;
    
    /**
     * @notice Releases USDC to reward tracking contract after 30 days
     * @dev Only callable by the owner
     */
    function releaseUSDCToRewardTracking() external;
    
    /**
     * @notice Emergency withdraws USDC from the contract
     * @dev Only callable by the owner
     * @param amount The amount of USDC to withdraw
     */
    function emergencyWithdrawUSDC(uint256 amount) external;
    
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

    // ============ Admin Functions ============
    
    /**
     * @notice Sets the price oracle address
     * @dev Only callable by admin or owner
     * @param _priceOracle The address of the price oracle
     */
    function setPriceOracle(address _priceOracle) external;
    
    /**
     * @notice Sets the admin address
     * @dev Only callable by the owner
     * @param _admin The address of the new admin
     */
    function setAdmin(address _admin) external;
    
    // ============ Business Admin Functions ============
    
    /**
     * @notice Sets the price validation bounds
     * @dev Only callable by business admin
     * @param _minTokenPrice The minimum acceptable token price
     * @param _maxTokenPrice The maximum acceptable token price
     */
    function setPriceValidation(uint256 _minTokenPrice, uint256 _maxTokenPrice) external;

    /**
     * @notice Sets the circuit breaker parameters
     * @dev Only callable by business admin
     * @param _priceStalenessThreshold The staleness threshold in seconds
     * @param _maxPriceDeviation The maximum price deviation percentage
     * @param _enabled Whether circuit breaker is enabled
     */
    function setCircuitBreaker(uint256 _priceStalenessThreshold, uint256 _maxPriceDeviation, bool _enabled) external;

    /**
     * @notice Resets the circuit breaker
     * @dev Only callable by business admin
     */
    function resetCircuitBreaker() external;

    /**
     * @notice Enables the circuit breaker
     * @dev Only callable by business admin
     */
    function enableCircuitBreaker() external;

    /**
     * @notice Disables the circuit breaker
     * @dev Only callable by business admin
     */
    function disableCircuitBreaker() external;

    /**
     * @notice Pauses the IEO
     * @dev Only callable by business admin, only when IEO is active
     */
    function pauseIEO() external;

    /**
     * @notice Unpauses the IEO
     * @dev Only callable by business admin, only when IEO is active and paused
     */
    function unpauseIEO() external;
}