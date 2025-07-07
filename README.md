# 🩸 Blockchain Blood Donation Registry

A Clarity smart contract for tracking and incentivizing blood donations with rewards and NFT badges on the Stacks blockchain.

## 🌟 Features

- 👥 **Donor Registration**: Register donors with blood type information
- 🏥 **Hospital Management**: Verified hospitals can record donations
- 🎁 **Reward System**: Earn rewards for verified donations
- 🏆 **NFT Badges**: Milestone-based achievement badges
- ✅ **Verification System**: Owner-verified donations and hospitals
- 📊 **Donation Tracking**: Complete donation history and statistics

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new blood-donation-registry
cd blood-donation-registry
```

Copy the contract code into `contracts/Blockchain-Blood-Donation-Registry.clar`

## 📋 Usage

### For Donors

1. **Register as Donor**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry register-donor "O+")
```

2. **Claim Rewards**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry claim-reward u1)
```

3. **Check Your Info**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry get-donor-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### For Hospitals

1. **Register Hospital**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry register-hospital "City General Hospital")
```

2. **Record Donation** (after verification)
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry record-donation 'ST1DONOR... "A+")
```

### For Contract Owner

1. **Verify Hospital**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry verify-hospital 'ST1HOSPITAL...)
```

2. **Verify Donation**
```clarity
(contract-call? .Blockchain-Blood-Donation-Registry verify-donation u1)
```

## 🏆 Badge System

Earn NFT badges based on donation milestones:

- 🥉 **First Donation** - 1 donation
- 🥈 **Regular Donor** - 5 donations  
- 🥇 **Committed Donor** - 10 donations
- 🦸 **Hero Donor** - 25 donations
- 🦸‍♂️ **Super Hero** - 50 donations
- 👑 **Legend** - 100 donations

## 🩸 Supported Blood Types

- A+, A-, B+, B-, AB+, AB-, O+, O-

## ⚙️ Configuration

- **Reward per donation**: 100 tokens (configurable)
- **Minimum donation interval**: 144 blocks (~24 hours)

## 🧪 Testing

```bash
clarinet test
```

## 📝 Contract Functions

### Public Functions
- `register-donor` - Register as blood donor
- `register-hospital` - Register hospital
- `verify-hospital` - Verify hospital (owner only)
- `record-donation` - Record new donation
- `verify-donation` - Verify donation (owner only)
- `claim-reward` - Claim donation rewards
- `transfer-badge` - Transfer NFT badge
- `set-reward-amount` - Update reward amount (owner only)

### Read-Only Functions
- `get-donor-info` - Get donor details
- `get-donation-info` - Get donation details
- `get-hospital-info` - Get hospital details
- `get-badge-info` - Get badge details
- `get-total-donations` - Get total donation count

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - see LICENSE file for details

---

Made with ❤️ for the blood donation community
```

**Git Commit Message:**
```
feat: implement blockchain blood donation registry with rewards and NFT badges
```

**GitHub Pull Request Title:**
```
🩸 Add Blockchain Blood Donation Registry Smart Contract
```

**GitHub Pull Request Description:**
```
## Summary
Added a comprehensive Clarity smart contract for tracking blood donations on the Stacks blockchain with integrated reward and NFT badge systems.

## Features Added
- ✅ Donor registration with blood type validation
- ✅ Hospital registration and verification system  
- ✅ Donation recording and verification workflow
- ✅ Token reward system for verified donations
- ✅ NFT badge minting for donation milestones
- ✅ Complete donation tracking and statistics
- ✅ Configurable reward amounts and donation intervals

## Technical Details
- 150+ lines of production-ready Clarity code
- Comprehensive error handling with custom error codes
- Support for all major blood types (A+, A-, B+
