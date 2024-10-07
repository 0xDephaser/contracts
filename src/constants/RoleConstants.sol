// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @dev value is equal to keccak256("PAUSER_ROLE")
bytes32 constant PAUSER_ROLE = 0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;

/// @dev value is equal to keccak256("UNPAUSER_ROLE")
bytes32 constant UNPAUSER_ROLE = 0x427da25fe773164f88948d3e215c94b6554e2ed5e5f203a821c9f2f6131cf75a;

/// @dev value is equal to keccak256("OPERATOR_ROLE")
bytes32 constant OPERATOR_ROLE = 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;

/// @dev value is equal to keccak256("UPGRADER_ROLE")
bytes32 constant UPGRADER_ROLE = 0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;
