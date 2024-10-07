// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @title Chainlink AggregatorV3 Interface
/// @notice Interface for fetching the latest round data from a Chainlink price feed
interface IAggregatorV3 {
    /// @notice Get the latest round data from the price feed
    /// @return roundId The round ID
    /// @return answer The price answer for the round
    /// @return startedAt Timestamp when the round started
    /// @return updatedAt Timestamp when the round was last updated
    /// @return answeredInRound (Deprecated) - Previously used when answers could take multiple rounds to be computed
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /// @notice Get the number of decimals for the price feed
    /// @return decimals The number of decimals
    function decimals() external view returns (uint8);
}
