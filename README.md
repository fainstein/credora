# Credora Protocol

[![Foundry][foundry-badge]][foundry]
[![License: MIT][license-badge]][license]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

A decentralized lending protocol where lenders deposit ETH (converted to wstETH) to earn yield through CRD tokens, and borrowers access credit via salary-verified loans. Features ERC1155 promissory notes, Symbiotic shared security integration, and a unique design where lenders benefit from protocol growth and borrower defaults.

**MVP Note**: This is a hackathon project focused on core deposit and lending functionality. Withdrawals and redemptions are marked as TODO for future implementation.

## Architecture Overview

### Core Components

```
src/interfaces/
├── IPool.sol               # Main liquidity pool for ETH deposits (converted to wstETH)
├── ICRDVault.sol           # Vault managing CRD token supply
├── INoteIssuer.sol         # ERC1155 factory for promissory notes
├── INote.sol               # ERC1155 note contract with CRD backing
├── ICredoraShares.sol      # CRD token representing pool ownership
├── ICRD.sol                # CRD token interface
└── IVerifier.sol           # External proof verification
```

### Key Design Principles

- **ETH to wstETH Conversion**: Users deposit ETH, converted to wstETH for shared security
- **CRD Token System**: ERC20 tokens representing shares in the wstETH lending pool
- **Symbiotic Integration**: wstETH deposited to Symbiotic vaults for network security rewards
- **ERC1155 Notes**: Semi-fungible tokens representing loan obligations
- **Proof-Based Lending**: Cryptographic verification for borrower eligibility
- **Vault Architecture**: Separated token management for security

## Protocol Flows

### Deposit & Yield Flow

1. **Lender Deposits**: User deposits ETH → converted to wstETH → receives CRD tokens (backed 1:1 initially)
2. **Security Provision**: Pool deploys wstETH to Symbiotic vault, delegated to operators providing network security
3. **Reward Collection**: Networks pay security rewards to Symbiotic vault
4. **Share Appreciation**: CRD tokens appreciate as wstETH rewards accumulate
5. **No Withdrawals**: Users hold CRD tokens indefinitely (withdrawals TODO for future)

### Lending Flow

1. **Borrower Verification**: Provides cryptographic proof of income/eligibility
2. **Loan Creation**: Issues ERC1155 note with CRD backing representing loan amount
3. **Advance Payment**: Borrower deposits wstETH advance payment (20% of loan value)
4. **Loan Lifecycle**: Note tracks repayment status and matures over time
5. **Repayment**: Borrower repays principal + interest → wstETH funds added to pool
6. **CRD Appreciation**: Lenders benefit through automatic CRD token appreciation

### Default Flow

1. **Default Declaration**: Unpaid loans after maturity
2. **CRD Burn**: Loan-backed CRD tokens burned (no longer redeemable) - TODO for future
3. **Advance Liquidation**: Borrower's wstETH advance payment added to Symbiotic vault as yield
4. **CRD Appreciation**: Remaining CRD holders benefit from increased share value

## Key Mechanics

### CRD Token Economics

```solidity
// CRD tokens represent ownership in the wstETH lending pool
// Price calculated in real-time: CRD_price = totalWstETH_in_Symbiotic_vault / totalCRD_supply
// When network rewards accrue: CRD_price increases automatically
// When defaults occur: CRD_price increases from advance payment liquidation
// Always backed by: Current Symbiotic vault balance + advance payments from defaults
// Note: Withdrawals not implemented in MVP (marked as TODO)
```

### Yield Sources & Price Updates

1. **Network Security Rewards**: Networks pay for security provided by Symbiotic operators
2. **Advance Payments**: Borrower advance payments → deposited to Symbiotic vault → price increases
3. **Repayment Premiums**: Interest payments above principal → added to Symbiotic vault → price increases
4. **Default Liquidation**: wstETH advance payments from defaults → added to Symbiotic vault → price increases
5. **Real-time Price**: CRD price reflects current Symbiotic vault balance automatically
6. **MVP Limitation**: No withdrawal/redemption functionality (marked as TODO)

### Note System (ERC1155)

- **Semi-Fungible**: Different note IDs for different loans
- **CRD Backing**: Each note holds CRD tokens representing loan value
- **Transferable**: Notes can be traded on secondary markets
- **Lifecycle**: Active → Repaid/Defaulted → Redeemed

### Verification System

- **Cryptographic Proofs**: ZK proofs, signatures, oracles
- **External Verifiers**: Third-party contracts handle validation
- **Dynamic Amounts**: Proof determines maximum borrowable amount
- **Conservative Ratios**: 20% advance payment requirement

## Installation & Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/)
- [Yarn](https://yarnpkg.com/)

### Installation

```bash
git clone <repository-url>
cd credora
yarn install
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test                   # Run all tests
forge test --match-contract PoolTest     # Run Pool tests
forge test --match-contract NoteIssuerTest # Run NoteIssuer tests
```

## API Reference

### IPool

```solidity
// Core lending pool functions
function deposit() payable returns (uint256 crdShares);
function receivePayment(address from, address token, uint256 amount);
// TODO: function redeemNote(uint256 noteId, address redeemer) returns (uint256 wstETHAmount);

// Balance checking
function getWstETHBalance() returns (uint256 wstETHBalance);
```

### INoteIssuer

```solidity
// Loan creation and management
function createNote(uint256 amount, uint256 advancePayment, bytes calldata proof, address creditor) returns (uint256 noteId);
function repay(uint256 noteId, uint256 amount) returns (uint256 actualPayment, uint256 remainingDebt);
// TODO: function redeemNote(uint256 noteId, address redeemer) returns (uint256 wstETHAmount);

// Note information
function getNoteCRDBalance(uint256 noteId) returns (uint256);
function getNoteRemainingDebt(uint256 noteId) returns (uint256);
function getNote(uint256 noteId) returns (Note memory);

// Utility functions
function calculateRequiredCollateral(uint256 loanAmount) returns (uint256);
function transferNote(uint256 noteId, address newOwner);
```

### INote (ERC1155)

```solidity
// Token management
function mintNote(address to, uint256 noteId, uint256 amount, address borrower, uint256 principal, uint256 rate, uint256 maturity, string calldata ipfsHash);
function burnNote(address from, uint256 noteId, uint256 amount);

// CRD management
function depositCRD(uint256 noteId, uint256 amount);
function withdrawCRD(uint256 noteId, uint256 amount);

// Metadata and information
function getNoteMetadata(uint256 noteId) returns (NoteMetadata memory);
function getNoteCRDBalance(uint256 noteId) returns (uint256);
function getNoteBorrower(uint256 noteId) returns (address);
function isNoteMature(uint256 noteId) returns (bool);
```

### ICredoraShares

```solidity
// CRD token functions
function mint(address to, uint256 amount);
function burn(address from, uint256 amount);
function totalSupply() returns (uint256);
function balanceOf(address account) returns (uint256);

// Share calculations
function sharePrice() returns (uint256);
function calculatePrice(uint256 totalWstETHBalance, uint256 totalCRDSupply) returns (uint256);
function calculateSharesForDeposit(uint256 wstETHAmount) returns (uint256);
// TODO: function calculateWstETHForShares(uint256 shares) returns (uint256);

// Yield management
// TODO: function addYield(uint256 yieldAmount);
```

### IVerifier

```solidity
// Proof verification
function verifyProof(address user, bytes calldata proof) returns (bool isValid, uint256 maxLoan);
function verifyProofDetailed(address user, bytes calldata proof) returns (bool, uint256, uint256, uint256);

// Configuration
function getDefaultMaxLoanAmount() returns (uint256);
function getVerificationRequirements() returns (uint256, uint256, string[] memory);
```

## Security Considerations

### Access Control
- **Role-Based Permissions**: Pool, NoteIssuer, and Vault have separate access controls
- **Authorized Operations**: Critical functions require specific roles
- **Emergency Controls**: Pausable functionality for security incidents

### Economic Security
- **CRD Token Backing**: All CRD tokens are backed by USDC in the pool
- **Yield Isolation**: External yield farming doesn't affect core protocol
- **Conservative Ratios**: 20% collateral requirement for all loans

### Smart Contract Security
- **Input Validation**: Comprehensive parameter validation on all functions
- **SafeERC20**: Protected ERC20 operations throughout the protocol
- **Reentrancy Guards**: All external functions protected against reentrancy
- **Overflow Protection**: SafeMath operations for all calculations

## Development Roadmap

### Phase 1 (Current)
- ✅ Interface design and specification
- ✅ Core protocol architecture
- ✅ USDC-only focus
- ✅ ERC1155 note system

### Phase 2 (Next)
- 🔄 Contract implementations
- 🔄 Yield farming integration
- 🔄 Multi-collateral support
- 🔄 Comprehensive testing

### Phase 3 (Future)
- 📋 Real verifier integration
- 📋 Governance system
- 📋 Cross-chain expansion
- 📋 Advanced liquidation mechanisms

## Contributing

This is a hackathon project focused on clean architecture and innovative lending mechanics. The interface-first approach ensures clear separation of concerns and easy implementation.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
