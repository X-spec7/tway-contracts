// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./dependencies/openzeppelin/ERC20.sol";
import "./libraries/Ownable.sol";
import "./libraries/errors/FundraisingTokenErrors.sol";

contract FundraisingToken is ERC20, Ownable {
    uint8 private _decimals;
    bool private _mintAuthorityFrozen;
    
    // Whitelist mapping
    mapping(address => bool) private _whitelist;
    
    // Events
    event AddressWhitelisted(address indexed account);
    event AddressRemovedFromWhitelist(address indexed account);
    event MintAuthorityFrozen();
    
    // Modifier to check if both sender and receiver are whitelisted
    modifier onlyWhitelisted(address from, address to) {
        if (!_whitelist[from]) {
            revert FundraisingTokenErrors.SenderNotWhitelisted();
        }
        if (!_whitelist[to]) {
            revert FundraisingTokenErrors.RecipientNotWhitelisted();
        }
        _;
    }
    
    // Modifier to check if caller is whitelisted
    modifier callerWhitelisted() {
        if (!_whitelist[_msgSender()]) {
            revert FundraisingTokenErrors.CallerNotWhitelisted();
        }
        _;
    }

    // Modifier to check if mint authority is not frozen
    modifier mintAuthorityNotFrozen() {
        if (_mintAuthorityFrozen) {
            revert FundraisingTokenErrors.MintAuthorityFrozen();
        }
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) Ownable(_msgSender()) {
        _decimals = decimals_;
        
        // Add deployer to whitelist
        _whitelist[_msgSender()] = true;
        emit AddressWhitelisted(_msgSender());
        
        // Mint initial supply
        _mint(_msgSender(), initialSupply * 10**decimals_);
        
        // Freeze mint authority after initial mint
        _mintAuthorityFrozen = true;
        emit MintAuthorityFrozen();
    }

    // Override ERC20 functions to add whitelist checks
    function transfer(address to, uint256 amount) public override onlyWhitelisted(_msgSender(), to) returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override onlyWhitelisted(from, to) returns (bool) {
        // Check whitelist first, then call parent function
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override callerWhitelisted returns (bool) {
        if (!_whitelist[spender]) {
            revert FundraisingTokenErrors.SpenderNotWhitelisted();
        }
        return super.approve(spender, amount);
    }

    // Override decimals function
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    // Whitelist management functions (only owner)
    function addToWhitelist(address account) public onlyOwner {
        if (account == address(0)) {
            revert FundraisingTokenErrors.CannotWhitelistZeroAddress();
        }
        if (_whitelist[account]) {
            revert FundraisingTokenErrors.AddressAlreadyWhitelisted();
        }
        
        _whitelist[account] = true;
        emit AddressWhitelisted(account);
    }

    function removeFromWhitelist(address account) public onlyOwner {
        if (!_whitelist[account]) {
            revert FundraisingTokenErrors.AddressNotWhitelisted();
        }
        
        _whitelist[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist[account];
    }

    function batchAddToWhitelist(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && !_whitelist[accounts[i]]) {
                _whitelist[accounts[i]] = true;
                emit AddressWhitelisted(accounts[i]);
            }
        }
    }

    function batchRemoveFromWhitelist(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (_whitelist[accounts[i]]) {
                _whitelist[accounts[i]] = false;
                emit AddressRemovedFromWhitelist(accounts[i]);
            }
        }
    }

    // Mint function - now frozen after initial mint
    function mint(address to, uint256 amount) public onlyOwner mintAuthorityNotFrozen {
        if (!_whitelist[to]) {
            revert FundraisingTokenErrors.RecipientMustBeWhitelisted();
        }
        _mint(to, amount);
    }

    // Burn function
    function burn(uint256 amount) public callerWhitelisted {
        _burn(_msgSender(), amount);
    }

    // View function to check if mint authority is frozen
    function isMintAuthorityFrozen() public view returns (bool) {
        return _mintAuthorityFrozen;
    }
}