// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { JpytToken } from "@src/JpytToken.sol";
import { UsdtDepositManager } from "@src/UsdtDepositManager.sol";
import { UPGRADER_ROLE, OPERATOR_ROLE } from "@src/constants/RoleConstants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20PermitMinimal } from "@src/interfaces/external/IERC20PermitMinimal.sol";

contract DeployUsdtDepositManager is Script {
    // Optimism mainnet addresses
    address private constant USDT_USD_PRICE_FEED = 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E; // chainlink usdt/usd
    address private constant JPY_USD_PRICE_FEED = 0x536944c3A71FEb7c1E5C66Ee37d1a148d8D8f619; // chainlink jpy/usd
    address private constant DEPOSIT_TOKEN = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; // USDT on Optimism
    address private constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // aave pool mainnet op

    address private constant DEFAULT_ADMIN = 0xFFE99E1864c30723a51ec4aEB465fd138f3b7ff0; // change this to your address
    address private constant PAUSER = 0xFFE99E1864c30723a51ec4aEB465fd138f3b7ff0; // change this to your address
    address private constant OPERATOR = 0xFFE99E1864c30723a51ec4aEB465fd138f3b7ff0; // change this to your address

    JpytToken public jpytToken;
    UsdtDepositManager public depositManager;

    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        deployJpytToken();
        deployUsdtDepositManager();
        setupRoles();

        vm.stopBroadcast();
    }

    function deployJpytToken() private {
        jpytToken = new JpytToken(DEFAULT_ADMIN);
        console2.log("JpytToken deployed at:", address(jpytToken));
    }

    function deployUsdtDepositManager() private {
        address managerAddress = Upgrades.deployUUPSProxy(
            "UsdtDepositManager.sol",
            abi.encodeCall(
                UsdtDepositManager.initialize,
                (
                    DEFAULT_ADMIN,
                    PAUSER,
                    OPERATOR,
                    AAVE_POOL,
                    DEPOSIT_TOKEN,
                    USDT_USD_PRICE_FEED,
                    address(jpytToken),
                    JPY_USD_PRICE_FEED,
                    10 // initialCooldownBlocks
                )
            )
        );

        depositManager = UsdtDepositManager(managerAddress);
        console2.log("UsdtDepositManager deployed at:", address(depositManager));
    }

    function setupRoles() private {
        jpytToken.grantRole(jpytToken.MINTER_ROLE(), address(depositManager));
        jpytToken.grantRole(jpytToken.BURNER_ROLE(), address(depositManager));
        depositManager.grantRole(UPGRADER_ROLE, DEFAULT_ADMIN);

        console2.log("Roles set up successfully");
    }
}
