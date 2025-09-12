// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library FundraisingTokenErrors {
    // Whitelist related errors
    error CallerNotWhitelisted();
    error SenderNotWhitelisted();
    error RecipientNotWhitelisted();
    error SpenderNotWhitelisted();
    error AddressAlreadyWhitelisted();
    error AddressNotWhitelisted();
    error CannotWhitelistZeroAddress();
    error RecipientMustBeWhitelisted();
    
    // Transfer related errors
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error TransferAmountExceedsBalance();
    error TransferAmountExceedsAllowance();
    error InsufficientAllowance();
    
    // Mint/Burn related errors
    error MintToZeroAddress();
    error BurnFromZeroAddress();
    error BurnAmountExceedsBalance();
    error MintAuthorityFrozen();
    
    // Approval related errors
    error ApproveFromZeroAddress();
    error ApproveToZeroAddress();
    
    // Owner related errors
    error CallerNotOwner();
    error NewOwnerIsZeroAddress();
}