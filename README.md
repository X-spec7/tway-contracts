# FundraisingToken

A secure, whitelisted ERC20 token contract designed for fundraising purposes with a permanently frozen mint authority and centralized error handling.

##  Features

### Core Functionality
- **ERC20 Standard**: Full compliance with ERC20 token standard using OpenZeppelin contracts
- **Fixed Supply**: Permanently frozen mint authority after initial deployment
- **Whitelist System**: Only whitelisted addresses can interact with the token
- **Centralized Error Handling**: Custom errors for better gas efficiency and debugging
- **Owner Controls**: Owner can manage whitelist and transfer ownership

### Security Features
- **Dual Whitelist Check**: Both sender and recipient must be whitelisted for transfers
- **Frozen Mint Authority**: No additional tokens can be minted after deployment
- **Access Control**: Only owner can manage whitelist
- **Zero Address Protection**: Prevents whitelisting zero addresses

##  Contract Details

- **Name**: FundraisingToken
- **Symbol**: FRT
- **Decimals**: 18
- **Initial Supply**: 1,000,000 tokens
- **Mint Authority**: Permanently frozen after deployment

##  Project Structure

```
contracts/
 libraries/
    errors/
       FundraisingTokenErrors.sol    # Centralized error definitions
    Ownable.sol                       # Custom Ownable implementation
 dependencies/
    openzeppelin/                     # OpenZeppelin contracts
 FundraisingToken.sol                  # Main token contract
 FundraisingToken.t.sol                # Solidity tests

test/
 FundraisingToken.ts                   # TypeScript tests

ignition/modules/
 FundraisingToken.ts                   # Deployment module
```

##  Installation

1. Clone the repository
2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
npx hardhat compile
```

##  Testing

Run all tests:
```bash
npx hardhat test
```

Run specific test patterns:
```bash
# Run only TypeScript tests
npx hardhat test test/FundraisingToken.ts

# Run tests with specific pattern
npx hardhat test --grep "mint"

# Run with verbose output
npx hardhat test --verbose

# Run with gas reporting
npx hardhat test --gas-report
```

##  Deployment

Deploy using Hardhat Ignition:
```bash
npx hardhat ignition deploy ignition/modules/FundraisingToken.ts --network <network>
```

##  Usage

### Basic Token Operations

#### Transfer (Requires Both Addresses Whitelisted)
```solidity
// Both sender and recipient must be whitelisted
token.transfer(recipient, amount);
```

#### Approve (Requires Caller and Spender Whitelisted)
```solidity
// Both caller and spender must be whitelisted
token.approve(spender, amount);
```

#### TransferFrom (Requires All Addresses Whitelisted)
```solidity
// Sender, recipient, and caller must be whitelisted
token.transferFrom(from, to, amount);
```

### Whitelist Management (Owner Only)

#### Add to Whitelist
```solidity
token.addToWhitelist(address);
```

#### Remove from Whitelist
```solidity
token.removeFromWhitelist(address);
```

#### Batch Operations
```solidity
address[] memory accounts = [addr1, addr2, addr3];
token.batchAddToWhitelist(accounts);
token.batchRemoveFromWhitelist(accounts);
```

#### Check Whitelist Status
```solidity
bool isWhitelisted = token.isWhitelisted(address);
```

### Token Burning (Whitelisted Callers Only)

```solidity
// Caller must be whitelisted
token.burn(amount);
```

### View Functions

```solidity
// Check if mint authority is frozen (always true after deployment)
bool frozen = token.isMintAuthorityFrozen();

// Standard ERC20 view functions
uint256 totalSupply = token.totalSupply();
uint256 balance = token.balanceOf(address);
uint256 allowance = token.allowance(owner, spender);
```

##  Security Model

### Whitelist Requirements
- **Transfers**: Both sender and recipient must be whitelisted
- **Approvals**: Both caller and spender must be whitelisted
- **TransferFrom**: Sender, recipient, and caller must be whitelisted
- **Burning**: Caller must be whitelisted

### Access Control
- **Owner**: Can manage whitelist and transfer ownership
- **Whitelisted Users**: Can perform token operations
- **Non-whitelisted Users**: Cannot interact with token

### Fixed Supply
- **Initial Mint**: 1,000,000 tokens minted to deployer
- **Mint Authority**: Permanently frozen after deployment
- **Supply Changes**: Only through burning (reduces total supply)

##  Events

### Whitelist Events
```solidity
event AddressWhitelisted(address indexed account);
event AddressRemovedFromWhitelist(address indexed account);
```

### Mint Authority Event
```solidity
event MintAuthorityFrozen();
```

### Standard ERC20 Events
```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

##  Error Handling

The contract uses custom errors for gas efficiency:

### Whitelist Errors
- `CallerNotWhitelisted()` - Caller is not whitelisted
- `SenderNotWhitelisted()` - Sender is not whitelisted
- `RecipientNotWhitelisted()` - Recipient is not whitelisted
- `SpenderNotWhitelisted()` - Spender is not whitelisted
- `AddressAlreadyWhitelisted()` - Address already whitelisted
- `AddressNotWhitelisted()` - Address not whitelisted
- `CannotWhitelistZeroAddress()` - Cannot whitelist zero address
- `RecipientMustBeWhitelisted()` - Recipient must be whitelisted

### Mint Authority Errors
- `MintAuthorityFrozen()` - Mint authority is frozen

### Owner Errors
- `CallerNotOwner()` - Caller is not the owner
- `NewOwnerIsZeroAddress()` - New owner is zero address

##  Development

### Prerequisites
- Node.js 22.10.0+ (LTS recommended)
- npm or yarn

### Scripts
```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Run tests with coverage
npx hardhat coverage

# Deploy to local network
npx hardhat node
npx hardhat ignition deploy ignition/modules/FundraisingToken.ts --network localhost
```

##  License

MIT License - see LICENSE file for details.

##  Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

##  Support

For questions or issues, please open an issue on the GitHub repository.

---

**Note**: This token is designed for fundraising purposes with a fixed supply. The mint authority is permanently frozen after deployment, ensuring no additional tokens can be created.