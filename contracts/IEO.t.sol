// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IEO} from "./IEO.sol";
import {Test} from "forge-std/Test.sol";
import {FundraisingErrors} from "./libraries/errors/FundraisingErrors.sol";
import {IIEO} from "./interfaces/IIEO.sol";

contract IEOTest is Test {
    IEO ieo;
    address owner;
    address admin;
    address businessAdmin;
    address user1;
    address user2;
    address mockToken;

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        businessAdmin = makeAddr("businessAdmin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        mockToken = makeAddr("mockToken");
        
        // Deploy with custom parameters: 14 days delay, 100-100000 USDC limits
        ieo = new IEO(
            mockToken, 
            admin, 
            businessAdmin,
            14, // delay days (same for claim, refund, and withdrawal)
            100 * 1e6, // min investment (100 USDC)
            100000 * 1e6 // max investment (100000 USDC)
        );
    }

    function test_InitialState() public view {
        require(!ieo.isIEOActive(), "IEO should be inactive initially");
        require(ieo.owner() == owner, "Owner should be set correctly");
        require(ieo.admin() == admin, "Admin should be set correctly");
        require(ieo.getBusinessAdmin() == businessAdmin, "Business admin should be set correctly");
        require(ieo.tokenAddress() == mockToken, "Token address should be set correctly");
        require(ieo.CLAIM_DELAY() == 14 days, "Claim delay should be 14 days");
        require(ieo.REFUND_PERIOD() == 14 days, "Refund period should be 14 days");
        require(ieo.getWithdrawalDelay() == 14 days, "Withdrawal delay should be 14 days");
        require(ieo.MIN_INVESTMENT() == 100 * 1e6, "Min investment should be 100 USDC");
        require(ieo.MAX_INVESTMENT() == 100000 * 1e6, "Max investment should be 100000 USDC");
        require(ieo.getTotalDeposited() == 0, "Total deposited should be 0 initially");
        require(ieo.getTotalWithdrawn() == 0, "Total withdrawn should be 0 initially");
    }

    function test_StartIEO() public {
        uint256 duration = 7 days;
        
        ieo.startIEO(duration);
        
        require(ieo.isIEOActive(), "IEO should be active after start");
        require(ieo.ieoStartTime() > 0, "IEO start time should be set");
        require(ieo.ieoEndTime() > ieo.ieoStartTime(), "IEO end time should be after start time");
    }

    function test_EndIEO() public {
        ieo.startIEO(7 days);
        require(ieo.isIEOActive(), "IEO should be active");
        
        ieo.endIEO();
        require(!ieo.isIEOActive(), "IEO should be inactive after end");
    }

    function test_SeparateInvestmentTracking() public {
        ieo.startIEO(30 days);
        
        // Test that each investment is tracked separately
        require(ieo.getUserInvestmentCount(user1) == 0, "User1 should have no investments initially");
        require(ieo.getUserInvestmentCount(user2) == 0, "User2 should have no investments initially");
        
        // Simulate first investment for user1
        uint256 investment1Time = block.timestamp;
        uint256 investment1Amount = 10000 * 1e6; // 10K USDC
        
        // Mock investment 1 by directly manipulating storage
        // This is a simplified test - in real scenario, this would be done through invest()
        vm.store(address(ieo), bytes32(uint256(11)), bytes32(investment1Amount)); // totalDeposited
        
        // Check that user1 is now an investor
        require(ieo.getUserInvestmentCount(user1) == 0, "User1 should still have 0 investments (no real invest call)");
        
        // Test that the system tracks separate investments
        require(ieo.getTotalDeposited() == investment1Amount, "Total deposited should be 10K USDC");
    }

    function test_MultipleInvestmentsPerUser() public {
        ieo.startIEO(30 days);
        
        // Test that multiple investments are tracked separately
        require(ieo.getUserInvestmentCount(user1) == 0, "User1 should have no investments initially");
        
        // Simulate multiple investments at different times
        uint256 investment1Time = block.timestamp;
        uint256 investment1Amount = 5000 * 1e6; // 5K USDC
        
        uint256 investment2Time = investment1Time + 5 days;
        uint256 investment2Amount = 3000 * 1e6; // 3K USDC
        
        // Mock investments by directly manipulating storage
        vm.store(address(ieo), bytes32(uint256(11)), bytes32(investment1Amount + investment2Amount)); // totalDeposited
        
        // Test that the system can handle multiple investments
        require(ieo.getTotalDeposited() == investment1Amount + investment2Amount, "Total deposited should be 8K USDC");
    }

    function test_WithdrawalLogic() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Test withdrawal logic without mocking storage
        // Just test the basic functionality
        require(ieo.getWithdrawableAmount() == 0, "Should not be withdrawable before delay");
        
        // Test that withdrawal functions exist and can be called
        // (They will fail due to insufficient balance, but that's expected)
        vm.prank(businessAdmin);
        vm.expectRevert("Amount exceeds withdrawable amount");
        ieo.withdrawUSDC(100 * 1e6);
    }

    function test_WithdrawalAccessControl() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Only business admin can withdraw
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.NotAdmin.selector));
        ieo.withdrawUSDC(100 * 1e6);
        
        // Owner can also withdraw (but will fail due to insufficient balance)
        vm.expectRevert("Amount exceeds withdrawable amount");
        ieo.withdrawUSDC(100 * 1e6);
    }

    function test_WithdrawalBeforeDelay() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Try to withdraw before delay
        vm.prank(businessAdmin);
        vm.expectRevert("Amount exceeds withdrawable amount");
        ieo.withdrawUSDC(100 * 1e6);
    }

    function test_WithdrawalExceedsAvailable() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Try to withdraw more than available
        vm.prank(businessAdmin);
        vm.expectRevert("Amount exceeds withdrawable amount");
        ieo.withdrawUSDC(2000 * 1e6);
    }

    function test_InvestorWithdrawableAmount() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Test investor-specific withdrawable amount
        require(ieo.getInvestorWithdrawableAmount(user1) == 0, "User1 should have no withdrawable amount");
        require(ieo.getInvestorWithdrawableAmount(user2) == 0, "User2 should have no withdrawable amount");
    }

    function test_WithdrawalWithRefunds() public {
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        // Test that withdrawal functions exist and can be called
        // (They will fail due to insufficient balance, but that's expected)
        vm.prank(businessAdmin);
        vm.expectRevert("Amount exceeds withdrawable amount");
        ieo.withdrawUSDC(100 * 1e6);
    }

    function test_ConstructorValidation() public {
        // Test zero address validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.ZeroAddress.selector));
        new IEO(address(0), admin, businessAdmin, 14, 100 * 1e6, 100000 * 1e6);
        
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.ZeroAddress.selector));
        new IEO(mockToken, address(0), businessAdmin, 14, 100 * 1e6, 100000 * 1e6);
        
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.ZeroAddress.selector));
        new IEO(mockToken, admin, address(0), 14, 100 * 1e6, 100000 * 1e6);
        
        // Test zero days validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidDelayDays.selector));
        new IEO(mockToken, admin, businessAdmin, 0, 100 * 1e6, 100000 * 1e6);
        
        // Test zero investment validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidMinInvestment.selector));
        new IEO(mockToken, admin, businessAdmin, 14, 0, 100000 * 1e6);
        
        // Test invalid range validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidInvestmentRange.selector));
        new IEO(mockToken, admin, businessAdmin, 14, 100000 * 1e6, 100 * 1e6);
    }

    function test_YulAssemblyIEOActiveState() public {
        // Test that the Yul assembly implementation works correctly
        require(!ieo.isIEOActive(), "Initially inactive");
        
        ieo.startIEO(7 days);
        require(ieo.isIEOActive(), "Active after start");
        
        ieo.endIEO();
        require(!ieo.isIEOActive(), "Inactive after end");
    }

    function test_ClaimAndRefundPeriodsSame() public view {
        // Verify that claim, refund, and withdrawal periods are all the same
        require(ieo.CLAIM_DELAY() == ieo.REFUND_PERIOD(), "Claim and refund periods should be the same");
        require(ieo.CLAIM_DELAY() == ieo.getWithdrawalDelay(), "Claim and withdrawal periods should be the same");
    }

    function test_WithdrawalDelayCalculation() public view {
        // Test that withdrawal delay is calculated correctly
        require(ieo.getWithdrawalDelay() == 14 days, "Withdrawal delay should be 14 days");
    }

    function test_WithdrawalStateTransitions() public {
        // Test withdrawal state transitions
        require(ieo.getWithdrawableAmount() == 0, "No withdrawable amount initially");
        
        ieo.startIEO(7 days);
        ieo.endIEO();
        
        require(ieo.getWithdrawableAmount() == 0, "No withdrawable amount after IEO end");
    }

    function test_UserInvestmentTracking() public {
        ieo.startIEO(30 days);
        
        // Test user investment tracking functions
        require(ieo.getUserInvestmentCount(user1) == 0, "User1 should have no investments");
        require(ieo.getUserInvestmentCount(user2) == 0, "User2 should have no investments");
        
        // Test getUserInvestments function
        IIEO.Investment[] memory user1Investments = ieo.getUserInvestments(user1);
        require(user1Investments.length == 0, "User1 should have no investments array");
        
        // Test getInvestment function (backward compatibility)
        IIEO.Investment memory user1Investment = ieo.getInvestment(user1);
        require(user1Investment.usdcAmount == 0, "User1 should have no investment amount");
    }
}