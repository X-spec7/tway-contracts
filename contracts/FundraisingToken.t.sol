// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {FundraisingToken} from "./FundraisingToken.sol";
import {IERC20} from "./dependencies/openzeppelin/IERC20.sol";
import {FundraisingTokenErrors} from "./libraries/errors/FundraisingTokenErrors.sol";
import {Test} from "forge-std/Test.sol";

contract FundraisingTokenTest is Test {
    FundraisingToken token;
    address owner;
    address user1;
    address user2;
    address user3;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        token = new FundraisingToken("FundraisingToken", "FRT", 18, 1000000); // 1M tokens with 18 decimals
    }

    function test_InitialSupply() public view {
        require(token.totalSupply() == 1000000 * 10**18, "Initial supply should be 1M tokens");
        require(token.balanceOf(owner) == 1000000 * 10**18, "Owner should have all initial supply");
    }

    function test_NameAndSymbol() public view {
        require(keccak256(abi.encodePacked(token.name())) == keccak256(abi.encodePacked("FundraisingToken")), "Name should be FundraisingToken");
        require(keccak256(abi.encodePacked(token.symbol())) == keccak256(abi.encodePacked("FRT")), "Symbol should be FRT");
        require(token.decimals() == 18, "Decimals should be 18");
    }

    function test_OwnerIsWhitelisted() public view {
        require(token.isWhitelisted(owner), "Owner should be whitelisted");
    }

    function test_MintAuthorityIsFrozen() public view {
        require(token.isMintAuthorityFrozen(), "Mint authority should be frozen after deployment");
    }

    function test_AddToWhitelist() public {
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted initially");
        
        token.addToWhitelist(user1);
        require(token.isWhitelisted(user1), "User1 should be whitelisted after adding");
    }

    function test_RemoveFromWhitelist() public {
        token.addToWhitelist(user1);
        require(token.isWhitelisted(user1), "User1 should be whitelisted");
        
        token.removeFromWhitelist(user1);
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted after removal");
    }

    function test_BatchAddToWhitelist() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        
        token.batchAddToWhitelist(accounts);
        
        require(token.isWhitelisted(user1), "User1 should be whitelisted");
        require(token.isWhitelisted(user2), "User2 should be whitelisted");
    }

    function test_BatchRemoveFromWhitelist() public {
        token.addToWhitelist(user1);
        token.addToWhitelist(user2);
        
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        
        token.batchRemoveFromWhitelist(accounts);
        
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted");
        require(!token.isWhitelisted(user2), "User2 should not be whitelisted");
    }

    function test_TransferRequiresBothWhitelisted() public {
        uint256 amount = 1000 * 10**18;
        
        // Should fail - user1 not whitelisted
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.SenderNotWhitelisted.selector);
        token.transfer(user2, amount);
        
        // Add user1 to whitelist
        token.addToWhitelist(user1);
        
        // Should still fail - user2 not whitelisted
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.RecipientNotWhitelisted.selector);
        token.transfer(user2, amount);
        
        // Add user2 to whitelist
        token.addToWhitelist(user2);
        
        // Transfer some tokens to user1 first
        token.transfer(user1, amount);
        
        // Now transfer should work
        vm.prank(user1);
        token.transfer(user2, amount);
        
        require(token.balanceOf(user2) == amount, "User2 should receive tokens");
    }

    function test_TransferFromRequiresBothWhitelisted() public {
        uint256 amount = 1000 * 10**18;
        
        // Add users to whitelist (but NOT user3)
        token.addToWhitelist(user1);
        token.addToWhitelist(user2);
        // user3 is NOT whitelisted
        
        // Transfer tokens to user1
        token.transfer(user1, amount);
        
        // Approve user2 to spend user1's tokens
        vm.prank(user1);
        token.approve(user2, amount);
        
        // user3 tries to transferFrom (not whitelisted) - this should fail with RecipientNotWhitelisted
        vm.prank(user3);
        vm.expectRevert(FundraisingTokenErrors.RecipientNotWhitelisted.selector);
        token.transferFrom(user1, user3, amount);
        
        // Add user3 to whitelist
        token.addToWhitelist(user3);
        
        // user2 transfers (whitelisted)
        vm.prank(user2);
        token.transferFrom(user1, user3, amount);
        
        require(token.balanceOf(user3) == amount, "User3 should receive tokens");
    }

    function test_ApproveRequiresWhitelist() public {
        uint256 amount = 1000 * 10**18;
        
        // user1 not whitelisted
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.CallerNotWhitelisted.selector);
        token.approve(user2, amount);
        
        // Add user1 to whitelist
        token.addToWhitelist(user1);
        
        // user2 not whitelisted
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.SpenderNotWhitelisted.selector);
        token.approve(user2, amount);
        
        // Add user2 to whitelist
        token.addToWhitelist(user2);
        
        // Now approve should work
        vm.prank(user1);
        token.approve(user2, amount);
        
        require(token.allowance(user1, user2) == amount, "Allowance should be set");
    }

    function test_MintFailsWhenAuthorityFrozen() public {
        uint256 mintAmount = 50000 * 10**18;
        
        // Add user1 to whitelist
        token.addToWhitelist(user1);
        
        // Should fail - mint authority is frozen
        vm.expectRevert(FundraisingTokenErrors.MintAuthorityFrozen.selector);
        token.mint(user1, mintAmount);
    }

    function test_BurnRequiresWhitelist() public {
        uint256 burnAmount = 10000 * 10**18;
        
        // Should fail - user1 not whitelisted
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.CallerNotWhitelisted.selector);
        token.burn(burnAmount);
        
        // Add user1 to whitelist and give tokens
        token.addToWhitelist(user1);
        token.transfer(user1, burnAmount);
        
        // Now burn should work
        vm.prank(user1);
        token.burn(burnAmount);
        
        require(token.balanceOf(user1) == 0, "User1 should have no tokens after burn");
        require(token.totalSupply() == 1000000 * 10**18 - burnAmount, "Total supply should decrease");
    }

    function test_OnlyOwnerCanManageWhitelist() public {
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.CallerNotOwner.selector);
        token.addToWhitelist(user2);
        
        vm.prank(user1);
        vm.expectRevert(FundraisingTokenErrors.CallerNotOwner.selector);
        token.removeFromWhitelist(user2);
    }

    function test_WhitelistEvents() public {
        // Test AddressWhitelisted event
        vm.expectEmit(true, false, false, true);
        emit FundraisingToken.AddressWhitelisted(user1);
        token.addToWhitelist(user1);
        
        // Test AddressRemovedFromWhitelist event
        vm.expectEmit(true, false, false, true);
        emit FundraisingToken.AddressRemovedFromWhitelist(user1);
        token.removeFromWhitelist(user1);
    }

    function test_AddToWhitelistZeroAddress() public {
        vm.expectRevert(FundraisingTokenErrors.CannotWhitelistZeroAddress.selector);
        token.addToWhitelist(address(0));
    }

    function test_AddAlreadyWhitelistedAddress() public {
        token.addToWhitelist(user1);
        
        vm.expectRevert(FundraisingTokenErrors.AddressAlreadyWhitelisted.selector);
        token.addToWhitelist(user1);
    }

    function test_RemoveNotWhitelistedAddress() public {
        vm.expectRevert(FundraisingTokenErrors.AddressNotWhitelisted.selector);
        token.removeFromWhitelist(user1);
    }
}