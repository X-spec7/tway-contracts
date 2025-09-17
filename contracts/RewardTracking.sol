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
    uint256 internal constant REENTRANCY_GUARD_NOT_ENTERED = 1;
    uint256 internal constant REENTRANCY_GUARD_ENTERED = 2;
    
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
            lastRewardBlock: block.number
        });
    }

    // Override functions to satisfy both Ownable and IRewardTracking
    function owner() public view override(Ownable, IRewardTracking) returns (address) {
        return super.owner();
    }

    function transferOwnership(address newOwner) public override(Ownable, IRewardTracking) {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override(Ownable, IRewardTracking) {
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

    function depositUSDC(uint256 amount) external onlyOwner nonReentrant {
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
            poolInfo.totalUSDCDeposited += amount;
            
            // Calculate new accumulated reward per token
            uint256 newRewardPerToken = poolInfo.accumulatedRewardPerToken + 
                (amount * PRECISION) / poolInfo.totalTokenSold;
            
            poolInfo.accumulatedRewardPerToken = newRewardPerToken;
            poolInfo.lastRewardBlock = block.number;
            
            emit RewardDeposited(amount, poolInfo.accumulatedRewardPerToken);
        }
    }

    // Called by IEO when tokens are sold
    function onTokenSold(address user, uint256 amount) external override onlyIEO {
        // Update total tokens sold
        poolInfo.totalTokenSold += amount;
        
        // Update user's reward tracking
        UserRewardTracking storage userTracking = userRewardTrackings[user];
        userTracking.balance += amount;
        userTracking.rewardDebt += amount * poolInfo.accumulatedRewardPerToken / PRECISION;
        
        emit UserBalanceUpdated(user, userTracking.balance, userTracking.rewardDebt);
        emit TokensSoldUpdated(poolInfo.totalTokenSold);
    }

    // Called by token contract when tokens are transferred
    function onTokenTransfer(address from, address to, uint256 amount) external override {
        require(msg.sender == tokenAddress, "Only token contract can call this");
        
        // Update sender's reward tracking
        if (from != address(0)) {
            UserRewardTracking storage fromTracking = userRewardTrackings[from];
            fromTracking.balance -= amount;
            fromTracking.rewardDebt -= amount * poolInfo.accumulatedRewardPerToken / PRECISION;
            
            emit UserBalanceUpdated(from, fromTracking.balance, fromTracking.rewardDebt);
        }
        
        // Update receiver's reward tracking
        if (to != address(0)) {
            UserRewardTracking storage toTracking = userRewardTrackings[to];
            toTracking.balance += amount;
            toTracking.rewardDebt += amount * poolInfo.accumulatedRewardPerToken / PRECISION;
            
            emit UserBalanceUpdated(to, toTracking.balance, toTracking.rewardDebt);
        }
    }

    // Claim rewards
    function claimReward() external override nonReentrant {
        UserRewardTracking storage userTracking = userRewardTrackings[msg.sender];
        
        // Calculate pending reward
        uint256 pendingReward = (userTracking.balance * poolInfo.accumulatedRewardPerToken / PRECISION) - userTracking.rewardDebt;
        
        if (pendingReward == 0) {
            revert FundraisingErrors.NoRewardsToClaim();
        }
        
        // Update user's reward debt
        userTracking.rewardDebt = userTracking.balance * poolInfo.accumulatedRewardPerToken / PRECISION;
        
        // Transfer USDC to user
        IERC20(USDC_ADDRESS).transfer(msg.sender, pendingReward);
        
        emit RewardClaimed(msg.sender, pendingReward);
    }
    
    // View functions
    function getPendingReward(address user) external view override returns (uint256) {
        UserRewardTracking memory userTracking = userRewardTrackings[user];
        return (userTracking.balance * poolInfo.accumulatedRewardPerToken / PRECISION) - userTracking.rewardDebt;
    }

    function getUserRewardTracking(address user) external view override returns (UserRewardTracking memory) {
        return userRewardTrackings[user];
    }

    function getPoolInfo() external view override returns (PoolInfo memory) {
        return poolInfo;
    }

    // Emergency function
    function emergencyWithdrawUSDC(uint256 amount) external override onlyOwner {
        IERC20(USDC_ADDRESS).transfer(owner(), amount);
    }
}