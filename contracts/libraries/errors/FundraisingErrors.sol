// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title FundraisingErrors
 * @author FundraisingToken Team
 * @notice Custom errors for the fundraising system
 * @dev These errors provide gas-efficient error handling
 */
library FundraisingErrors {
    // ============ General Errors ============
    
    /// @notice Thrown when a zero address is provided where it's not allowed
    error ZeroAddress();
    
    /// @notice Thrown when the caller is not authorized
    error NotAuthorized();
    
    /// @notice Thrown when the caller is not the owner
    error NotOwner();
    
    /// @notice Thrown when the caller is not the admin
    error NotAdmin();
    
    /// @notice Thrown when the caller is not the business admin
    error NotBusinessAdmin();
    
    /// @notice Thrown when a reentrant call is detected
    error ReentrantCallBlocked();
    
    // ============ Token Errors ============
    
    /// @notice Thrown when trying to whitelist a zero address
    error CannotWhitelistZeroAddress();
    
    /// @notice Thrown when trying to remove a zero address from whitelist
    error CannotRemoveZeroAddress();
    
    /// @notice Thrown when trying to whitelist an already whitelisted address
    error AddressAlreadyWhitelisted();
    
    /// @notice Thrown when trying to remove a non-whitelisted address
    error AddressNotWhitelisted();
    
    /// @notice Thrown when trying to transfer to a non-whitelisted address
    error RecipientNotWhitelisted();
    
    /// @notice Thrown when trying to transfer from a non-whitelisted address
    error SenderNotWhitelisted();
    
    /// @notice Thrown when trying to set reward tracking address to zero
    error RewardTrackingAddressCannotBeZero();
    
    /// @notice Thrown when reward tracking is not enabled
    error RewardTrackingNotEnabled();
    
    // ============ IEO Errors ============
    
    /// @notice Thrown when IEO is not active
    error IEONotActive();
    
    /// @notice Thrown when IEO is paused
    error IEOPaused();
    
    /// @notice Thrown when IEO is already active
    error IEOAlreadyActive();
    
    /// @notice Thrown when IEO is not started
    error IEONotStarted();
    
    /// @notice Thrown when IEO has ended
    error IEOEnded();
    
    /// @notice Thrown when trying to start IEO before it's ready
    error IEOStartNotReady();
    
    /// @notice Thrown when trying to end IEO before it's started
    error IEOEndNotReady();
    
    /// @notice Thrown when trying to pause IEO when it's not active
    error IEONotActiveForPause();
    
    /// @notice Thrown when trying to unpause IEO when it's not paused
    error IEONotPausedForUnpause();
    
    // ============ Investment Errors ============
    
    /// @notice Thrown when investment amount is invalid
    error InvalidInvestmentAmount();
    
    /// @notice Thrown when investment amount is below minimum
    error InvestmentAmountBelowMinimum();
    
    /// @notice Thrown when investment amount exceeds maximum
    error InvestmentAmountExceedsMaximum();
    
    /// @notice Thrown when investment range is invalid
    error InvalidInvestmentRange();
    
    /// @notice Thrown when user is not an investor
    error NotInvestor();
    
    /// @notice Thrown when trying to invest when not whitelisted
    error NotWhitelistedForInvestment();
    
    /// @notice Thrown when trying to invest when IEO is not active
    error IEONotActiveForInvestment();
    
    /// @notice Thrown when trying to invest when IEO is paused
    error IEOpausedForInvestment();
    
    // ============ Claim/Refund Errors ============
    
    /// @notice Thrown when claim period has not started
    error ClaimPeriodNotStarted();
    
    /// @notice Thrown when claim period has ended
    error ClaimPeriodEnded();
    
    /// @notice Thrown when refund period has ended
    error RefundPeriodEnded();
    
    /// @notice Thrown when trying to claim already claimed tokens
    error TokensAlreadyClaimed();
    
    /// @notice Thrown when trying to refund already refunded investment
    error InvestmentAlreadyRefunded();
    
    /// @notice Thrown when trying to claim when not an investor
    error NotInvestorForClaim();
    
    /// @notice Thrown when trying to refund when not an investor
    error NotInvestorForRefund();
    
    // ============ Price Oracle Errors ============
    
    /// @notice Thrown when price oracle returns invalid price
    error InvalidPrice();
    
    /// @notice Thrown when price oracle is not set
    error PriceOracleNotSet();
    
    /// @notice Thrown when price validation fails
    error PriceValidationFailed();
    
    /// @notice Thrown when price is below minimum threshold
    error PriceBelowMinimum();
    
    /// @notice Thrown when price is above maximum threshold
    error PriceAboveMaximum();
    
    /// @notice Thrown when circuit breaker is triggered
    error CircuitBreakerTriggered();
    
    /// @notice Thrown when circuit breaker is not enabled
    error CircuitBreakerNotEnabled();
    
    /// @notice Thrown when circuit breaker parameters are invalid
    error InvalidCircuitBreakerParameters();
    
    // ============ Withdrawal Errors ============
    
    /// @notice Thrown when withdrawal amount is invalid
    error InvalidWithdrawalAmount();
    
    /// @notice Thrown when withdrawal amount exceeds available
    error AmountExceedsWithdrawable();
    
    /// @notice Thrown when no withdrawable amount available
    error NoWithdrawableAmount();
    
    /// @notice Thrown when withdrawal delay has not passed
    error WithdrawalDelayNotPassed();
    
    /// @notice Thrown when trying to withdraw when not business admin
    error NotBusinessAdminForWithdrawal();
    
    // ============ Reward Tracking Errors ============
    
    /// @notice Thrown when no tokens have been sold yet
    error NoTokensSold();
    
    /// @notice Thrown when reward tracking is not enabled
    error RewardTrackingNotEnabledForDeposit();
    
    /// @notice Thrown when trying to claim rewards when not eligible
    error NotEligibleForRewards();
    
    /// @notice Thrown when reward amount is zero
    error ZeroRewardAmount();
    
    /// @notice Thrown when reward calculation fails
    error RewardCalculationFailed();
    
    /// @notice Thrown when caller is not the IEO contract
    error NotIEOContract();
    
    // ============ Validation Errors ============
    
    /// @notice Thrown when delay days is invalid
    error InvalidDelayDays();
    
    /// @notice Thrown when minimum investment is invalid
    error InvalidMinInvestment();
    
    /// @notice Thrown when maximum investment is invalid
    error InvalidMaxInvestment();
    
    /// @notice Thrown when amount is invalid
    error InvalidAmount();
    
    /// @notice Thrown when trying to set invalid parameters
    error InvalidParameters();
    
    /// @notice Thrown when trying to perform action with invalid state
    error InvalidState();
    
    // ============ Emergency Errors ============
    
    /// @notice Thrown when emergency function is called
    error EmergencyFunctionCalled();
    
    /// @notice Thrown when emergency withdrawal fails
    error EmergencyWithdrawalFailed();
    
    /// @notice Thrown when emergency pause fails
    error EmergencyPauseFailed();
    
    /// @notice Thrown when emergency unpause fails
    error EmergencyUnpauseFailed();
}