# Dephaser

Dephaser is a decentralized finance (DeFi) protocol that allows users to deposit USDT and mint a JPY-pegged stablecoin. It leverages Aave for yield generation and Chainlink oracles for price feeds.

## Key Features

1. **USDT Deposits**: Users can deposit USDT into the protocol.
2. **JPY Minting**: Upon deposit, users receive a JPY-pegged stablecoin.
3. **Yield Generation**: Deposited USDT is supplied to Aave to generate yield.
4. **Withdrawals**: Users can request withdrawals of their USDT by burning the JPY-pegged tokens.
5. **Price Oracles**: Utilizes Chainlink price feeds for accurate USDT/USD and JPY/USD conversion rates.
6. **Cooldown Period**: Implements a cooldown period between withdrawal requests and executions for security.
7. **Protocol Fees**: Ability to set and collect protocol fees on deposits.
8. **Yield Distribution**: Plans for distributing Aave-generated profits back to users.

## Audit

Dephaser has undergone a thorough security audit conducted by Solidproof. The audit report can be found in the following location:

[Solidproof Audit Report](https://github.com/solidproof/Projects/tree/main/2024/Dephaser)

The audit process involved a comprehensive review of the smart contract code, focusing on potential vulnerabilities, code quality, and adherence to best practices in blockchain development. We encourage all users and stakeholders to review the audit report for a detailed understanding of the security measures in place.

Key highlights from the audit:
- Identification and resolution of potential security issues
- Verification of contract functionality

By undergoing this audit, Dephaser demonstrates its commitment to security and transparency in the DeFi space. We will continue to prioritize the safety of user funds and the integrity of our protocol.

## Smart Contracts

- **DepositManager**: The main contract handling deposits, withdrawals, and interactions with Aave and Chainlink.
- **JpytToken**: The JPY-pegged stablecoin minted when users deposit USDT.

## How It Works

1. **Deposit**:
   - User deposits USDT.
   - Contract calculates the equivalent JPY amount using Chainlink price feeds.
   - JPY-pegged tokens are minted to the user.
   - USDT is supplied to Aave for yield generation.

2. **Withdrawal**:
   - User requests a withdrawal by specifying an amount of JPY-pegged tokens.
   - Contract burns the JPY-pegged tokens.
   - A cooldown period begins.
   - After the cooldown, user can execute the withdrawal to receive USDT.

3. **Yield and Fees**:
   - Yield generated from Aave is retained in the protocol.
   - Optional protocol fees can be applied on deposits.
   - Accumulated yield will be distributed back to users in future implementations.

## Flowcharts

To better illustrate the deposit and withdrawal processes, please refer to the following flowcharts:

![Deposit Flowchart](images/deposit.jpg)
*Figure 1: Deposit Process Flowchart*

![Withdrawal Flowchart](images/withdrawal.jpg)
*Figure 2: Withdrawal Process Flowchart*

These flowcharts provide a visual representation of the key steps involved in depositing USDT and withdrawing funds from the Dephaser protocol.


## Yield Distribution

While the current implementation retains yield generated from Aave within the protocol, future updates will introduce mechanisms to distribute this yield back to users. 

## Security Features

- Cooldown period for withdrawals
- Role-based access control for administrative functions
- Use of battle-tested protocols (Aave, Chainlink)
- Pausable functionality for emergency situations

## Deployment

The protocol is designed to be deployed on Optimism, leveraging its lower gas fees and faster transaction times.

## Testing

Comprehensive unit tests and fuzz tests are implemented to ensure the robustness and correctness of the protocol under various scenarios.

