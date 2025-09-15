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
        
        ieo = new IEO(mockToken, admin);
    }

    function test_InitialState() public view {
        require(!ieo.isIEOActive(), "IEO should be inactive initially");
        require(ieo.owner() == owner, "Owner should be set correctly");
        require(ieo.admin() == admin, "Admin should be set correctly");
        require(ieo.tokenAddress() == mockToken, "Token address should be set correctly");
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
}