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
    bytes32 internal constant IEO_PAUSED_SLOT = bytes32(keccak256("ieo.paused.state"));
    bytes32 internal constant REENTRANCY_GUARD_FLAG_SLOT = bytes32(keccak256("ieo.reentrancy.guard"));
    
    // Reentrancy guard constants
    uint8 internal constant REENTRANCY_GUARD_NOT_ENTERED = 1;
    uint8 internal constant REENTRANCY_GUARD_ENTERED = 2;
    
    // Constants
    address public constant override USDC_ADDRESS = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    uint8 public constant MAX_PRICE_DECIMALS = 18; // Maximum allowed price decimals
    
    // Immutable variables set during deployment
    address public immutable override tokenAddress;
    address public immutable override admin;
    uint32 public immutable override CLAIM_DELAY;
    uint32 public immutable override REFUND_PERIOD;
    uint128 public immutable override MIN_INVESTMENT;
    uint128 public immutable override MAX_INVESTMENT;
    uint32 public immutable WITHDRAWAL_DELAY; // Same as claim/refund delay
    
    // State variables - optimally packed for gas efficiency
    
    // Addresses (20 bytes each) - group together
    address public override rewardTrackingAddress;
    address public override priceOracle;
    address public businessAdmin; // Changed from immutable to allow updates
    
    // Time variables (8 bytes each) - can pack 2 per slot
    uint64 public override ieoStartTime;
    uint64 public override ieoEndTime;
    
    // Amount variables (16 bytes each) - can pack 2 per slot
    uint128 public override totalRaised;
    uint128 public override totalTokensSold;
    uint128 public totalDeposited;        // Total USDC received from all investments
    uint128 public totalWithdrawn;        // Total USDC withdrawn by business admin
    
    // Price variables (16 bytes each) - can pack 2 per slot
    uint128 public minTokenPrice;        // Minimum acceptable token price
    uint128 public maxTokenPrice;        // Maximum acceptable token price
    uint128 public lastValidPrice;       // Last valid price for deviation check
    
    // Configuration variables (4 bytes each) - can pack 8 per slot
    uint32 public priceStalenessThreshold; // Maximum age of price data (in seconds)
    uint32 public investmentCounter;      // Investment counter for unique IDs
    
    // Small variables (2 bytes and 1 byte) - can pack many per slot
    uint16 public maxPriceDeviation;    // Maximum price deviation percentage (in basis points)
    bool public circuitBreakerEnabled;   // Whether circuit breaker is enabled
    bool public circuitBreakerTriggered; // Whether circuit breaker is currently triggered
    
    // Mappings and arrays (separate storage)
    mapping(address => Investment[]) public userInvestments;  // Array of investments per user
    mapping(address => bool) public isInvestor;               // Track if user has ever invested
    address[] public investors;                               // List of all investors

    modifier onlyBusinessAdmin() {
        if (msg.sender != businessAdmin && msg.sender != owner()) {
            revert FundraisingErrors.NotAdmin();
        }
        _;
    }

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

    modifier whenNotPaused() {
        if (isIEOActive() && isPaused()) {
            revert FundraisingErrors.IEOPaused();
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

    modifier circuitBreakerNotTriggered() {
        if (circuitBreakerEnabled && circuitBreakerTriggered) {
            revert FundraisingErrors.CircuitBreakerTriggered();
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
        businessAdmin = _businessAdmin; // Now a state variable
        
        CLAIM_DELAY = uint32(_delayDays * 1 days);
        REFUND_PERIOD = uint32(_delayDays * 1 days); // Same as claim delay
        MIN_INVESTMENT = uint128(_minInvestment);
        MAX_INVESTMENT = uint128(_maxInvestment);
        WITHDRAWAL_DELAY = uint32(_delayDays * 1 days); // Same as claim/refund delay
        
        // Initialize state variables
        rewardTrackingAddress = address(0);
        
        // Initialize price validation (disabled by default - no bounds set)
        minTokenPrice = 0;
        maxTokenPrice = 0;
        
        // Initialize oracle circuit breaker (disabled by default)
        priceStalenessThreshold = 3600; // 1 hour default
        maxPriceDeviation = 1000; // 10% default (1000 basis points)
        lastValidPrice = 0;
        circuitBreakerEnabled = false;
        circuitBreakerTriggered = false;
        
        // Initialize reentrancy guard
        setRewardTrackingEnabled(false);
        // Initialize IEO as inactive
        setIEOActive(false);
        // Initialize as not paused
        setPaused(false);
    }

    // Override functions to satisfy both Ownable and IIEO
    function owner()
        override(Ownable, IIEO)
        public
        view
        returns (address)
    {
        return super.owner();
    }

    function transferOwnership(address newOwner)
        override(Ownable, IIEO)
        public
    {
        super.transferOwnership(newOwner);
    }

    function renounceOwnership()
        override(Ownable, IIEO)
        public
    {
        super.renounceOwnership();
    }

    // Yul assembly functions for reward tracking enabled state
    function isRewardTrackingEnabled()
        public
        view
        returns (bool)
    {
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

    // Yul assembly functions for IEO paused state
    function isPaused() public view returns (bool) {
        bytes32 slot = IEO_PAUSED_SLOT;
        uint256 status;
        assembly ("memory-safe") {
            status := sload(slot)
        }
        return status == 1;
    }

    function setPaused(bool paused) internal {
        bytes32 slot = IEO_PAUSED_SLOT;
        uint256 value = paused ? 1 : 0;
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
    function setRewardTrackingAddress(address _rewardTrackingAddress)
        external
        onlyOwner
    {
        if (_rewardTrackingAddress == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        rewardTrackingAddress = _rewardTrackingAddress;
        setRewardTrackingEnabled(true);
        emit RewardTrackingAddressUpdated(_rewardTrackingAddress);
        emit RewardTrackingEnabled(true);
    }

    // Setter for business admin address (admin only)
    function setBusinessAdmin(address _businessAdmin)
        external
        onlyAdmin
    {
        if (_businessAdmin == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        
        address oldBusinessAdmin = businessAdmin;
        businessAdmin = _businessAdmin;
        
        emit BusinessAdminUpdated(oldBusinessAdmin, _businessAdmin);
    }

    // Price validation management (business admin only)
    function setPriceValidation(uint256 _minTokenPrice, uint256 _maxTokenPrice)
        external
        onlyBusinessAdmin
    {
        if (_minTokenPrice > 0 && _maxTokenPrice > 0 && _minTokenPrice >= _maxTokenPrice) {
            revert FundraisingErrors.InvalidInvestmentRange(); // Reuse existing error for price range
        }
        
        minTokenPrice = _minTokenPrice;
        maxTokenPrice = _maxTokenPrice;
        
        emit PriceValidationUpdated(_minTokenPrice, _maxTokenPrice, _minTokenPrice > 0 || _maxTokenPrice > 0);
    }

    // Oracle circuit breaker management (business admin only)
    function setCircuitBreaker(
        uint256 _priceStalenessThreshold,
        uint256 _maxPriceDeviation,
        bool _enabled
    )
        external
        onlyBusinessAdmin
    {
        require(_priceStalenessThreshold > 0, "Invalid staleness threshold");
        require(_maxPriceDeviation <= 10000, "Invalid deviation percentage"); // Max 100%
        
        priceStalenessThreshold = _priceStalenessThreshold;
        maxPriceDeviation = _maxPriceDeviation;
        circuitBreakerEnabled = _enabled;
        
        // Reset circuit breaker if enabling
        if (_enabled) {
            circuitBreakerTriggered = false;
        }
        
        emit CircuitBreakerUpdated(_priceStalenessThreshold, _maxPriceDeviation, _enabled);
    }

    function resetCircuitBreaker() external onlyBusinessAdmin {
        circuitBreakerTriggered = false;
        emit CircuitBreakerReset();
    }

    function enableCircuitBreaker() external onlyBusinessAdmin {
        circuitBreakerEnabled = true;
        circuitBreakerTriggered = false;
        emit CircuitBreakerEnabled(true);
    }

    function disableCircuitBreaker()
        external
        onlyBusinessAdmin
    {
        circuitBreakerEnabled = false;
        circuitBreakerTriggered = false;
        emit CircuitBreakerEnabled(false);
    }

    // Pause/Unpause functions (business admin only)
    function pauseIEO() external onlyBusinessAdmin {
        require(isIEOActive(), "IEO not active");
        require(!isPaused(), "IEO already paused");
        
        setPaused(true);
        emit IEOpaused();
    }

    function unpauseIEO() external onlyBusinessAdmin {
        require(isIEOActive(), "IEO not active");
        require(isPaused(), "IEO not paused");
        
        setPaused(false);
        emit IEOunpaused();
    }

    // Start IEO
    function startIEO(uint256 duration)
        external
        onlyBusinessAdmin
    {
        require(!isIEOActive(), "IEO already active");
        
        ieoStartTime = uint64(block.timestamp);
        ieoEndTime = uint64(block.timestamp + duration);
        setIEOActive(true);
        setPaused(false); // Ensure not paused when starting
        
        emit IEOStarted(ieoStartTime, ieoEndTime);
    }

    // End IEO
    function endIEO() external override onlyBusinessAdmin {
        require(isIEOActive(), "IEO not active");
        
        setIEOActive(false);
        setPaused(false); // Ensure not paused when ending
        emit IEOEnded(totalRaised, totalTokensSold);
    }

    function calculateTokenAmount(uint256 usdcAmount, uint256 tokenPrice, uint256 priceDecimals)
        internal
        pure
        returns (uint256)
    {
        // Validate priceDecimals range to prevent overflow
        require(priceDecimals <= MAX_PRICE_DECIMALS, "Price decimals too high");
        
        // Calculate multiplier safely
        uint256 multiplier = 10 ** priceDecimals;
        
        // Calculate numerator
        uint256 numerator = usdcAmount * 1e18 * multiplier;
        
        // Validate no overflow occurred by checking the reverse calculation
        require(numerator / usdcAmount / 1e18 == multiplier, "Overflow in token calculation");
        
        return numerator / tokenPrice;
    }

    // Invest in IEO (supports multiple separate investments)
    function invest(uint256 usdcAmount)
        external
        nonReentrant
        circuitBreakerNotTriggered
    {
        if (usdcAmount < MIN_INVESTMENT || usdcAmount > MAX_INVESTMENT) {
            revert FundraisingErrors.InvalidInvestmentAmount();
        }

        // Get token price from oracle (now includes timestamp)
        (uint256 tokenPrice, uint256 priceDecimals, uint256 priceTimestamp) = IPriceOracle(priceOracle).getPrice(tokenAddress);
        if (tokenPrice == 0) {
            revert FundraisingErrors.InvalidPrice();
        }

        // Apply oracle circuit breaker checks
        _validateOraclePrice(tokenPrice, priceTimestamp);

        // Validate price if bounds are set (price validation is always enabled when bounds exist)
        if (minTokenPrice > 0 || maxTokenPrice > 0) {
            if (minTokenPrice > 0 && tokenPrice < minTokenPrice) {
                revert FundraisingErrors.InvalidPrice();
            }
            if (maxTokenPrice > 0 && tokenPrice > maxTokenPrice) {
                revert FundraisingErrors.InvalidPrice();
            }
        }

        // Calculate token amount 
        uint256 tokenAmount = calculateTokenAmount(usdcAmount, tokenPrice, priceDecimals);

        // Transfer USDC from investor
        IERC20(USDC_ADDRESS).transferFrom(msg.sender, address(this), usdcAmount);
        totalDeposited += uint128(usdcAmount);

        // Create new separate investment
        Investment memory newInvestment = Investment({
            usdcAmount: uint128(usdcAmount),
            tokenAmount: uint128(tokenAmount),
            investmentTime: uint64(block.timestamp),
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

        
        totalRaised += uint128(usdcAmount);
        totalTokensSold += uint128(tokenAmount);

        // Notify reward tracking contract if enabled
        if (isRewardTrackingEnabled() && rewardTrackingAddress != address(0)) {
            IRewardTracking(rewardTrackingAddress).onTokenSold(msg.sender, tokenAmount);
        }

        emit InvestmentMade(msg.sender, usdcAmount, tokenAmount);
    }

    // Internal function to validate oracle price
    function _validateOraclePrice(uint256 tokenPrice, uint256 priceTimestamp)
        internal
    {
        if (!circuitBreakerEnabled) {
            return; // Circuit breaker disabled, skip validation
        }

        uint256 currentTime = block.timestamp;

        // Check price staleness using oracle timestamp
        if (currentTime - priceTimestamp > priceStalenessThreshold) {
            circuitBreakerTriggered = true;
            emit CircuitBreakerTriggered("Price too stale");
            revert FundraisingErrors.CircuitBreakerTriggered();
        }

        // Check price deviation (only if we have a previous price)
        if (lastValidPrice > 0) {
            uint256 priceChange = tokenPrice > lastValidPrice 
                ? ((tokenPrice - lastValidPrice) * 10000) / lastValidPrice
                : ((lastValidPrice - tokenPrice) * 10000) / lastValidPrice;

            if (priceChange > maxPriceDeviation) {
                circuitBreakerTriggered = true;
                emit CircuitBreakerTriggered("Price deviation too high");
                revert FundraisingErrors.CircuitBreakerTriggered();
            }
        }

        // Update oracle state
        lastValidPrice = tokenPrice;
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

    // Refund specific investment by index
    function refundInvestmentByIndex(uint256 investmentIndex)
        external
        nonReentrant
    {
        Investment[] storage investments = userInvestments[msg.sender];
        
        if (investments.length == 0) {
            revert FundraisingErrors.NotInvestor();
        }
        
        if (investmentIndex >= investments.length) {
            revert("Investment index out of bounds");
        }

        Investment storage investment = investments[investmentIndex];
        
        // Check if already claimed or refunded
        if (investment.claimed) {
            revert("Investment already claimed");
        }
        
        if (investment.refunded) {
            revert("Investment already refunded");
        }
        
        // Check if this investment is refundable (within refund period)
        if (block.timestamp > investment.investmentTime + REFUND_PERIOD) {
            revert FundraisingErrors.RefundPeriodEnded();
        }

        // Mark as refunded
        investment.refunded = true;

        // Transfer USDC back to investor
        IERC20(USDC_ADDRESS).transfer(msg.sender, investment.usdcAmount);

        emit InvestmentRefunded(msg.sender, investment.usdcAmount);
    }

    // Refund all refundable investments
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
    function withdrawUSDC(uint256 amount)
        external
        onlyBusinessAdmin
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getWithdrawableAmount(), "Amount exceeds withdrawable amount");
        
        totalWithdrawn += amount;
        IERC20(USDC_ADDRESS).transfer(businessAdmin, amount);
        
        emit USDCWithdrawn(businessAdmin, amount);
    }

    // Withdraw all available USDC
    function withdrawAllUSDC()
        external
        onlyBusinessAdmin
        nonReentrant
    {
        uint256 withdrawableAmount = getWithdrawableAmount();
        require(withdrawableAmount > 0, "No withdrawable amount");
        
        totalWithdrawn += withdrawableAmount;
        IERC20(USDC_ADDRESS).transfer(businessAdmin, withdrawableAmount);
        
        emit USDCWithdrawn(businessAdmin, withdrawableAmount);
    }

    // Release USDC to reward tracking contract (after 30 days)
    function releaseUSDCToRewardTracking()
        external
        onlyOwner
        rewardTrackingEnabled
    {
        require(block.timestamp >= ieoEndTime + 30 days, "30 days not passed since IEO ended");
        
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance > 0) {
            IERC20(USDC_ADDRESS).transfer(rewardTrackingAddress, usdcBalance);
        }
    }

    // Set admin address (interface compliance)
    function setAdmin(address _admin)
        external
        onlyOwner
    {
        // Note: admin is immutable, so this function cannot actually change it
        // This is kept for interface compliance but will always revert
        revert("Admin address is immutable")
        external
        onlyOwner
    {
        if (_priceOracle == address(0)) {
            revert FundraisingErrors.ZeroAddress();
        }
        priceOracle = _priceOracle;
        emit PriceOracleUpdated(_priceOracle);
    }

    // Emergency functions
    function emergencyWithdrawUSDC(uint256 amount)
        external
        onlyOwner
    {
        IERC20(USDC_ADDRESS).transfer(owner(), amount);
    }

    // View functions
    function getInvestment(address investor)
        external
        view
        returns (Investment memory)
    {
        // Return the latest investment for backward compatibility
        Investment[] memory investments = userInvestments[investor];
        if (investments.length == 0) {
            return Investment(0, 0, 0, false, false);
        }
        return investments[investments.length - 1];
    }

    function getUserInvestments(address investor)
        external
        view
        returns (Investment[] memory)
    {
        return userInvestments[investor];
    }

    function getUserInvestmentCount(address investor)
        external
        view
        returns (uint256)
    {
        return userInvestments[investor].length;
    }

    // Get specific investment by index
    function getUserInvestmentByIndex(address investor, uint256 index)
        external
        view
        returns (Investment memory)
    {
        Investment[] memory investments = userInvestments[investor];
        if (index >= investments.length) {
            revert("Investment index out of bounds");
        }
        return investments[index];
    }

    // Get refundable investments for a user
    function getRefundableInvestments(address investor)
        external
        view
        returns (uint256[] memory refundableIndices)
    {
        Investment[] memory investments = userInvestments[investor];
        uint256 currentTime = block.timestamp;
        uint256 refundableCount = 0;
        
        // First pass: count refundable investments
        for (uint256 i = 0; i < investments.length; i++) {
            Investment memory investment = investments[i];
            if (!investment.claimed && !investment.refunded && 
                currentTime <= investment.investmentTime + REFUND_PERIOD) {
                refundableCount++;
            }
        }
        
        // Second pass: collect refundable indices
        refundableIndices = new uint256[](refundableCount);
        uint256 index = 0;
        for (uint256 i = 0; i < investments.length; i++) {
            Investment memory investment = investments[i];
            if (!investment.claimed && !investment.refunded && 
                currentTime <= investment.investmentTime + REFUND_PERIOD) {
                refundableIndices[index] = i;
                index++;
            }
        }
    }

    // Get claimable investments for a user
    function getClaimableInvestments(address investor)
        external
        view
        returns (uint256[] memory claimableIndices)
    {
        Investment[] memory investments = userInvestments[investor];
        uint256 currentTime = block.timestamp;
        uint256 claimableCount = 0;
        
        // First pass: count claimable investments
        for (uint256 i = 0; i < investments.length; i++) {
            Investment memory investment = investments[i];
            if (!investment.claimed && !investment.refunded && 
                currentTime >= investment.investmentTime + CLAIM_DELAY) {
                claimableCount++;
            }
        }
        
        // Second pass: collect claimable indices
        claimableIndices = new uint256[](claimableCount);
        uint256 index = 0;
        for (uint256 i = 0; i < investments.length; i++) {
            Investment memory investment = investments[i];
            if (!investment.claimed && !investment.refunded && 
                currentTime >= investment.investmentTime + CLAIM_DELAY) {
                claimableIndices[index] = i;
                index++;
            }
        }
    }

    function getInvestorCount()
        external
        view
        returns (uint256)
    {
        return investors.length;
    }

    function getInvestor(uint256 index)
        external
        view
        returns (address)
    {
        return investors[index];
    }

    function getIEOStatus()
        external
        view
        returns (bool)
    {
        return isIEOActive() && block.timestamp >= ieoStartTime && block.timestamp <= ieoEndTime;
    }

    function getUSDCBalance()
        external
        view
        returns (uint256)
    {
        return IERC20(USDC_ADDRESS).balanceOf(address(this));
    }

    // New view functions for withdrawal tracking
    function getWithdrawableAmount()
        public
        view
        returns (uint256)
    {
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

    function getTotalDeposited()
        external
        view
        returns (uint256)
    {
        return totalDeposited;
    }

    function getTotalWithdrawn()
        external
        view
        returns (uint256)
    {
        return totalWithdrawn;
    }

    function getBusinessAdmin()
        external
        view
        returns (address)
    {
        return businessAdmin;
    }

    function getWithdrawalDelay()
        external
        view
        returns (uint256)
    {
        return WITHDRAWAL_DELAY;
    }

    // Helper function to get withdrawable amount for a specific investor
    function getInvestorWithdrawableAmount(address investor)
        external
        view
        returns (uint256)
    {
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

    // Price validation view functions
    function getMinTokenPrice()
        external
        view
        returns (uint256)
    {
        return minTokenPrice;
    }

    function getMaxTokenPrice()
        external
        view
        returns (uint256)
    {
        return maxTokenPrice;
    }

    function isPriceValidationEnabled()
        external
        view
        returns (bool)
    {
        return minTokenPrice > 0 || maxTokenPrice > 0;
    }

    // Oracle circuit breaker view functions
    function getPriceStalenessThreshold()
        external
        view
        returns (uint256)
    {
        return priceStalenessThreshold;
    }

    function getMaxPriceDeviation()
        external
        view
        returns (uint256)
    {
        return maxPriceDeviation;
    }

    function getLastValidPrice()
        external
        view
        returns (uint256)
    {
        return lastValidPrice;
    }

    function isCircuitBreakerEnabled()
        external
        view
        returns (bool)
    {
        return circuitBreakerEnabled;
    }

    function isCircuitBreakerTriggered()
        external
        view
        returns (bool)
    {
        return circuitBreakerTriggered;
    }
}

// Interface for reward tracking
interface IRewardTracking {
    function onTokenSold(address user, uint256 amount) external;
}

// New events for price validation and circuit breaker
event PriceValidationUpdated(uint256 minPrice, uint256 maxPrice, bool enabled);
event CircuitBreakerUpdated(uint256 stalenessThreshold, uint256 maxDeviation, bool enabled);
event CircuitBreakerTriggered(string reason);
event CircuitBreakerReset();
event CircuitBreakerEnabled(bool enabled);
event USDCWithdrawn(address indexed businessAdmin, uint256 amount);
event IEOpaused();
event IEOunpaused();
event BusinessAdminUpdated(address indexed oldBusinessAdmin, address indexed newBusinessAdmin);