// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import { UsdtDepositManager } from "@src/UsdtDepositManager.sol";
import { JpytToken } from "@src/JpytToken.sol";
import { IPool } from "@src/interfaces/external/IPool.sol";
import { IAggregatorV3 } from "@src/interfaces/external/IAggregatorV3.sol";

import { PAUSER_ROLE, OPERATOR_ROLE, UPGRADER_ROLE, UNPAUSER_ROLE } from "@src/constants/RoleConstants.sol";

contract UsdtDepositManagerTest is Test {
    // Constants
    string private constant OPTIMISM_RPC_URL = "https://optimism-mainnet.public.blastapi.io";
    bytes32 private constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // Optimism mainnet contract addresses
    address private constant AAVE_POOL_ADDRESS = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address private constant DEPOSIT_TOKEN_ADDRESS = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
    address private constant USDT_USD_PRICE_FEED_ADDRESS = 0xECef79E109e997bCA29c1c0897ec9d7b03647F5E;
    address private constant JPY_USD_PRICE_FEED_ADDRESS = 0x536944c3A71FEb7c1E5C66Ee37d1a148d8D8f619;

    // Contracts
    UsdtDepositManager public depositManager;
    JpytToken public jpytToken;
    IERC20 public depositToken;
    IPool public aavePool;
    IAggregatorV3 public usdtPriceFeed;
    IAggregatorV3 public jpyPriceFeed;

    // Addresses
    address public constant DEFAULT_ADMIN = address(1);
    address public constant PAUSER = address(2);
    address public constant OPERATOR = address(3);
    address public user1;
    address public user2;

    // Private keys
    uint256 private user1Key;
    uint256 private user2Key;

    function setUp() public {
        _setupFork();
        _setupContracts();
        _setupUsers();
    }

    function _setupFork() private {
        vm.createSelectFork(OPTIMISM_RPC_URL);
    }

    function _setupContracts() private {
        depositToken = IERC20(DEPOSIT_TOKEN_ADDRESS);
        aavePool = IPool(AAVE_POOL_ADDRESS);
        usdtPriceFeed = IAggregatorV3(USDT_USD_PRICE_FEED_ADDRESS);
        jpyPriceFeed = IAggregatorV3(JPY_USD_PRICE_FEED_ADDRESS);

        jpytToken = new JpytToken(DEFAULT_ADMIN);

        depositManager = UsdtDepositManager(
            Upgrades.deployUUPSProxy(
                "UsdtDepositManager.sol",
                abi.encodeCall(
                    UsdtDepositManager.initialize,
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
    }

    function _setupUsers() private {
        user1Key = 0x12345;
        user1 = vm.addr(user1Key);
        user2Key = 0x67890;
        user2 = vm.addr(user2Key);

        deal(DEPOSIT_TOKEN_ADDRESS, user1, 1_000_000 * 1e6);
        deal(DEPOSIT_TOKEN_ADDRESS, user2, 1_000_000 * 1e6);
    }

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e6; // 1000 USDT
        _deposit(user1, depositAmount);

        assertGt(jpytToken.balanceOf(user1), 0, "No JPYT minted");
        assertEq(depositToken.balanceOf(address(depositManager)), 0, "USDT should be in Aave, not in DepositManager");
        assertEq(depositManager.totalDepositToken(), depositAmount, "Incorrect total deposit token");
        assertEq(depositManager.totalMintedJpy(), jpytToken.balanceOf(user1), "Incorrect total minted JPY");
    }

    function testRequestWithdrawal() public {
        testDeposit();
        uint256 jpyBalance = jpytToken.balanceOf(user1);
        uint256 withdrawAmount = jpyBalance / 2;

        _requestWithdrawal(user1, withdrawAmount);

        (uint256 jpyAmount, uint256 tokenAmount, uint256 requestBlock) = depositManager.withdrawalRequests(user1);
        assertEq(jpyAmount, withdrawAmount, "Incorrect JPY amount in withdrawal request");
        assertGt(tokenAmount, 0, "Token amount should be greater than 0");
        assertEq(requestBlock, block.number, "Incorrect request block");
    }

    function testExecuteWithdrawal() public {
        testRequestWithdrawal();
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

    function testGetDepositRate() public view {
        uint256 depositRate = depositManager.getDepositRate();
        assertGt(depositRate, 0, "Deposit rate should be greater than 0");
    }

    function testPauseAndUnpause() public {
        _pauseContract();
        _unpauseContract();
    }

    function testSetProtocolFeeBps() public {
        uint256 newFeeBps = 50; // 0.5%
        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(newFeeBps);
        assertEq(depositManager.protocolFeeBps(), newFeeBps, "Protocol fee should be updated");
    }

    function testDepositWithFee() public {
        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(100); // 1% fee

        uint256 depositAmount = 1000 * 1e6; // 1000 USDT
        _deposit(user1, depositAmount);

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

    function testRequestWithdrawalWithPermit() public {
        testDeposit();

        uint256 jpyBalance = jpytToken.balanceOf(user1);
        uint256 withdrawAmount = jpyBalance / 2;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = IERC20Permit(address(jpytToken)).nonces(user1);

        bytes32 permitDigest = _getERC20PermitTypeDataHash(
            IERC20Permit(address(jpytToken)), user1, address(depositManager), withdrawAmount, nonce, deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1Key, permitDigest);

        vm.prank(user1);
        depositManager.requestWithdrawalWithPermit(withdrawAmount, deadline, v, r, s);

        (uint256 jpyAmount, uint256 tokenAmount, uint256 requestBlock) = depositManager.withdrawalRequests(user1);
        assertEq(jpyAmount, withdrawAmount, "Incorrect JPY amount in withdrawal request");
        assertGt(tokenAmount, 0, "Token amount should be greater than 0");
        assertEq(requestBlock, block.number, "Incorrect request block");
    }

    function testDepositAndWithdrawAll() public {
        uint256 depositAmount = 3_128_799_412;
        deal(DEPOSIT_TOKEN_ADDRESS, user1, depositAmount);

        _deposit(user1, depositAmount);

        uint256 jpyBalance = jpytToken.balanceOf(user1);

        _requestWithdrawal(user1, jpyBalance);

        vm.roll(block.number + depositManager.cooldownBlocks() + 1);

        _executeWithdrawal(user1);

        assertLt(jpytToken.balanceOf(user1), jpyBalance, "JPYT balance should decrease");
        assertGt(depositToken.balanceOf(user1), 0, "User should receive USDT");
    }

    function testMultipleUsersDepositAndWithdraw() public {
        uint256 depositAmount1 = 1234 * 1e6; // 1234 USDT
        uint256 depositAmount2 = 5678 * 1e6; // 5678 USDT

        _deposit(user1, depositAmount1);
        _deposit(user2, depositAmount2);

        uint256 user1JpyBalance = jpytToken.balanceOf(user1);
        uint256 user2JpyBalance = jpytToken.balanceOf(user2);

        assertGt(user1JpyBalance, 0, "User 1 should have JPYT");
        assertGt(user2JpyBalance, 0, "User 2 should have JPYT");
        assertEq(depositManager.totalDepositToken(), depositAmount1 + depositAmount2, "Incorrect total deposit token");

        _requestWithdrawal(user1, user1JpyBalance / 2);
        _requestWithdrawal(user2, user2JpyBalance / 3);

        vm.roll(block.number + depositManager.cooldownBlocks() + 1);

        _executeWithdrawal(user1);
        _executeWithdrawal(user2);

        assertLt(jpytToken.balanceOf(user1), user1JpyBalance, "User 1 JPYT balance should decrease");
        assertLt(jpytToken.balanceOf(user2), user2JpyBalance, "User 2 JPYT balance should decrease");
        assertGt(depositToken.balanceOf(user1), 0, "User 1 should receive USDT");
        assertGt(depositToken.balanceOf(user2), 0, "User 2 should receive USDT");
    }

    function testMultipleUsersDepositAndWithdrawAll() public {
        uint256 depositAmount1 = 311 * 1e6; // 311 USDT
        uint256 depositAmount2 = 734 * 1e6; // 734 USDT

        _deposit(user1, depositAmount1);
        _deposit(user2, depositAmount2);

        uint256 user1JpyBalance = jpytToken.balanceOf(user1);
        uint256 user2JpyBalance = jpytToken.balanceOf(user2);

        assertGt(user1JpyBalance, 0, "User 1 should have JPYT");
        assertGt(user2JpyBalance, 0, "User 2 should have JPYT");
        assertEq(depositManager.totalDepositToken(), depositAmount1 + depositAmount2, "Incorrect total deposit token");

        _requestWithdrawal(user1, user1JpyBalance);
        _requestWithdrawal(user2, user2JpyBalance);

        vm.roll(block.number + depositManager.cooldownBlocks() + 1);

        _executeWithdrawal(user1);
        _executeWithdrawal(user2);
    }

    function testFuzz_Deposit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 100_000 * 1e6);
        deal(DEPOSIT_TOKEN_ADDRESS, user1, depositAmount);
        _deposit(user1, depositAmount);

        assertGt(jpytToken.balanceOf(user1), 0, "No JPYT minted");
        assertEq(depositToken.balanceOf(address(depositManager)), 0, "USDT should be in Aave, not in DepositManager");
        assertEq(depositManager.totalDepositToken(), depositAmount, "Incorrect total deposit token");
        assertGt(depositManager.totalMintedJpy(), 0, "No JPY minted");
    }

    function testFuzz_DepositAndWithdraw(uint256 depositAmount, uint256 withdrawalFraction) public {
        depositAmount = bound(depositAmount, 1e6, 100_000 * 1e6);
        withdrawalFraction = bound(withdrawalFraction, 1, 100);

        deal(DEPOSIT_TOKEN_ADDRESS, user1, depositAmount);

        _deposit(user1, depositAmount);        
        uint256 jpyBalance = jpytToken.balanceOf(user1);
        
        uint256 withdrawAmount = (jpyBalance * withdrawalFraction) / 100;
        _requestWithdrawal(user1, withdrawAmount);

        vm.roll(block.number + depositManager.cooldownBlocks() + 1);
        _executeWithdrawal(user1);

        assertLt(jpytToken.balanceOf(user1), jpyBalance, "JPYT balance should decrease");
        assertGt(depositToken.balanceOf(user1), 0, "User should receive USDT");
    }

    function testFuzz_SetProtocolFeeBps(uint256 newFeeBps) public {
        newFeeBps = bound(newFeeBps, 0, 100);

        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(newFeeBps);
        assertEq(depositManager.protocolFeeBps(), newFeeBps, "Protocol fee should be updated");
    }

    function testFuzz_DepositWithFee(uint256 depositAmount, uint256 feeBps) public {
        depositAmount = bound(depositAmount, 1e6, 100_000 * 1e6);
        feeBps = bound(feeBps, 0, 100);

        vm.prank(OPERATOR);
        depositManager.setProtocolFeeBps(feeBps);

        deal(DEPOSIT_TOKEN_ADDRESS, user1, depositAmount);

        _deposit(user1, depositAmount);

        uint256 expectedFee = (depositAmount * feeBps) / 10_000;
        uint256 expectedDepositAfterFee = depositAmount - expectedFee;

        assertGe(depositManager.totalFeeAmount(), expectedFee, "Incorrect fee amount collected");
        assertLe(depositManager.totalDepositToken(), expectedDepositAfterFee, "Incorrect total deposit token after fee");
    }

    // Helper functions
    function _deposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        depositToken.approve(address(depositManager), amount);
        depositManager.deposit(user, amount);
        vm.stopPrank();
    }

    function _requestWithdrawal(address user, uint256 amount) internal {
        vm.startPrank(user);
        jpytToken.approve(address(depositManager), amount);
        depositManager.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function _executeWithdrawal(address user) internal {
        vm.prank(user);
        depositManager.executeWithdrawal();
    }

    function _pauseContract() internal {
        vm.prank(PAUSER);
        depositManager.pause();
        assertTrue(depositManager.paused(), "Contract should be paused");

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(user1);
        depositManager.deposit(user1, 1000 * 1e6);
    }

    function _unpauseContract() internal {
        vm.prank(DEFAULT_ADMIN);
        depositManager.unpause();
        assertFalse(depositManager.paused(), "Contract should be unpaused");

        uint256 depositAmount = 1000 * 1e6;
        _deposit(user1, depositAmount);
        assertGt(jpytToken.balanceOf(user1), 0, "Deposit should succeed after unpausing");
    }

    function _getERC20PermitTypeDataHash(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    )
        private
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }
}
