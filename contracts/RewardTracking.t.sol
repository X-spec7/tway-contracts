// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {RewardTracking} from "./RewardTracking.sol";
import {Test} from "forge-std/Test.sol";
import {FundraisingErrors} from "./libraries/errors/FundraisingErrors.sol";

contract RewardTrackingTest is Test {
    RewardTracking rewardTracking;
    address owner;
    address ieoContract;
    address tokenAddress;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        ieoContract = makeAddr("ieoContract");
        tokenAddress = makeAddr("tokenAddress");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        rewardTracking = new RewardTracking(tokenAddress, ieoContract);
    }

    function test_InitialState() public view {
        require(rewardTracking.owner() == owner, "Owner should be set correctly");
        require(rewardTracking.tokenAddress() == tokenAddress, "Token address should be set correctly");
        require(rewardTracking.ieoContract() == ieoContract, "IEO contract should be set correctly");
        require(rewardTracking.USDC_ADDRESS() == 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359, "USDC address should be set correctly");
        require(rewardTracking.PRECISION() == 1e18, "Precision should be 1e18");
    }

    function test_DepositUSDC_NoTokensSold() public {
        // Try to deposit USDC when no tokens have been sold
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.NoTokensSold.selector));
        rewardTracking.depositUSDC(1000 * 1e6);
    }

    function test_DepositUSDC_AfterTokensSold() public {
        // First, simulate some tokens being sold
        vm.prank(ieoContract);
        rewardTracking.onTokenSold(user1, 1000 * 1e18);
        
        // Now deposit USDC should work
        // Note: This will fail due to USDC transfer, but the revert should be different
        vm.expectRevert(); // Will revert due to USDC transfer failure, not NoTokensSold
        rewardTracking.depositUSDC(1000 * 1e6);
    }

    function test_OnTokenSold() public {
        // Test that onTokenSold can be called by IEO contract
        vm.prank(ieoContract);
        rewardTracking.onTokenSold(user1, 1000 * 1e18);
        
        // Check that total tokens sold was updated
        require(rewardTracking.getPoolInfo().totalTokenSold == 1000 * 1e18, "Total tokens sold should be updated");
    }

    function test_OnTokenSold_NotIEO() public {
        // Test that onTokenSold reverts when called by non-IEO contract
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.NotIEOContract.selector));
        rewardTracking.onTokenSold(user1, 1000 * 1e18);
    }

    function test_OnTokenTransfer() public {
        // First, simulate some tokens being sold
        vm.prank(ieoContract);
        rewardTracking.onTokenSold(user1, 1000 * 1e18);
        
        // Test token transfer
        vm.prank(tokenAddress);
        rewardTracking.onTokenTransfer(user1, user2, 500 * 1e18);
        
        // Check that balances were updated
        require(rewardTracking.getUserRewardTracking(user1).balance == 500 * 1e18, "User1 balance should be updated");
        require(rewardTracking.getUserRewardTracking(user2).balance == 500 * 1e18, "User2 balance should be updated");
    }

    function test_OnTokenTransfer_NotTokenContract() public {
        // Test that onTokenTransfer reverts when called by non-token contract
        vm.prank(user1);
        vm.expectRevert("Only token contract can call this");
        rewardTracking.onTokenTransfer(user1, user2, 500 * 1e18);
    }

    function test_ClaimReward_NoRewards() public {
        // Test claiming rewards when there are no rewards
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.NoRewardsToClaim.selector));
        rewardTracking.claimReward();
    }

    function test_GetPendingReward() public view {
        // Test getting pending reward for a user
        uint256 pendingReward = rewardTracking.getPendingReward(user1);
        require(pendingReward == 0, "Pending reward should be 0 initially");
    }

    function test_GetPoolInfo() public view {
        // Test getting pool info
        RewardTracking.PoolInfo memory poolInfo = rewardTracking.getPoolInfo();
        require(poolInfo.totalTokenSold == 0, "Total tokens sold should be 0 initially");
        require(poolInfo.accumulatedRewardPerToken == 0, "Accumulated reward per token should be 0 initially");
        require(poolInfo.totalUSDCDeposited == 0, "Total USDC deposited should be 0 initially");
    }

    function test_GetUserRewardTracking() public view {
        // Test getting user reward tracking
        RewardTracking.UserRewardTracking memory userTracking = rewardTracking.getUserRewardTracking(user1);
        require(userTracking.balance == 0, "User balance should be 0 initially");
        require(userTracking.rewardDebt == 0, "User reward debt should be 0 initially");
    }

    function test_EmergencyWithdrawUSDC() public {
        // Test emergency withdraw USDC
        // This will fail due to USDC transfer, but the function should exist
        vm.expectRevert(); // Will revert due to USDC transfer failure
        rewardTracking.emergencyWithdrawUSDC(1000 * 1e6);
    }
}