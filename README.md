# Tway Fundraising System

A complete fundraising platform with ERC20 token, IEO (Initial Exchange Offering), and reward tracking system.

##  Overview

This project provides a comprehensive fundraising solution with:
- **FundraisingToken**: Whitelisted ERC20 token with frozen mint authority
- **IEO Contract**: Token sales with price oracle integration and time-based controls
- **Reward Tracking**: Automated reward distribution system for token holders

##  Key Features

### FundraisingToken
-  ERC20 compliant with whitelist system
-  Permanently frozen mint authority
-  Reward tracking integration

### IEO Contract
-  Token sales with USDC
-  Price oracle integration
-  Configurable claim/refund periods
-  Multi-investment support per user
-  Business admin withdrawal system

### Reward Tracking
-  High-precision reward calculations
-  Per-token reward distribution
-  Transfer-based reward updates
-  USDC reward claims

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

# Run specific contract tests
npx hardhat test contracts/FundraisingToken.t.sol
npx hardhat test contracts/IEO.t.sol
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
| **FundraisingToken** | ERC20 Token | Whitelist, Frozen Mint, Reward Integration |
| **IEO** | Token Sales | Oracle Pricing, Time Controls, Multi-Investment |
| **RewardTracking** | Reward Distribution | High Precision, Transfer Updates, USDC Claims |

##  Configuration

### IEO Parameters
- **Claim Delay**: 14 days (configurable)
- **Refund Period**: 14 days (configurable)
- **Withdrawal Delay**: 14 days (configurable)
- **Min Investment**: 100 USDC (configurable)
- **Max Investment**: 100,000 USDC (configurable)

### Token Parameters
- **Name**: FundraisingToken
- **Symbol**: FRT
- **Decimals**: 18
- **Initial Supply**: 1,000,000 tokens
- **Mint Authority**: Permanently frozen

##  Testing

The project includes comprehensive tests:
- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Cross-contract interactions
- **Security Tests**: Vulnerability detection
- **Gas Tests**: Performance optimization

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
