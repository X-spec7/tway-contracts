// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {FundraisingToken} from "./FundraisingToken.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "./dependencies/openzeppelin/IERC20.sol";
import {FundraisingTokenErrors} from "./libraries/errors/FundraisingTokenErrors.sol";
import {IFundraisingToken} from "./interfaces/IFundraisingToken.sol";

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
        
        token = new FundraisingToken("FundraisingToken", "FRT", 18, 1000000 * 1e18); // 1M tokens with 18 decimals
    }

    function test_InitialSupply() public view {
        require(token.totalSupply() == 1000000 * 1e18, "Initial supply should be 1M tokens");
        require(token.balanceOf(owner) == 1000000 * 1e18, "Owner should have 1M tokens");
    }

    function test_NameAndSymbol() public view {
        require(keccak256(bytes(token.name())) == keccak256(bytes("FundraisingToken")), "Name should be FundraisingToken");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("FRT")), "Symbol should be FRT");
        require(token.decimals() == 18, "Decimals should be 18");
    }

    function test_OwnerIsWhitelisted() public view {
        require(token.isWhitelisted(owner), "Owner should be whitelisted");
    }

    function test_MintAuthorityIsFrozen() public view {
        require(token.isMintAuthorityFrozen(), "Mint authority should be frozen");
    }

    function test_RewardTrackingDisabledInitially() public view {
        require(!token.isRewardTrackingEnabled(), "Reward tracking should be disabled initially");
    }

    function test_AddToWhitelist() public {
        token.addToWhitelist(user1);
        require(token.isWhitelisted(user1), "User1 should be whitelisted");
    }

    function test_RemoveFromWhitelist() public {
        token.addToWhitelist(user1);
        token.removeFromWhitelist(user1);
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted");
    }

    function test_BatchAddToWhitelist() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        token.batchAddToWhitelist(users);
        require(token.isWhitelisted(user1), "User1 should be whitelisted");
        require(token.isWhitelisted(user2), "User2 should be whitelisted");
    }

    function test_BatchRemoveFromWhitelist() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        token.batchAddToWhitelist(users);
        token.batchRemoveFromWhitelist(users);
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted");
        require(!token.isWhitelisted(user2), "User2 should not be whitelisted");
    }

    function test_TransferRequiresBothWhitelisted() public {
        token.addToWhitelist(user1);
        token.addToWhitelist(user2);
        
        // Should succeed when both are whitelisted
        token.transfer(user2, 1000 * 1e18);
        require(token.balanceOf(user2) == 1000 * 1e18, "Transfer should succeed");
        
        // Should fail when recipient is not whitelisted
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.RecipientNotWhitelisted.selector));
        token.transfer(user3, 1000 * 1e18);
    }

    function test_TransferFromFailsWhenRecipientNotWhitelisted() public {
        token.addToWhitelist(user1);
        // user3 is not whitelisted
        
        // Approve user1 to spend owner's tokens
        token.approve(user1, 1000 * 1e18);
        
        // Should fail when recipient is not whitelisted
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.RecipientNotWhitelisted.selector));
        token.transferFrom(owner, user3, 1000 * 1e18);
    }

    function test_ApproveRequiresWhitelist() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.CallerNotWhitelisted.selector));
        token.approve(user2, 1000 * 1e18);
    }

    function test_MintFailsWhenAuthorityFrozen() public {
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.MintAuthorityFrozen.selector));
        token.mint(user1, 1000 * 1e18);
    }

    function test_BurnRequiresWhitelist() public {
        token.addToWhitelist(user1);
        token.transfer(user1, 1000 * 1e18);
        
        vm.prank(user1);
        token.burn(100 * 1e18);
        require(token.balanceOf(user1) == 900 * 1e18, "Burn should succeed");
    }

    function test_OnlyOwnerCanManageWhitelist() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.CallerNotOwner.selector));
        token.addToWhitelist(user2);
    }

    function test_SetRewardTrackingAddress() public {
        address mockRewardTracking = makeAddr("rewardTracking");
        
        token.setRewardTrackingAddress(mockRewardTracking);
        require(token.rewardTrackingAddress() == mockRewardTracking, "Reward tracking address should be set");
        require(token.isRewardTrackingEnabled(), "Reward tracking should be enabled");
    }

    function test_WhitelistEvents() public {
        vm.expectEmit(true, true, true, true);
        emit IFundraisingToken.AddressWhitelisted(user1);
        token.addToWhitelist(user1);
        
        vm.expectEmit(true, true, true, true);
        emit IFundraisingToken.AddressRemovedFromWhitelist(user1);
        token.removeFromWhitelist(user1);
    }

    function test_AddToWhitelistZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(FundraisingTokenErrors.CannotWhitelistZeroAddress.selector));
        token.addToWhitelist(address(0));
    }

    function test_RemoveNotWhitelistedAddress() public {
        // This should not revert, just do nothing
        token.removeFromWhitelist(user1);
        require(!token.isWhitelisted(user1), "User1 should not be whitelisted");
    }

    function test_AddAlreadyWhitelistedAddress() public {
        token.addToWhitelist(user1);
        // This should not revert, just do nothing
        token.addToWhitelist(user1);
        require(token.isWhitelisted(user1), "User1 should still be whitelisted");
    }
}