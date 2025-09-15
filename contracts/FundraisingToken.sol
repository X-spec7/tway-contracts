// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./dependencies/openzeppelin/ERC20.sol";
import "./libraries/Ownable.sol";
import "./libraries/errors/FundraisingTokenErrors.sol";
import "./interfaces/IFundraisingToken.sol";

contract FundraisingToken is ERC20, Ownable, IFundraisingToken {
    // Storage slots for Yul assembly optimization
    bytes32 internal constant REWARD_TRACKING_ENABLED_SLOT = bytes32(keccak256("fundraising.token.reward.tracking.enabled"));
    bytes32 internal constant REENTRANCY_GUARD_FLAG_SLOT = bytes32(keccak256("fundraising.token.reentrancy.guard"));
    
    // Reentrancy guard constants
    uint256 internal constant REENTRANCY_GUARD_NOT_ENTERED = 1;
    uint256 internal constant REENTRANCY_GUARD_ENTERED = 2;
    
    // State variables
    mapping(address => bool) private _whitelist;
    address public override rewardTrackingAddress;
    bool private _mintAuthorityFrozen;

    // Modifiers
    modifier callerWhitelisted() {
        if (!_whitelist[_msgSender()]) {
            revert FundraisingTokenErrors.CallerNotWhitelisted();
        }
        _;
    }

    modifier onlyWhitelisted(address from, address to) {
        if (!_whitelist[from]) {
            revert FundraisingTokenErrors.SenderNotWhitelisted();
        }
        if (!_whitelist[to]) {
            revert FundraisingTokenErrors.RecipientNotWhitelisted();
        }
        _;
    }

    modifier mintAuthorityNotFrozen() {
        if (_mintAuthorityFrozen) {
            revert FundraisingTokenErrors.MintAuthorityFrozen();
        }
        _;
    }

    modifier nonReentrant() {
        nonReentrantBefore();
        _;
        nonReentrantAfter();
    }

    modifier rewardTrackingEnabled() {
        if (!isRewardTrackingEnabled()) {
            revert FundraisingTokenErrors.RewardTrackingNotEnabled();
        }
        _;
    }

    // Custom decimals
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) Ownable(_msgSender()) {
        _decimals = decimals_;
        rewardTrackingAddress = address(0);
        
        // Add owner to whitelist
        _whitelist[_msgSender()] = true;
        emit AddressWhitelisted(_msgSender());
        
        // Mint initial supply to owner
        _mint(_msgSender(), initialSupply);
        
        // Freeze mint authority after initial mint
        _mintAuthorityFrozen = true;
        emit MintAuthorityFrozen();
        
        // Initialize reentrancy guard
        setRewardTrackingEnabled(false);
    }

    // Override functions to satisfy both ERC20 and IFundraisingToken
    function name() public view override(ERC20, IFundraisingToken) returns (string memory) {
        return super.name();
    }

    function symbol() public view override(ERC20, IFundraisingToken) returns (string memory) {
        return super.symbol();
    }

    function decimals() public view override(ERC20, IFundraisingToken) returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override(ERC20, IFundraisingToken) returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address account) public view override(ERC20, IFundraisingToken) returns (uint256) {
        return super.balanceOf(account);
    }

    function allowance(address owner, address spender) public view override(ERC20, IFundraisingToken) returns (uint256) {
        return super.allowance(owner, spender);
    }

    function owner() public view override(Ownable, IFundraisingToken) returns (address) {
        return super.owner();
    }

    function transferOwnership(address newOwner) public override(Ownable, IFundraisingToken) {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override(Ownable, IFundraisingToken) {
        super.renounceOwnership();
    }

    // Yul assembly functions for reward tracking enabled state
    function isRewardTrackingEnabled() public view override returns (bool) {
        bytes32 slot = REWARD_TRACKING_ENABLED_SLOT;
        uint256 status;
        assembly ("memory-safe") {
            status := sload(slot)
        }
        return status == 1;
    }

    function setRewardTrackingEnabled(bool enabled) internal {
        bytes32 slot = REWARD_TRACKING_ENABLED_SLOT;
        uint256 value = enabled ? 1 : 0;
        assembly ("memory-safe") {
            sstore(slot, value)
        }
    }

    // Reentrancy guard functions
    function nonReentrantBefore() internal {
        bytes32 slot = REENTRANCY_GUARD_FLAG_SLOT;
        uint256 status;
        assembly ("memory-safe") {
            status := sload(slot)
        }

        if (status == REENTRANCY_GUARD_ENTERED) revert FundraisingTokenErrors.ReentrantCallBlocked();
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

    // Whitelist management functions
    function addToWhitelist(address account) public override onlyOwner {
        if (account == address(0)) {
            revert FundraisingTokenErrors.CannotWhitelistZeroAddress();
        }
        _whitelist[account] = true;
        emit AddressWhitelisted(account);
    }

    function removeFromWhitelist(address account) public override onlyOwner {
        if (account == address(0)) {
            revert FundraisingTokenErrors.CannotWhitelistZeroAddress();
        }
        _whitelist[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    function batchAddToWhitelist(address[] memory accounts) public override onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                _whitelist[accounts[i]] = true;
                emit AddressWhitelisted(accounts[i]);
            }
        }
    }

    function batchRemoveFromWhitelist(address[] memory accounts) public override onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0)) {
                _whitelist[accounts[i]] = false;
                emit AddressRemovedFromWhitelist(accounts[i]);
            }
        }
    }

    function isWhitelisted(address account) public view override returns (bool) {
        return _whitelist[account];
    }

    // Setter for reward tracking address
    function setRewardTrackingAddress(address _rewardTrackingAddress) external override onlyOwner {
        if (_rewardTrackingAddress == address(0)) {
            revert FundraisingTokenErrors.CannotWhitelistZeroAddress();
        }
        rewardTrackingAddress = _rewardTrackingAddress;
        setRewardTrackingEnabled(true);
        emit RewardTrackingAddressUpdated(_rewardTrackingAddress);
        emit RewardTrackingEnabled(true);
    }

    // Override transfer functions to include whitelist checks and reward tracking
    // NOTE: Reentrancy guard needed because we make external calls to reward tracking
    function transfer(address to, uint256 amount) public override(ERC20, IFundraisingToken) callerWhitelisted onlyWhitelisted(_msgSender(), to) nonReentrant returns (bool) {
        bool success = super.transfer(to, amount);
        
        // Notify reward tracking contract if enabled
        if (isRewardTrackingEnabled() && rewardTrackingAddress != address(0)) {
            IRewardTracking(rewardTrackingAddress).onTokenTransfer(_msgSender(), to, amount);
        }
        
        return success;
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IFundraisingToken) callerWhitelisted onlyWhitelisted(from, to) nonReentrant returns (bool) {
        bool success = super.transferFrom(from, to, amount);
        
        // Notify reward tracking contract if enabled
        if (isRewardTrackingEnabled() && rewardTrackingAddress != address(0)) {
            IRewardTracking(rewardTrackingAddress).onTokenTransfer(from, to, amount);
        }
        
        return success;
    }

    // approve() doesn't need reentrancy guard - no external calls
    function approve(address spender, uint256 amount) public override(ERC20, IFundraisingToken) callerWhitelisted returns (bool) {
        return super.approve(spender, amount);
    }

    // View functions
    function isMintAuthorityFrozen() public view override returns (bool) {
        return _mintAuthorityFrozen;
    }

    // Mint function - now frozen after initial mint
    function mint(address to, uint256 amount) public override onlyOwner mintAuthorityNotFrozen {
        if (!_whitelist[to]) {
            revert FundraisingTokenErrors.RecipientMustBeWhitelisted();
        }
        _mint(to, amount);
    }

    // Burn function - no external calls, no reentrancy guard needed
    function burn(uint256 amount) public override callerWhitelisted {
        _burn(_msgSender(), amount);
    }
}

// Interface for reward tracking
interface IRewardTracking {
    function onTokenTransfer(address from, address to, uint256 amount) external;
}