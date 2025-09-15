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
    address user1;
    address mockToken;

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        mockToken = makeAddr("mockToken");
        
        // Deploy with custom parameters: 14 days delay, 100-100000 USDC limits
        ieo = new IEO(
            mockToken, 
            admin, 
            14, // delay days (same for claim and refund)
            100 * 1e6, // min investment (100 USDC)
            100000 * 1e6 // max investment (100000 USDC)
        );
    }

    function test_InitialState() public view {
        require(!ieo.isIEOActive(), "IEO should be inactive initially");
        require(ieo.owner() == owner, "Owner should be set correctly");
        require(ieo.admin() == admin, "Admin should be set correctly");
        require(ieo.tokenAddress() == mockToken, "Token address should be set correctly");
        require(ieo.CLAIM_DELAY() == 14 days, "Claim delay should be 14 days");
        require(ieo.REFUND_PERIOD() == 14 days, "Refund period should be 14 days");
        require(ieo.MIN_INVESTMENT() == 100 * 1e6, "Min investment should be 100 USDC");
        require(ieo.MAX_INVESTMENT() == 100000 * 1e6, "Max investment should be 100000 USDC");
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

    function test_YulAssemblyIEOActiveState() public {
        // Test that the Yul assembly implementation works correctly
        require(!ieo.isIEOActive(), "Initially inactive");
        
        ieo.startIEO(7 days);
        require(ieo.isIEOActive(), "Active after start");
        
        ieo.endIEO();
        require(!ieo.isIEOActive(), "Inactive after end");
    }

    function test_ConstructorValidation() public {
        // Test zero address validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.ZeroAddress.selector));
        new IEO(address(0), admin, 14, 100 * 1e6, 100000 * 1e6);
        
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.ZeroAddress.selector));
        new IEO(mockToken, address(0), 14, 100 * 1e6, 100000 * 1e6);
        
        // Test zero days validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidDelayDays.selector));
        new IEO(mockToken, admin, 0, 100 * 1e6, 100000 * 1e6);
        
        // Test zero investment validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidMinInvestment.selector));
        new IEO(mockToken, admin, 14, 0, 100000 * 1e6);
        
        // Test invalid range validation
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidInvestmentRange.selector));
        new IEO(mockToken, admin, 14, 100000 * 1e6, 100 * 1e6);
    }

    function test_DifferentPeriods() public {
        // Test with different periods
        IEO ieoCustom = new IEO(
            mockToken, 
            admin, 
            7, // delay days
            50 * 1e6, // min investment (50 USDC)
            50000 * 1e6 // max investment (50000 USDC)
        );
        
        require(ieoCustom.CLAIM_DELAY() == 7 days, "Claim delay should be 7 days");
        require(ieoCustom.REFUND_PERIOD() == 7 days, "Refund period should be 7 days");
        require(ieoCustom.MIN_INVESTMENT() == 50 * 1e6, "Min investment should be 50 USDC");
        require(ieoCustom.MAX_INVESTMENT() == 50000 * 1e6, "Max investment should be 50000 USDC");
    }

    function test_ClaimAndRefundPeriodsSame() public view {
        // Verify that claim and refund periods are always the same
        require(ieo.CLAIM_DELAY() == ieo.REFUND_PERIOD(), "Claim and refund periods should be the same");
    }

    function test_SpecificErrorMessages() public {
        // Test specific error messages for better debugging
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidDelayDays.selector));
        new IEO(mockToken, admin, 0, 100 * 1e6, 100000 * 1e6);
        
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidMinInvestment.selector));
        new IEO(mockToken, admin, 14, 0, 100000 * 1e6);
        
        vm.expectRevert(abi.encodeWithSelector(FundraisingErrors.InvalidInvestmentRange.selector));
        new IEO(mockToken, admin, 14, 100000 * 1e6, 100 * 1e6);
    }
}