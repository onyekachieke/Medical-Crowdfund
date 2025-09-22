# Healthcare Crowdfunding Platform Smart Contract

A comprehensive Clarity smart contract for transparent medical crowdfunding on the Stacks blockchain, enabling patients to raise funds for medical treatments with automated fund allocation and comprehensive tracking.

## Overview

This smart contract provides a decentralized platform for healthcare crowdfunding where patients can create campaigns to raise funds for medical treatments. The platform includes verification mechanisms, transparent fund tracking, and automated refund systems to ensure trust and accountability.

## Features

- **Campaign Creation**: Patients can create detailed crowdfunding campaigns with titles, descriptions, funding goals, and time limits
- **Secure Contributions**: Contributors can donate STX tokens with transparent tracking
- **Medical Verification**: Administrative verification system for campaign legitimacy
- **Partial Withdrawals**: Campaign creators can withdraw funds in stages as treatments progress
- **Automatic Refunds**: Contributors can claim refunds for unsuccessful or rejected campaigns
- **Platform Statistics**: Comprehensive tracking of all platform activity
- **Fee Structure**: Transparent platform fee system (default 2.5%)

## Contract Constants

### Error Codes
- `ERR-UNAUTHORIZED-ACCESS (100)`: Access denied for restricted operations
- `ERR-CAMPAIGN-NOT-FOUND (101)`: Campaign does not exist
- `ERR-CAMPAIGN-ALREADY-EXISTS (102)`: Campaign ID already in use
- `ERR-INVALID-GOAL-AMOUNT (103)`: Goal amount outside valid range
- `ERR-INVALID-DURATION (104)`: Campaign duration outside valid range
- `ERR-CAMPAIGN-EXPIRED (105)`: Campaign has passed its end date
- `ERR-CAMPAIGN-NOT-ACTIVE (106)`: Campaign is not in active status
- `ERR-INSUFFICIENT-FUNDS (107)`: Not enough funds available
- `ERR-INVALID-AMOUNT (108)`: Invalid amount specified
- `ERR-WITHDRAWAL-NOT-ALLOWED (109)`: Withdrawal conditions not met
- `ERR-REFUND-NOT-AVAILABLE (110)`: Refund conditions not met
- `ERR-ALREADY-CONTRIBUTED (111)`: User has already contributed
- `ERR-NO-CONTRIBUTION-FOUND (112)`: No contribution record found
- `ERR-GOAL-ALREADY-REACHED (113)`: Campaign goal already achieved
- `ERR-INVALID-VERIFICATION-STATUS (114)`: Invalid verification status
- `ERR-INVALID-STRING-INPUT (115)`: Invalid string input provided

### Campaign Parameters
- **Minimum Goal**: 1 STX (1,000,000 microSTX)
- **Maximum Goal**: 1,000,000 STX (1,000,000,000,000 microSTX)
- **Minimum Duration**: 1 day (144 blocks)
- **Maximum Duration**: ~1000 days (144,000 blocks)

### Status Constants
- **Campaign Status**: Active (1), Completed (2), Expired (3), Cancelled (4)
- **Verification Status**: Pending (1), Approved (2), Rejected (3)

## Public Functions

### Campaign Management

#### `create-campaign`
Creates a new medical crowdfunding campaign.

**Parameters:**
- `title (string-ascii 100)`: Campaign title
- `description (string-ascii 500)`: Medical condition description
- `goal-amount (uint)`: Target funding amount in microSTX
- `duration (uint)`: Campaign duration in blocks

**Returns:** Campaign ID on success

#### `contribute-to-campaign`
Allows users to contribute STX tokens to a campaign.

**Parameters:**
- `campaign-id (uint)`: Target campaign identifier
- `amount (uint)`: Contribution amount in microSTX

**Returns:** New total raised amount on success

#### `withdraw-funds`
Enables campaign creators to withdraw raised funds.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier
- `amount (uint)`: Withdrawal amount in microSTX

**Returns:** Net amount received (after platform fee) on success

#### `request-refund`
Allows contributors to claim refunds for unsuccessful campaigns.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Refund amount on success

### Administrative Functions

#### `update-verification-status`
Updates the medical verification status of a campaign (contract owner only).

**Parameters:**
- `campaign-id (uint)`: Campaign identifier
- `new-status (uint)`: New verification status (1-3)

**Returns:** New status on success

#### `cancel-campaign`
Cancels an active campaign (contract owner or campaign creator only).

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Campaign ID on success

#### `update-platform-fee-rate`
Updates the platform fee rate (contract owner only).

**Parameters:**
- `new-rate (uint)`: New fee rate in basis points (max 1000 = 10%)

**Returns:** New fee rate on success

## Read-Only Functions

### Campaign Information

#### `get-campaign-info`
Retrieves complete information about a campaign.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Campaign data map or none

#### `is-campaign-active`
Checks if a campaign is currently active and accepting contributions.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Boolean indicating active status

#### `get-campaign-time-remaining`
Calculates remaining blocks until campaign expiration.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Remaining blocks or none

#### `get-campaign-progress`
Calculates campaign progress as a percentage (scaled by 100).

**Parameters:**
- `campaign-id (uint)`: Campaign identifier

**Returns:** Progress percentage (0-10000) or none

### User Information

#### `get-user-contribution`
Retrieves contribution details for a specific user and campaign.

**Parameters:**
- `campaign-id (uint)`: Campaign identifier
- `user (principal)`: User address

**Returns:** Contribution data or none

#### `get-user-campaigns`
Gets all campaigns created by a user.

**Parameters:**
- `user (principal)`: User address

**Returns:** List of campaign IDs or none

#### `get-user-stats`
Retrieves user's total contribution statistics.

**Parameters:**
- `user (principal)`: User address

**Returns:** User statistics or none

### Platform Information

#### `get-platform-stats`
Retrieves overall platform statistics.

**Returns:** Map containing:
- `total-campaigns`: Total number of campaigns created
- `total-funds-raised`: Total STX raised across all campaigns
- `platform-fee-rate`: Current platform fee rate
- `next-campaign-id`: Next available campaign ID

## Data Structures

### Campaign Record
```clarity
{
  creator: principal,           // Campaign creator address
  title: (string-ascii 100),   // Campaign title
  description: (string-ascii 500), // Medical description
  goal-amount: uint,           // Target amount in microSTX
  raised-amount: uint,         // Current raised amount
  start-block: uint,           // Starting block height
  end-block: uint,             // Ending block height
  status: uint,                // Campaign status (1-4)
  verification-status: uint,   // Medical verification (1-3)
  total-contributors: uint,    // Number of unique contributors
  withdrawal-count: uint       // Number of withdrawals made
}
```

### Contribution Record
```clarity
{
  amount: uint,                // Total contributed amount
  block-height: uint           // Block height of contribution
}
```

## Usage Examples

### Creating a Campaign
```clarity
(contract-call? .healthcare-crowdfunding create-campaign
  "Heart Surgery for John"
  "Funds needed for emergency cardiac surgery procedure"
  u50000000000  ;; 50,000 STX goal
  u14400        ;; 100 day duration
)
```

### Contributing to a Campaign
```clarity
(contract-call? .healthcare-crowdfunding contribute-to-campaign
  u1            ;; Campaign ID
  u1000000000   ;; 1,000 STX contribution
)
```

### Checking Campaign Status
```clarity
(contract-call? .healthcare-crowdfunding get-campaign-info u1)
(contract-call? .healthcare-crowdfunding is-campaign-active u1)
(contract-call? .healthcare-crowdfunding get-campaign-progress u1)
```

## Security Features

- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive parameter validation
- **State Checks**: Campaign status and timing validation
- **Overflow Protection**: Safe arithmetic operations
- **Refund Protection**: Automatic refund eligibility for failed campaigns

## Platform Economics

- **Default Platform Fee**: 2.5% (250 basis points)
- **Fee Application**: Only charged on successful withdrawals
- **Fee Recipient**: Contract owner address
- **Maximum Fee**: 10% (administratively limited)

## Deployment Requirements

- Stacks blockchain compatibility
- Clarity smart contract support
- Sufficient STX for contract deployment
- Administrative access for verification functions

## Testing Considerations

1. **Campaign Lifecycle**: Test creation, funding, and completion flows
2. **Edge Cases**: Boundary conditions for amounts and durations
3. **Security**: Unauthorized access attempts and input validation
4. **Refund Logic**: Various refund scenarios and conditions
5. **Administrative Functions**: Verification and cancellation processes

## Compliance Notes

This contract is designed for transparent healthcare crowdfunding and includes:
- Medical verification requirements
- Transparent fund tracking
- Refund mechanisms for contributor protection
- Administrative oversight capabilities