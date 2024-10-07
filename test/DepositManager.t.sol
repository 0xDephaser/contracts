// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {DepositManager} from "@src/DepositManager.sol";
import {JpytToken} from "@src/JpytToken.sol";
import {IPool} from "@src/interfaces/external/IPool.sol";
import {IAggregatorV3} from "@src/interfaces/external/IAggregatorV3.sol";

import { OPERATOR_ROLE, UPGRADER_ROLE} from "@src/constants/RoleConstants.sol";

contract DepositManagerTest is Test {
    DepositManager public depositManager;
    JpytToken public jpytToken;
    IERC20 public depositToken;
    IPool public aavePool;
    IAggregatorV3 public usdtPriceFeed;
    IAggregatorV3 public jpyPriceFeed;

    address public constant DEFAULT_ADMIN = address(1);
    address public constant PAUSER = address(2);
    address public constant OPERATOR = address(3);
    address public user1 = address(4);
    address public user2 = address(5);

    string public constant OPTIMISM_RPC_URL = "https://mainnet.optimism.io";

    // Optimism contract addresses
    address private constant AAVE_POOL_ADDRESS = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address private constant DEPOSIT_TOKEN_ADDRESS = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; // USDT on Optimism
    address private constant USDT_USD_PRICE_FEED_ADDRESS = 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E;
    address private constant JPY_USD_PRICE_FEED_ADDRESS = 0x536944c3A71FEb7c1E5C66Ee37d1a148d8D8f619;

    function setUp() public {
        // Fork Optimism
        vm.createSelectFork(OPTIMISM_RPC_URL);

        // Set up contracts
        depositToken = IERC20(DEPOSIT_TOKEN_ADDRESS);
        aavePool = IPool(AAVE_POOL_ADDRESS);
        usdtPriceFeed = IAggregatorV3(USDT_USD_PRICE_FEED_ADDRESS);
        jpyPriceFeed = IAggregatorV3(JPY_USD_PRICE_FEED_ADDRESS);

        // Deploy JpytToken
        jpytToken = new JpytToken(DEFAULT_ADMIN);

        // Deploy DepositManager
        depositManager = DepositManager(
            Upgrades.deployUUPSProxy(
                "DepositManager.sol",
                abi.encodeCall(
                    DepositManager.initialize,
                    (
                        DEFAULT_ADMIN,
                        PAUSER,
                        OPERATOR,
                        AAVE_POOL_ADDRESS,
                        DEPOSIT_TOKEN_ADDRESS,
                        USDT_USD_PRICE_FEED_ADDRESS,
                        address(jpytToken),
                        JPY_USD_PRICE_FEED_ADDRESS,
                        10 // initialCooldownBlocks
                    )
                )
            )
        );

        vm.startPrank(DEFAULT_ADMIN);
        jpytToken.grantRole(jpytToken.MINTER_ROLE(), address(depositManager));
        jpytToken.grantRole(jpytToken.BURNER_ROLE(), address(depositManager));
        vm.stopPrank();

        // Fund test users with USDT
        deal(DEPOSIT_TOKEN_ADDRESS, user1, 1_000_000 * 1e6);
        deal(DEPOSIT_TOKEN_ADDRESS, user2, 1_000_000 * 1e6);
    }

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e6; // 1000 USDT

        vm.startPrank(user1);
        depositToken.approve(address(depositManager), depositAmount);
        depositManager.deposit(user1, depositAmount);
        vm.stopPrank();

        assertGt(jpytToken.balanceOf(user1), 0, "No JPYT minted");
        assertEq(depositToken.balanceOf(address(depositManager)), 0, "USDT should be in Aave, not in DepositManager");
        assertEq(depositManager.totalDepositToken(), depositAmount, "Incorrect total deposit token");
        assertGt(depositManager.totalMintedJpy(), 0, "No JPY minted");
    }

    function testRequestWithdrawal() public {
        testDeposit();

        uint256 jpyBalance = jpytToken.balanceOf(user1);
        uint256 withdrawAmount = jpyBalance / 2;

        vm.startPrank(user1);
        jpytToken.approve(address(depositManager), withdrawAmount);
        depositManager.requestWithdrawal(withdrawAmount);
        vm.stopPrank();

        (uint256 jpyAmount, uint256 tokenAmount, uint256 requestBlock) = depositManager.withdrawalRequests(user1);
        assertEq(jpyAmount, withdrawAmount, "Incorrect JPY amount in withdrawal request");
        assertGt(tokenAmount, 0, "Token amount should be greater than 0");
        assertEq(requestBlock, block.number, "Incorrect request block");
    }

    function testExecuteWithdrawal() public {
        testRequestWithdrawal();

        // Fast forward time
        vm.roll(block.number + depositManager.cooldownBlocks() + 1);

        uint256 initialUSDTBalance = depositToken.balanceOf(user1);

        vm.prank(user1);
        depositManager.executeWithdrawal();

        assertGt(depositToken.balanceOf(user1), initialUSDTBalance, "USDT balance should increase after withdrawal");
        
        (uint256 jpyAmount, uint256 tokenAmount, uint256 requestBlock) = depositManager.withdrawalRequests(user1);
        assertEq(jpyAmount, 0, "Withdrawal request should be deleted");
        assertEq(tokenAmount, 0, "Withdrawal request should be deleted");
        assertEq(requestBlock, 0, "Withdrawal request should be deleted");
    }

    function testGetDepositRate() public {
        uint256 depositRate = depositManager.getDepositRate();
        assertGt(depositRate, 0, "Deposit rate should be greater than 0");
    }

    function testPauseAndUnpause() public {
        vm.prank(PAUSER);
        depositManager.pause();

        assertTrue(depositManager.paused(), "Contract should be paused");

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(user1);
        depositManager.deposit(user1, 1000 * 1e6);

        vm.prank(DEFAULT_ADMIN);
        depositManager.unpause();

        assertFalse(depositManager.paused(), "Contract should be unpaused");

        vm.startPrank(user1);
        depositToken.approve(address(depositManager), 1000 * 1e6);
        depositManager.deposit(user1, 1000 * 1e6);
        vm.stopPrank();

        assertGt(jpytToken.balanceOf(user1), 0, "Deposit should succeed after unpausing");
    }

    function testSetProtocolFeeBps() public {
        uint256 newFeeBps = 50; // 0.5%

        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(newFeeBps);

        assertEq(depositManager.protocolFeeBps(), newFeeBps, "Protocol fee should be updated");
    }

    function testDepositWithFee() public {
        // Set a protocol fee
        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(100); // 1% fee

        uint256 depositAmount = 1000 * 1e6; // 1000 USDT

        vm.startPrank(user1);
        depositToken.approve(address(depositManager), depositAmount);
        depositManager.deposit(user1, depositAmount);
        vm.stopPrank();

        assertEq(depositManager.totalFeeAmount(), 10 * 1e6, "Incorrect fee amount collected");
        assertEq(depositManager.totalDepositToken(), 990 * 1e6, "Incorrect total deposit token after fee");
    }

    function testWithdrawFeeAmount() public {
        testDepositWithFee();

        uint256 initialBalance = depositToken.balanceOf(OPERATOR);

        vm.prank(OPERATOR);
        depositManager.withdrawFeeAmount();

        assertEq(
            depositToken.balanceOf(OPERATOR),
            initialBalance + 10 * 1e6,
            "Operator should receive the correct fee amount"
        );
        assertEq(depositManager.totalFeeAmount(), 0, "Total fee amount should be reset to 0");
    }

    // Helper function to generate permit signatures
    function _getPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 nonce,
        address tokenAddress
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        IERC20Permit token = IERC20Permit(tokenAddress);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (v, r, s) = vm.sign(uint256(uint160(owner)), digest);
    }
}