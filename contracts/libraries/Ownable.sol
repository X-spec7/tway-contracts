// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../dependencies/openzeppelin/Context.sol";
import "./errors/FundraisingTokenErrors.sol";

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_owner != _msgSender()) {
            revert FundraisingTokenErrors.CallerNotOwner();
        }
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) {
            revert FundraisingTokenErrors.NewOwnerIsZeroAddress();
        }
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}