// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/Ownable.sol";
import "./libraries/errors/FundraisingErrors.sol";
import "./interfaces/IIEO.sol";

contract IEO is Ownable, IIEO {
    // Storage slots for Yul assembly optimization
    bytes32 internal constant REWARD_TRACKING_ENABLED_SLOT = bytes32(keccak256("ieo.reward.tracking.enabled"));
    bytes32 internal constant IEO_ACTIVE_SLOT = bytes32(keccak256("ieo.active.state"));
    bytes32 internal constant REENTRANCY_GUARD_FLAG_SLOT = bytes32(keccak256("ieo.reentrancy.guard"));
    
    // Reentrancy guard constants
    uint256 internal constant REENTRANCY_GUARD_NOT_ENTERED = 1;
    uint256 internal constant REENTRANCY_GUARD_ENTERED = 2;
    
    // Constants
    address public constant override USDC_ADDRESS = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    uint256 public constant override CLAIM_DELAY = 14 days;
    uint256 public constant override REFUND_PERIOD = 14 days;
    uint256 public constant override MIN_INVESTMENT = 100 * 1e6; // 100 USDC (6 decimals)
    uint256 public constant override MAX_INVESTMENT = 100000 * 1e6; // 100,000 USDC (6 decimals)

    // State variables
    address public immutable override tokenAddress;
    address public override rewardTrackingAddress;
    address public override priceOracle;
    address public override admin;
    
    uint256 public override ieoStartTime;
    uint256 public override ieoEndTime;
    uint256 public override totalRaised;
    uint256 public override totalTokensSold;
    
    mapping(address => Investment) public investments;
    address[] public investors;

    modifier onlyAdmin() {
        if (msg.sender != admin && msg.sender != owner()) {
            revert FundraisingErrors.NotAdmin();
        }
        _;
    }

    modifier onlyIEOActive() {
        if (!isIEOActive() || block.timestamp < ieoStartTime || block.timestamp > ieoEndTime) {
            revert FundraisingErrors.IEONotActive();
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
            revert FundraisingErrors.RewardTrackingNotEnabled();
        }
        _;
    }

    constructor(
        address _tokenAddress,
        address _admin
    ) Ownable(msg.sender) {
        tokenAddress = _tokenAddress;
        rewardTrackingAddress = address(0);
        admin = _admin;
        
        // Initialize reentrancy guard
        setRewardTrackingEnabled(false);
        // Initialize IEO as inactive
        setIEOActive(false);
    }

    // Override functions to satisfy both Ownable and IIEO
    function owner() public view override(Ownable, IIEO) returns (address) {
        return super.owner();
    }

    function transferOwnership(address newOwner) public override(Ownable, IIEO) {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public override(Ownable, IIEO) {
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

    // Yul assembly functions for IEO active state
    function isIEOActive() public view override returns (bool) {
        bytes32 slot = IEO_ACTIVE_SLOT;
        uint256 status;
        assembly ("memory-safe") {
            status := sload(slot)
        }
        return status == 1;
    }

    function setIEOActive(bool active) internal {
        bytes32 slot = IEO_ACTIVE_SLOT;
        uint256 value = active ? 1 : 0;
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

        if (status == REENTRANCY_GUARD_ENTERED) revert FundraisingErrors.ReentrantCallBlocked();
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

    // Setter for reward tracking address
    function setRewardTrackingAddress(address _rewardTrackingAddress) external override onlyOwner {
        if (_rewardTrackingAddress == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        rewardTrackingAddress = _rewardTrackingAddress;
        setRewardTrackingEnabled(true);
        emit RewardTrackingAddressUpdated(_rewardTrackingAddress);
        emit RewardTrackingEnabled(true);
    }

    // Start IEO
    function startIEO(uint256 duration) external override onlyOwner {
        require(!isIEOActive(), "IEO already active");
        
        ieoStartTime = block.timestamp;
        ieoEndTime = block.timestamp + duration;
        setIEOActive(true);
        
        emit IEOStarted(ieoStartTime, ieoEndTime);
    }

    // End IEO
    function endIEO() external override onlyOwner {
        require(isIEOActive(), "IEO not active");
        
        setIEOActive(false);
        emit IEOEnded(totalRaised, totalTokensSold);
    }

    // Invest in IEO
    function invest(uint256 usdcAmount) external override onlyIEOActive nonReentrant {
        if (usdcAmount < MIN_INVESTMENT || usdcAmount > MAX_INVESTMENT) {
            revert FundraisingErrors.InvalidInvestmentAmount();
        }
        
        if (investments[msg.sender].usdcAmount > 0) {
            revert FundraisingErrors.AlreadyInvested();
        }

        // Get token price from oracle
        (uint256 tokenPrice, uint256 priceDecimals) = IPriceOracle(priceOracle).getPrice(tokenAddress);
        if (tokenPrice == 0) {
            revert FundraisingErrors.InvalidPrice();
        }

        // Calculate token amount (USDC has 6 decimals, token has 18 decimals)
        uint256 tokenAmount = (usdcAmount * 1e18 * (10 ** priceDecimals)) / tokenPrice;

        // Transfer USDC from investor
        IERC20(USDC_ADDRESS).transferFrom(msg.sender, address(this), usdcAmount);

        // Record investment
        investments[msg.sender] = Investment({
            usdcAmount: usdcAmount,
            tokenAmount: tokenAmount,
            investmentTime: block.timestamp,
            claimed: false,
            refunded: false
        });

        investors.push(msg.sender);
        totalRaised += usdcAmount;
        totalTokensSold += tokenAmount;

        // Notify reward tracking contract if enabled
        if (isRewardTrackingEnabled() && rewardTrackingAddress != address(0)) {
            IRewardTracking(rewardTrackingAddress).onTokenSold(msg.sender, tokenAmount);
        }

        emit InvestmentMade(msg.sender, usdcAmount, tokenAmount);
    }

    // Claim tokens (after 14 days)
    function claimTokens() external override nonReentrant {
        Investment storage investment = investments[msg.sender];
        
        if (investment.usdcAmount == 0) {
            revert FundraisingErrors.NotInvestor();
        }
        
        if (investment.claimed) {
            revert FundraisingErrors.AlreadyClaimed();
        }
        
        if (block.timestamp < investment.investmentTime + CLAIM_DELAY) {
            revert FundraisingErrors.ClaimPeriodNotStarted();
        }

        investment.claimed = true;

        // Transfer tokens to investor
        IERC20(tokenAddress).transfer(msg.sender, investment.tokenAmount);

        emit TokensClaimed(msg.sender, investment.tokenAmount);
    }

    // Refund investment (within 14 days)
    function refundInvestment() external override nonReentrant {
        Investment storage investment = investments[msg.sender];
        
        if (investment.usdcAmount == 0) {
            revert FundraisingErrors.NotInvestor();
        }
        
        if (investment.refunded) {
            revert FundraisingErrors.AlreadyRefunded();
        }
        
        if (block.timestamp > investment.investmentTime + REFUND_PERIOD) {
            revert FundraisingErrors.RefundPeriodEnded();
        }

        investment.refunded = true;

        // Transfer USDC back to investor
        IERC20(USDC_ADDRESS).transfer(msg.sender, investment.usdcAmount);

        emit InvestmentRefunded(msg.sender, investment.usdcAmount);
    }

    // Release USDC to reward tracking contract (after 30 days)
    function releaseUSDCToRewardTracking() external override onlyOwner rewardTrackingEnabled {
        require(block.timestamp >= ieoEndTime + 30 days, "30 days not passed since IEO ended");
        
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance > 0) {
            IERC20(USDC_ADDRESS).transfer(rewardTrackingAddress, usdcBalance);
        }
    }

    // Admin functions
    function setPriceOracle(address _priceOracle) external override onlyAdmin {
        if (_priceOracle == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        priceOracle = _priceOracle;
        emit PriceOracleUpdated(_priceOracle);
    }

    function setAdmin(address _admin) external override onlyOwner {
        if (_admin == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        admin = _admin;
        emit AdminUpdated(_admin);
    }

    // Emergency functions
    function emergencyWithdrawUSDC(uint256 amount) external override onlyOwner {
        IERC20(USDC_ADDRESS).transfer(owner(), amount);
    }

    // View functions
    function getInvestment(address investor) external view override returns (Investment memory) {
        return investments[investor];
    }

    function getInvestorCount() external view override returns (uint256) {
        return investors.length;
    }

    function getInvestor(uint256 index) external view override returns (address) {
        return investors[index];
    }

    function getIEOStatus() external view override returns (bool) {
        return isIEOActive() && block.timestamp >= ieoStartTime && block.timestamp <= ieoEndTime;
    }

    function getUSDCBalance() external view override returns (uint256) {
        return IERC20(USDC_ADDRESS).balanceOf(address(this));
    }
}

// Interface for reward tracking
interface IRewardTracking {
    function onTokenSold(address user, uint256 amount) external;
}