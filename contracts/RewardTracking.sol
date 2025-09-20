// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./libraries/Ownable.sol";
import "./libraries/errors/FundraisingErrors.sol";
import "./interfaces/IRewardTracking.sol";

contract RewardTracking is Ownable, IRewardTracking {
    // Storage slots for Yul assembly optimization
    bytes32 internal constant REENTRANCY_GUARD_FLAG_SLOT = bytes32(keccak256("reward.tracking.reentrancy.guard"));
    
    // Reentrancy guard constants
    uint8 internal constant REENTRANCY_GUARD_NOT_ENTERED = 1;
    uint8 internal constant REENTRANCY_GUARD_ENTERED = 2;
    
    // Constants
    address public constant override USDC_ADDRESS = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    uint256 public constant override PRECISION = 1e18;

    // Immutable addresses (set in constructor)
    address public immutable override tokenAddress;
    address public immutable override ieoContract;

    // State variables
    PoolInfo public poolInfo;
    mapping(address => UserRewardTracking) public userRewardTrackings;

    modifier onlyIEO() {
        if (msg.sender != ieoContract) {
            revert FundraisingErrors.NotIEOContract();
        }
        _;
    }

    modifier nonReentrant() {
        nonReentrantBefore();
        _;
        nonReentrantAfter();
    }

    constructor(
        address _tokenAddress,
        address _ieoContract
    ) Ownable(msg.sender) {
        tokenAddress = _tokenAddress;
        ieoContract = _ieoContract;
        
        poolInfo = PoolInfo({
            totalTokenSold: 0,
            accumulatedRewardPerToken: 0,
            totalUSDCDeposited: 0,
            lastRewardBlock: uint64(block.number)
        });
    }

    // Override functions to satisfy both Ownable and IRewardTracking
    function owner()
        override(Ownable, IRewardTracking)
        public
        view
        returns (address)
    {
        return super.owner();
    }

    function transferOwnership(address newOwner)
        override(Ownable, IRewardTracking)
        public
    {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership()
        override(Ownable, IRewardTracking)
        public
    {
        super.renounceOwnership();
    }

    // Reentrancy guard functions
    function nonReentrantBefore() internal {
        bytes32 slot = REENTRANCY_GUARD_FLAG_SLOT;
        uint256 status;
        assembly ("memory-safe") {
            status := sload(slot)
        }

        if (status == REENTRANCY_GUARD_ENTERED) revert FundraisingErrors.ReentrantCallBlocked();
        assembly ("memory-safe") {
            sstore(slot, REENTRANCY_GUARD_ENTERED)
        }
    }

    function nonReentrantAfter() internal {
        bytes32 slot = REENTRANCY_GUARD_FLAG_SLOT;
        assembly ("memory-safe") {
            sstore(slot, REENTRANCY_GUARD_NOT_ENTERED)
        }
    }

    function depositUSDC(uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        // Revert if no tokens have been sold yet
        if (poolInfo.totalTokenSold == 0) {
            revert FundraisingErrors.NoTokensSold();
        }
        
        IERC20(USDC_ADDRESS).transferFrom(msg.sender, address(this), amount);
        _updatePool(amount);
    }

    // Update pool when USDC is deposited
    function _updatePool(uint256 amount) internal {
        if (amount > 0) {
            // Ensure totalTokenSold is not zero to prevent division by zero
            require(poolInfo.totalTokenSold > 0, "No tokens sold yet");
            
            poolInfo.totalUSDCDeposited += uint128(amount);
            
            uint256 rewardIncrease = (amount * PRECISION) / poolInfo.totalTokenSold;
            poolInfo.accumulatedRewardPerToken += rewardIncrease;
            
            poolInfo.lastRewardBlock = uint64(block.number);
            
            emit RewardDeposited(amount, poolInfo.accumulatedRewardPerToken);
        }
    }

    // Called by IEO when tokens are sold
    function onTokenSold(address user, uint256 amount)
        external
        onlyIEO
    {
        // Update total tokens sold
        poolInfo.totalTokenSold += uint128(amount);
        
        // Update user's reward tracking
        UserRewardTracking storage userTracking = userRewardTrackings[user];
        userTracking.balance += uint128(amount);
        
        // Calculate reward debt increase
        uint256 debtIncrease = (amount * poolInfo.accumulatedRewardPerToken) / PRECISION;
        userTracking.rewardDebt += debtIncrease;
        
        emit UserBalanceUpdated(user, userTracking.balance, userTracking.rewardDebt);
        emit TokensSoldUpdated(poolInfo.totalTokenSold);
    }

    // Called by token contract when tokens are transferred
    function onTokenTransfer(address from, address to, uint256 amount)
        external
    {
        require(msg.sender == tokenAddress, "Only token contract can call this");
        
        // Update sender's reward tracking
        if (from != address(0)) {
            UserRewardTracking storage fromTracking = userRewardTrackings[from];
            
            require(fromTracking.balance >= amount, "Insufficient balance for transfer");
            
            fromTracking.balance -= uint128(amount);
            
            // Calculate debt reduction
            uint256 debtReduction = (amount * poolInfo.accumulatedRewardPerToken) / PRECISION;
            require(fromTracking.rewardDebt >= debtReduction, "Insufficient reward debt for reduction");
            fromTracking.rewardDebt -= debtReduction;
            
            emit UserBalanceUpdated(from, fromTracking.balance, fromTracking.rewardDebt);
        }
        
        // Update receiver's reward tracking
        if (to != address(0)) {
            UserRewardTracking storage toTracking = userRewardTrackings[to];
            toTracking.balance += uint128(amount);
            
            // Calculate debt increase
            uint256 debtIncrease = (amount * poolInfo.accumulatedRewardPerToken) / PRECISION;
            toTracking.rewardDebt += debtIncrease;
            
            emit UserBalanceUpdated(to, toTracking.balance, toTracking.rewardDebt);
        }
    }

    // Claim rewards
    function claimReward() external override nonReentrant {
        UserRewardTracking storage userTracking = userRewardTrackings[msg.sender];
        
        // Calculate pending reward
        uint256 totalReward = (userTracking.balance * poolInfo.accumulatedRewardPerToken) / PRECISION;
        uint256 pendingReward = totalReward - userTracking.rewardDebt;
        
        if (pendingReward == 0) {
            revert FundraisingErrors.NoRewardsToClaim();
        }
        
        // Update user's reward debt
        userTracking.rewardDebt = (userTracking.balance * poolInfo.accumulatedRewardPerToken) / PRECISION;
        
        // Transfer USDC to user
        IERC20(USDC_ADDRESS).transfer(msg.sender, pendingReward);
        
        emit RewardClaimed(msg.sender, pendingReward);
    }
    
    // View functions
    function getPendingReward(address user)
        external
        view
        returns (uint256)
    {
        UserRewardTracking memory userTracking = userRewardTrackings[user];
        uint256 totalReward = (userTracking.balance * poolInfo.accumulatedRewardPerToken) / PRECISION;
        return totalReward - userTracking.rewardDebt;
    }

    function getUserRewardTracking(address user)
        external
        view
        returns (UserRewardTracking memory)
    {
        return userRewardTrackings[user];
    }

    function getPoolInfo()
        external
        view
        returns (PoolInfo memory)
    {
        return poolInfo;
    }

    // Emergency function
    function emergencyWithdrawUSDC(uint256 amount)
        external
        onlyOwner
    {
        IERC20(USDC_ADDRESS).transfer(owner(), amount);
    }
}