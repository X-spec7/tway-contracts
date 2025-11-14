# Tway Fundraising System

A complete fundraising platform with ERC20 token, IEO (Initial Exchange Offering), and reward tracking system.

##  Overview

This project provides a comprehensive fundraising solution with:
- **FundraisingToken**: Whitelisted ERC20 token with frozen mint authority and reward-tracking callbacks
- **IEO Contract**: Token sales with price oracle integration, price safeguards, and time-based controls
- **Reward Tracking**: Automated USDC reward distribution for token holders

##  Key Features

### FundraisingToken
-  ERC20 with strict whitelist checks on sender and recipient
-  Initial supply minted to owner, then mint authority is permanently frozen
-  Business admin management (owner can update)
-  Reward tracking integration: notifies tracking contract on transfers

### IEO Contract
-  USDC-denominated token sales
-  Price oracle integration with timestamp and decimals
-  Configurable time windows via a single `delayDays_` constructor param (claim, refund, withdrawal)
-  Multi-investment per user with full history and indexing
-  Business admin withdrawals with per-investment withdrawal delays
-  Pausable while active (business admin)
-  Price validation bounds (min/max) and an oracle circuit breaker (staleness and deviation)

### Reward Tracking
-  High-precision reward accounting using accumulated reward per token (1e18 precision)
-  USDC reward pool topped up by owner deposits
-  Updates on token sales and transfers to maintain holder balances and reward debt
-  Users can claim accrued USDC rewards at any time

##  Architecture

```
FundraisingToken     RewardTracking      IEO Contract
                                       
  Whitelist           Reward Pool       Investment Pool
  (ERC20)            (USDC Rewards)      (USDC Sales)
```

##  Quick Start

### Installation
```bash
npm install
npx hardhat compile
```

### Testing
```bash
# Run all tests
npx hardhat test
```

### Deployment
```bash
# Deploy to local network
npx hardhat node
npx hardhat ignition deploy ignition/modules/FundraisingSystem.ts --network localhost
```

##  Contract Details

| Contract | Purpose | Key Features |
|----------|---------|--------------|
| **FundraisingToken** | ERC20 Token | Whitelist, Frozen Mint, Reward Integration, Business Admin |
| **IEO** | Token Sales | Oracle Pricing, Time Controls, Multi-Investment, Pause, Safeguards |
| **RewardTracking** | Reward Distribution | High Precision, Transfer Updates, USDC Claims, Owner Deposits |

##  Configuration

### IEO Parameters
- **Time Windows**: Set via constructor `delayDays_`; `CLAIM_DELAY`, `REFUND_PERIOD`, and `WITHDRAWAL_DELAY` are all `delayDays_ * 1 days`
- **Min/Max Investment**: Set via constructor (`MIN_INVESTMENT`, `MAX_INVESTMENT`)
- **USDC Address**: On-chain constant in contracts; update in code for your network

### Token Parameters
- **Name/Symbol/Decimals**: Provided via constructor
- **Initial Supply**: Minted to owner at deployment
- **Mint Authority**: Permanently frozen after initial mint
- **Business Admin**: Required in constructor and can be updated by owner

##  Security Features

- **Reentrancy Guards**: Storage-slot guards in token, IEO, and rewards
- **Pausable IEO**: Business admin can pause/unpause while IEO is active
- **Price Validation**: Optional min/max token price bounds
- **Oracle Circuit Breaker**: Staleness threshold, max deviation, enable/disable, and reset

##  Access Control and Roles

- **Owner**: Standard ownership (via `Ownable`) across contracts
- **Admin (IEO)**: Immutable `admin` address provided at deployment
- **Business Admin**:
  - IEO: Can pause/unpause, set price validation/circuit breaker, and withdraw USDC
  - Token: Manages whitelist and can be updated by owner

##  Oracle and Circuit Breaker

- **Oracle Interface**: `IPriceOracle.getPrice(address token) returns (price, decimals, timestamp)`
- **Safeguards**:
  - Price validation against optional `minTokenPrice`/`maxTokenPrice`
  - Circuit breaker checks price staleness and deviation vs. `lastValidPrice`
  - When triggered, investments revert until reset/conditions resolve

##  Constants and Addresses

- **USDC Address**: Hardcoded as `0x966c69ae5b4fB4744e976EB058cfe7592bD935d2` in `IEO` and `RewardTracking`
  - Update this in code for your deployment network

##  Public APIs (High Level)

- **IEO**
  - Actions: `invest`, `adminRecordInvestment`, `claimTokens`, `refundInvestment`, `refundInvestmentByIndex`
  - Admin/Biz Admin: `startIEO`, `endIEO`, `pauseIEO`, `unpauseIEO`, `setPriceOracle`, `setBusinessAdmin`
  - Biz Admin only: `setPriceValidation`, `setCircuitBreaker`, `resetCircuitBreaker`, `enableCircuitBreaker`, `disableCircuitBreaker`, `withdrawUSDC`, `withdrawAllUSDC`
  - Views: `getUserInvestments`, `getRefundableInvestments`, `getClaimableInvestments`, `getWithdrawableAmount`, `getInvestorCount`, `getInvestor`

- **RewardTracking**
  - Actions: `depositUSDC` (owner), `claimReward`
  - Views: `getPendingReward`, `getUserRewardTracking`, `getPoolInfo`

- **FundraisingToken**
  - Actions: whitelist management (`addToWhitelist`, `removeFromWhitelist`, batch variants), `setRewardTrackingAddress`, `setBusinessAdmin`
  - Transfers notify reward tracking when enabled

##  Deployment Strategy

1. **FundraisingToken**: Deploy first with zero reward tracking address
2. **IEO Contract**: Deploy with token address, set reward tracking later
3. **RewardTracking**: Deploy last with both token and IEO addresses
4. **Configuration**: Set cross-references and enable functionality

##  Workflow

1. **Setup**: Deploy contracts and configure addresses
2. **IEO Phase**: Users invest USDC to buy tokens
3. **Claim Phase**: Users claim tokens after delay
4. **Reward Phase**: USDC rewards distributed to token holders
5. **Withdrawal**: Business admin withdraws available USDC
