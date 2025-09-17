// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library FundraisingErrors {
    // General errors
    error ZeroAddress();
    error NotAdmin();
    error NotIEOContract();
    error NotEscrowContract(); // Removed after escrow removal
    error ReentrantCallBlocked(); // Added for reentrancy guard
    error RewardTrackingNotEnabled(); // Added for reward tracking state
    error IEOContractNotSet(); // Added for IEO state

    // IEO related errors
    error IEONotActive();
    error InvalidInvestmentAmount();
    error AlreadyInvested();
    error InvalidPrice();
    error NotInvestor();
    error AlreadyClaimed();
    error ClaimPeriodNotStarted();
    error AlreadyRefunded();
    error RefundPeriodEnded();

    // Reward Tracking related errors
    error NoRewardsToClaim();
    error NoTokensSold(); // Added for when no tokens are sold

    // Escrow related errors (mostly removed)
    error EscrowNotActive();

    // New validation errors
    error InvalidDelayDays();
    error InvalidMinInvestment();
    error InvalidMaxInvestment();
    error InvalidInvestmentRange();
    error InvalidAmount();
    error AmountExceedsWithdrawable();
    error NoWithdrawableAmount();
}