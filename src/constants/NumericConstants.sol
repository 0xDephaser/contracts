// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @dev Represents 100% in basis points
 * Used for percentage calculations throughout the contract
 * 10,000 basis points = 100%
 */
uint256 constant ONE_HUNDRED_PERCENT_IN_BP = 10_000;

/**
 * @dev Minimum number of blocks for the cooldown period
 * Sets a lower bound for the withdrawal cooldown to prevent instant withdrawals
 */
uint256 constant MIN_COOLDOWN_BLOCKS = 1; // 1 block

/**
 * @dev Maximum number of blocks for the cooldown period
 * Sets an upper bound for the withdrawal cooldown to ensure withdrawals are not excessively delayed
 */
uint256 constant MAX_COOLDOWN_BLOCKS = 100; // 100 blocks

/**
 * @dev Minimum protocol fee in basis points
 * Allows setting the protocol fee to 0% if desired
 */
uint256 constant MIN_PROTOCOL_FEE_BPS = 0; // 0%

/**
 * @dev Maximum protocol fee in basis points
 * Caps the protocol fee at 1% to protect users from excessive fees
 */
uint256 constant MAX_PROTOCOL_FEE_BPS = 100; // 1%

/**
 * @dev Number of decimal places for the exchange rate
 * Used to represent the exchange rate as a fixed-point number
 */
uint256 constant EXCHANGE_RATE_DECIMALS = 8;

/**
 * @dev Scaling factor for the exchange rate calculations
 * Equal to 10^EXCHANGE_RATE_DECIMALS
 */
uint256 constant EXCHANGE_RATE_SCALE = 10 ** EXCHANGE_RATE_DECIMALS;
