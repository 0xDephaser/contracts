// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.27;

import { IAggregatorV3 } from "@src/interfaces/external/IAggregatorV3.sol";

/**
 * @title IDepositManager
 * @notice Interface for managing deposits, withdrawals, and related operations
 * @dev This interface interacts with Aave's IPool for supplying and withdrawing assets
 */
interface IDepositManager {
    /**
     * @notice Struct to store price feed information
     * @param priceFeed The price feed contract for USD conversion
     * @param decimals The number of decimals used in the price feed
     */
    struct PriceFeedInfo {
        IAggregatorV3 priceFeed;
        uint8 decimals;
    }

    /**
     * @notice Struct to store withdrawal request information
     * @param jpyAmount The amount of JPY tokens requested for withdrawal
     * @param tokenAmount The equivalent amount of deposit tokens to be withdrawn
     * @param requestBlock The block number when the withdrawal request was made
     */
    struct WithdrawalRequest {
        uint256 jpyAmount;
        uint256 tokenAmount;
        uint256 requestBlock;
    }

    /**
     * @notice Thrown when the token address provided is zero
     */
    error ZeroTokenAddress();

    /**
     * @notice Thrown when the price feed address provided is zero
     */
    error ZeroPriceFeedAddress();

    /**
     * @notice Thrown when the price feed has invalid decimals
     * @param decimals The invalid decimals value
     */
    error InvalidPriceFeedDecimals(uint8 decimals);

    /* 
     * @notice Thrown when a withdrawal request is already pending
     */
    error WithdrawalRequestPending();

    /* 
     * @notice Thrown when the cooldown period for withdrawal has not been met
     */
    error CooldownPeriodNotMet();

    /* 
     * @notice Thrown when trying to execute a withdrawal without an existing request
     */
    error NoWithdrawalRequest();

    /* 
     * @notice Thrown when the withdrawn amount is less than requested
     * @param requested The requested amount
     * @param withdrawn The actually withdrawn amount
     */
    error InsufficientWithdrawn(uint256 requested, uint256 withdrawn);

    /* 
     * @notice Thrown when the new cooldown blocks are out of the allowed range
     * @param newCooldownBlocks The proposed new cooldown blocks
     * @param minBlocks The minimum allowed cooldown blocks
     * @param maxBlocks The maximum allowed cooldown blocks
     */
    error CooldownBlocksOutOfRange(uint256 newCooldownBlocks, uint256 minBlocks, uint256 maxBlocks);

    /* 
     * @notice Thrown when the new protocol fee is out of the allowed range
     * @param newFeeBps The proposed new fee in basis points
     * @param minFeeBps The minimum allowed fee in basis points
     * @param maxFeeBps The maximum allowed fee in basis points
     */
    error ProtocolFeeOutOfRange(uint256 newFeeBps, uint256 minFeeBps, uint256 maxFeeBps);

    /* 
     * @notice Thrown when a price feed is not set for a token
     * @param token The address of the token without a price feed
     */
    error PriceFeedNotSet(address token);

    /* 
     * @notice Thrown when an invalid price is received from the price feed
     * @param token The address of the token with an invalid price
     */
    error InvalidPrice(address token);

    /* 
     * @notice Emitted when the cooldown blocks are updated
     * @param newCooldownBlocks The new cooldown blocks value
     */
    event CooldownBlocksUpdated(uint256 newCooldownBlocks);

    /* 
     * @notice Emitted when fees are collected
     * @param amount The amount of fees collected
     */
    event FeesCollected(uint256 amount);

    /* 
     * @notice Emitted when the protocol fee is updated
     * @param newFeeBps The new protocol fee in basis points
     */
    event ProtocolFeeUpdated(uint256 newFeeBps);

    /* 
     * @notice Emitted when a price feed is updated
     * @param token The address of the token
     * @param priceFeed The address of the new price feed
     * @param decimals The number of decimals for the price feed
     */
    event PriceFeedUpdated(address indexed token, address indexed priceFeed, uint8 decimals);

    /* 
     * @notice Emitted when a deposit is made
     * @param user The address of the user making the deposit
     * @param depositTokenAmount The amount of deposit tokens
     * @param jpyAmount The equivalent amount in JPY which is minted to the user
     */
    event Deposited(address indexed user, uint256 depositTokenAmount, uint256 jpyAmount);

    /* 
     * @notice Emitted when a withdrawal is requested
     * @param user The address of the user requesting the withdrawal
     * @param jpyAmount The amount of JPY requested for withdrawal
     * @param tokenAmount The equivalent amount in deposit tokens
     */
    event WithdrawalRequested(address indexed user, uint256 jpyAmount, uint256 tokenAmount);

    /* 
     * @notice Emitted when a withdrawal is executed
     * @param user The address of the user executing the withdrawal
     * @param tokenAmount The amount of tokens withdrawn
     */
    event WithdrawalExecuted(address indexed user, uint256 tokenAmount);

    /* 
     * @notice Emitted when fees are withdrawn
     * @param to The address receiving the withdrawn fees
     * @param amount The amount of fees withdrawn
     */
    event FeeWithdrawn(address indexed to, uint256 amount);

    /* 
     * @notice Emitted when Aave profit is withdrawn
     * @param amount The amount of profit withdrawn
     */
    event AaveProfitWithdrawn(uint256 amount);

    /**
     * @notice Deposit tokens into the contract
     * @param to The address to receive the minted JPY tokens
     * @param depositAmount The amount of deposit tokens to deposit
     * @dev This function will:
     *      1. Transfer deposit tokens from the sender to this contract
     *      2. Supply the tokens to Aave
     *      3. Mint equivalent JPY tokens to the recipient
     *      e.g., If depositing 100 USDC and 1 USDC = 100 JPY, it will mint 10,000 JPY tokens
     */
    function deposit(address to, uint256 depositAmount) external;

    /**
     * @notice Deposit tokens into the contract using permit
     * @param to The address to receive the minted JPY tokens
     * @param depositAmount The amount of deposit tokens to deposit
     * @param deadline The deadline for the permit
     * @param v The v value of the permit signature
     * @param r The r value of the permit signature
     * @param s The s value of the permit signature
     * @dev This function works like `deposit` but uses EIP-2612 permit for approval
     */
    function depositWithPermit(
        address to,
        uint256 depositAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external;

    /**
     * @notice Request a withdrawal of JPY tokens
     * @param jpyAmount The amount of JPY tokens to withdraw
     * @dev This function will:
     *      1. Burn the JPY tokens from the sender
     *      2. Create a withdrawal request
     *      3. Withdraw tokens from Aave to this contract
     *      e.g., If requesting withdrawal of 10,000 JPY and 1 USDC = 100 JPY, it will prepare 100 USDC for withdrawal
     */
    function requestWithdrawal(uint256 jpyAmount) external;

    /**
     * @notice Request a withdrawal of JPY tokens using permit
     * @param jpyAmount The amount of JPY tokens to withdraw
     * @param deadline The deadline for the permit
     * @param v The v value of the permit signature
     * @param r The r value of the permit signature
     * @param s The s value of the permit signature
     * @dev This function works like `requestWithdrawal` but uses EIP-2612 permit for approval
     */
    function requestWithdrawalWithPermit(uint256 jpyAmount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @notice Execute a previously requested withdrawal
     * @dev This function will:
     *      1. Check if the cooldown period has passed
     *      2. Transfer the prepared deposit tokens to the user
     *      3. Delete the withdrawal request
     *      e.g., If a withdrawal of 100 USDC was requested and the cooldown has passed, it will transfer 100 USDC to
     * the user
     */
    function executeWithdrawal() external;

    /**
     * @notice Set or update the price feed for a specific token
     * @dev This function allows the authorized role to set or update
     *      the Chainlink price feed for a given token. This price feed is used to calculate
     *      exchange rates and token values in USD.
     *
     * @param token The address of the token for which to set the price feed
     * @param priceFeedAddress The address of the Chainlink price feed contract
     *
     * @notice Important considerations:
     * - Only callable by authorized roles
     * - The price feed should return the token price in USD
     * - Updating a price feed may affect all subsequent calculations and operations involving that token
     * - Emits a PriceFeedUpdated event upon successful update
     *
     * @notice Security considerations:
     * - Ensure the priceFeedAddress is a valid and trusted Chainlink price feed
     * - Incorrect price feeds can lead to severe miscalculations and potential loss of funds
     * - Consider implementing a time lock or multi-sig requirement for this critical operation
     */
    function setPriceFeed(address token, address priceFeedAddress) external;

    /**
     * @notice Set the cooldown period for withdrawals
     * @dev This function allows the authorized role to set the cooldown period
     *      that users must wait between requesting a withdrawal and executing it.
     *
     * @param newCooldownBlocks The new cooldown period in number of blocks
     *
     * @notice Important considerations:
     * - Only callable by authorized roles
     * - The new cooldown period must be within the allowed range (MIN_COOLDOWN_BLOCKS to MAX_COOLDOWN_BLOCKS)
     * - Changing the cooldown period affects all subsequent withdrawal requests
     * - Emits a CooldownBlocksUpdated event upon successful update
     *
     * @notice Security considerations:
     * - A longer cooldown period provides more security but may inconvenience users
     * - A shorter cooldown period might increase the risk of certain types of attacks
     * - Consider the impact on user experience and contract security when changing this value
     */
    function setCooldownBlocks(uint256 newCooldownBlocks) external;

    /**
     * @notice Set the protocol fee rate
     * @dev This function allows the authorized role to set the protocol fee rate.
     *      The fee is applied to deposits and is a source of revenue for the protocol.
     *
     * @param newFeeBps The new protocol fee rate in basis points (1 bp = 0.01%)
     *
     * @notice Important considerations:
     * - Only callable by authorized roles
     * - The new fee rate must be within the allowed range (MIN_PROTOCOL_FEE_BPS to MAX_PROTOCOL_FEE_BPS)
     * - Changing the fee rate affects all subsequent deposits
     * - Emits a ProtocolFeeUpdated event upon successful update
     *
     * @notice Security considerations:
     * - Consider implementing a time lock or gradual fee change mechanism for large adjustments
     */
    function setProtocolFeeBps(uint256 newFeeBps) external;

    /**
     * @notice Withdraw accumulated protocol fees to a specified address
     * @dev This function allows authorized role to withdraw
     *      the accumulated protocol fees. These fees are collected from user deposits
     *      and are stored separately from the main deposit pool.
     *
     * @notice Important considerations:
     * - Only callable by authorized roles
     * - The fees are in the deposit token (e.g., USDT)
     * - This action will reset the accumulated fee amount to zero
     * - Emits a FeeWithdrawn event upon successful withdrawal
     *
     * @notice Security considerations:
     * - This function should have appropriate access controls
     */
    function withdrawFeeAmount() external;

    /**
     * @notice Withdraw and realize the profit generated from Aave deposits
     * @dev This function calculates the current Aave profit (difference between
     *      aToken balance and total deposited amount), withdraws it from Aave,
     *      and transfers it to the caller.
     *
     * @notice Profit calculation:
     * 1. Calculate profit: aToken balance - total deposited amount
     * 2. Withdraw this profit amount from Aave
     * 3. Update the contract's accounting of total deposits
     *
     * @notice Important considerations:
     * - Only callable by authorized roles
     * - The profit is in the form of the deposit token (e.g., USDT)
     * - This action realizes the profit, making it available for further operations
     * - Emits an AaveProfitWithdrawn event upon successful withdrawal
     *
     * @notice Security considerations:
     * - This function interacts with external protocols (Aave), ensure proper integration
     * - Appropriate access controls should be in place
     */
    function withdrawAaveProfit() external;
}
