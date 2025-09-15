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
    
    // Immutable variables set during deployment
    address public immutable override tokenAddress;
    address public immutable override admin;
    address public immutable businessAdmin;
    uint256 public immutable override CLAIM_DELAY;
    uint256 public immutable override REFUND_PERIOD;
    uint256 public immutable override MIN_INVESTMENT;
    uint256 public immutable override MAX_INVESTMENT;
    uint256 public immutable WITHDRAWAL_DELAY; // Same as claim/refund delay
    
    // State variables
    address public override rewardTrackingAddress;
    address public override priceOracle;
    
    uint256 public override ieoStartTime;
    uint256 public override ieoEndTime;
    uint256 public override totalRaised;
    uint256 public override totalTokensSold;
    
    // Withdrawal tracking (per-investment based)
    uint256 public totalDeposited;        // Total USDC received from all investments
    uint256 public totalWithdrawn;        // Total USDC withdrawn by business admin
    
    // Separate investment tracking
    mapping(address => Investment[]) public userInvestments;  // Array of investments per user
    mapping(address => bool) public isInvestor;               // Track if user has ever invested
    address[] public investors;                               // List of all investors
    
    // Investment counter for unique IDs
    uint256 public investmentCounter;

    modifier onlyAdmin() {
        if (msg.sender != admin && msg.sender != owner()) {
            revert FundraisingErrors.NotAdmin();
        }
        _;
    }

    modifier onlyBusinessAdmin() {
        if (msg.sender != businessAdmin && msg.sender != owner()) {
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
        address _admin,
        address _businessAdmin,
        uint256 _delayDays,
        uint256 _minInvestment,
        uint256 _maxInvestment
    ) Ownable(msg.sender) {
        if (_tokenAddress == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        if (_admin == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        if (_businessAdmin == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        if (_delayDays == 0) {
            revert FundraisingErrors.InvalidDelayDays();
        }
        if (_minInvestment == 0) {
            revert FundraisingErrors.InvalidMinInvestment();
        }
        if (_maxInvestment <= _minInvestment) {
            revert FundraisingErrors.InvalidInvestmentRange();
        }
        
        // Assign immutable variables
        tokenAddress = _tokenAddress;
        admin = _admin;
        businessAdmin = _businessAdmin;
        CLAIM_DELAY = _delayDays * 1 days;
        REFUND_PERIOD = _delayDays * 1 days; // Same as claim delay
        MIN_INVESTMENT = _minInvestment;
        MAX_INVESTMENT = _maxInvestment;
        WITHDRAWAL_DELAY = _delayDays * 1 days; // Same as claim/refund delay
        
        // Initialize state variables
        rewardTrackingAddress = address(0);
        
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

    // Invest in IEO (supports multiple separate investments)
    function invest(uint256 usdcAmount) external override onlyIEOActive nonReentrant {
        if (usdcAmount < MIN_INVESTMENT || usdcAmount > MAX_INVESTMENT) {
            revert FundraisingErrors.InvalidInvestmentAmount();
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

        // Update total deposited
        totalDeposited += usdcAmount;

        // Create new separate investment
        Investment memory newInvestment = Investment({
            usdcAmount: usdcAmount,
            tokenAmount: tokenAmount,
            investmentTime: block.timestamp,
            claimed: false,
            refunded: false
        });

        // Add to user's investments array
        userInvestments[msg.sender].push(newInvestment);

        // Track if this is first investment
        if (!isInvestor[msg.sender]) {
            isInvestor[msg.sender] = true;
            investors.push(msg.sender);
        }

        totalRaised += usdcAmount;
        totalTokensSold += tokenAmount;

        // Notify reward tracking contract if enabled
        if (isRewardTrackingEnabled() && rewardTrackingAddress != address(0)) {
            IRewardTracking(rewardTrackingAddress).onTokenSold(msg.sender, tokenAmount);
        }

        emit InvestmentMade(msg.sender, usdcAmount, tokenAmount);
    }

    // Claim tokens (after claim delay) - claims all unclaimed investments
    function claimTokens() external override nonReentrant {
        Investment[] storage investments = userInvestments[msg.sender];
        
        if (investments.length == 0) {
            revert FundraisingErrors.NotInvestor();
        }

        uint256 totalClaimableTokens = 0;
        uint256 currentTime = block.timestamp;

        // Check all investments for claimable tokens
        for (uint256 i = 0; i < investments.length; i++) {
            Investment storage investment = investments[i];
            
            // Skip if already claimed or refunded
            if (investment.claimed || investment.refunded) {
                continue;
            }
            
            // Check if this investment is claimable (after claim delay)
            if (currentTime >= investment.investmentTime + CLAIM_DELAY) {
                totalClaimableTokens += investment.tokenAmount;
                investment.claimed = true;
            }
        }

        if (totalClaimableTokens == 0) {
            revert FundraisingErrors.ClaimPeriodNotStarted();
        }

        // Transfer all claimable tokens to investor
        IERC20(tokenAddress).transfer(msg.sender, totalClaimableTokens);

        emit TokensClaimed(msg.sender, totalClaimableTokens);
    }

    // Refund investment (within refund period) - refunds all refundable investments
    function refundInvestment() external override nonReentrant {
        Investment[] storage investments = userInvestments[msg.sender];
        
        if (investments.length == 0) {
            revert FundraisingErrors.NotInvestor();
        }

        uint256 totalRefundableUSDC = 0;
        uint256 currentTime = block.timestamp;

        // Check all investments for refundable USDC
        for (uint256 i = 0; i < investments.length; i++) {
            Investment storage investment = investments[i];
            
            // Skip if already claimed or refunded
            if (investment.claimed || investment.refunded) {
                continue;
            }
            
            // Check if this investment is refundable (within refund period)
            if (currentTime <= investment.investmentTime + REFUND_PERIOD) {
                totalRefundableUSDC += investment.usdcAmount;
                investment.refunded = true;
            }
        }

        if (totalRefundableUSDC == 0) {
            revert FundraisingErrors.RefundPeriodEnded();
        }

        // Transfer all refundable USDC back to investor
        IERC20(USDC_ADDRESS).transfer(msg.sender, totalRefundableUSDC);

        emit InvestmentRefunded(msg.sender, totalRefundableUSDC);
    }

    // Business admin withdrawal (after per-investment delay)
    function withdrawUSDC(uint256 amount) external onlyBusinessAdmin nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getWithdrawableAmount(), "Amount exceeds withdrawable amount");
        
        totalWithdrawn += amount;
        IERC20(USDC_ADDRESS).transfer(businessAdmin, amount);
        
        emit USDCWithdrawn(businessAdmin, amount);
    }

    // Withdraw all available USDC
    function withdrawAllUSDC() external onlyBusinessAdmin nonReentrant {
        uint256 withdrawableAmount = getWithdrawableAmount();
        require(withdrawableAmount > 0, "No withdrawable amount");
        
        totalWithdrawn += withdrawableAmount;
        IERC20(USDC_ADDRESS).transfer(businessAdmin, withdrawableAmount);
        
        emit USDCWithdrawn(businessAdmin, withdrawableAmount);
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
        // Note: admin is immutable, so this function cannot actually change it
        // This is kept for interface compliance but will always revert
        revert("Admin address is immutable");
    }

    // Emergency functions
    function emergencyWithdrawUSDC(uint256 amount) external override onlyOwner {
        IERC20(USDC_ADDRESS).transfer(owner(), amount);
    }

    // View functions
    function getInvestment(address investor) external view override returns (Investment memory) {
        // Return the latest investment for backward compatibility
        Investment[] memory investments = userInvestments[investor];
        if (investments.length == 0) {
            return Investment(0, 0, 0, false, false);
        }
        return investments[investments.length - 1];
    }

    function getUserInvestments(address investor) external view returns (Investment[] memory) {
        return userInvestments[investor];
    }

    function getUserInvestmentCount(address investor) external view returns (uint256) {
        return userInvestments[investor].length;
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

    // New view functions for withdrawal tracking
    function getWithdrawableAmount() public view returns (uint256) {
        uint256 withdrawable = 0;
        uint256 currentTime = block.timestamp;
        
        // Check each investor's investments
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            Investment[] memory investments = userInvestments[investor];
            
            // Check each investment separately
            for (uint256 j = 0; j < investments.length; j++) {
                Investment memory investment = investments[j];
                
                // Skip if already refunded
                if (investment.refunded) {
                    continue;
                }
                
                // Check if this investment is withdrawable (14 days after investment)
                if (currentTime >= investment.investmentTime + WITHDRAWAL_DELAY) {
                    withdrawable += investment.usdcAmount;
                }
            }
        }
        
        // Subtract already withdrawn amount
        return withdrawable > totalWithdrawn ? withdrawable - totalWithdrawn : 0;
    }

    function getTotalDeposited() external view returns (uint256) {
        return totalDeposited;
    }

    function getTotalWithdrawn() external view returns (uint256) {
        return totalWithdrawn;
    }

    function getBusinessAdmin() external view returns (address) {
        return businessAdmin;
    }

    function getWithdrawalDelay() external view returns (uint256) {
        return WITHDRAWAL_DELAY;
    }

    // Helper function to get withdrawable amount for a specific investor
    function getInvestorWithdrawableAmount(address investor) external view returns (uint256) {
        Investment[] memory investments = userInvestments[investor];
        uint256 withdrawable = 0;
        uint256 currentTime = block.timestamp;
        
        for (uint256 i = 0; i < investments.length; i++) {
            Investment memory investment = investments[i];
            
            if (investment.refunded) {
                continue;
            }
            
            if (currentTime >= investment.investmentTime + WITHDRAWAL_DELAY) {
                withdrawable += investment.usdcAmount;
            }
        }
        
        return withdrawable;
    }
}

// Interface for reward tracking
interface IRewardTracking {
    function onTokenSold(address user, uint256 amount) external;
}

// New event for USDC withdrawal
event USDCWithdrawn(address indexed businessAdmin, uint256 amount);