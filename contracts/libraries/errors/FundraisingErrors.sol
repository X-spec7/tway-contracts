// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library FundraisingErrors {
    // General errors
    error ZeroAddress();
    error NotAdmin();
    error NotIEOContract();
    error RewardTrackingNotEnabled();
    error ReentrantCallBlocked();

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
}