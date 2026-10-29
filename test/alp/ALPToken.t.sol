// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Test } from "forge-std/Test.sol";

import { ALPToken } from "../../src/alp/ALPToken.sol";

contract ALPTokenTest is Test {
    address internal constant TREASURY = address(0x7EA5);
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    uint256 internal constant SUPPLY = 1_000_000_000 ether;

    ALPToken internal token;

    function setUp() public {
        token = new ALPToken("ALPHEA", "ALP", SUPPLY, TREASURY);
    }

    function testWholeSupplyIsMintedOnceToTheTreasury() public view {
        assertEq(token.name(), "ALPHEA");
        assertEq(token.symbol(), "ALP");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(TREASURY), SUPPLY);
    }

    function testConstructorEmitsOnlyTheGenesisTransfer() public {
        vm.recordLogs();
        ALPToken fresh = new ALPToken("ALPHEA", "ALP", SUPPLY, TREASURY);

        assertEq(vm.getRecordedLogs().length, 1);
        assertEq(fresh.balanceOf(TREASURY), SUPPLY);
    }

    function testConstructorRefusesZeroSupplyAndZeroTreasury() public {
        vm.expectRevert(ALPToken.InvalidSupply.selector);
        new ALPToken("ALPHEA", "ALP", 0, TREASURY);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        new ALPToken("ALPHEA", "ALP", SUPPLY, address(0));
    }

    /// @dev The token has no function beyond ERC-20 and no fallback, so every supply- or
    ///      control-changing entry point an auditor might look for is absent and reverts.
    function testNoPrivilegedOrSupplyChangingEntryPoints() public {
        bytes[8] memory calls = [
            abi.encodeWithSignature("mint(address,uint256)", TREASURY, 1),
            abi.encodeWithSignature("burn(uint256)", 1),
            abi.encodeWithSignature("burnFrom(address,uint256)", TREASURY, 1),
            abi.encodeWithSignature("owner()"),
            abi.encodeWithSignature("transferOwnership(address)", ALICE),
            abi.encodeWithSignature("pause()"),
            abi.encodeWithSignature("grantRole(bytes32,address)", bytes32(0), ALICE),
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", ALICE, "")
        ];

        vm.startPrank(TREASURY);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool ok,) = address(token).call(calls[i]);
            assertFalse(ok, "unexpected entry point");
        }
        vm.stopPrank();

        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(TREASURY), SUPPLY);
    }

    function testFreeTransfersFromDeployment() public {
        vm.prank(TREASURY);
        assertTrue(token.transfer(ALICE, 10 ether));

        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, 4 ether));

        assertEq(token.balanceOf(ALICE), 6 ether);
        assertEq(token.balanceOf(BOB), 4 ether);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzzTransfersAndAllowancesConserveSupply(
        uint256 toAlice,
        uint256 toBob,
        uint256 allowance,
        uint256 pulled
    ) public {
        toAlice = bound(toAlice, 0, SUPPLY);
        toBob = bound(toBob, 0, toAlice);
        allowance = bound(allowance, 0, SUPPLY);
        pulled = bound(pulled, 0, allowance);

        vm.prank(TREASURY);
        assertTrue(token.transfer(ALICE, toAlice));

        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, toBob));

        vm.prank(TREASURY);
        assertTrue(token.approve(BOB, allowance));
        uint256 treasuryBalance = token.balanceOf(TREASURY);
        if (pulled <= treasuryBalance) {
            vm.prank(BOB);
            assertTrue(token.transferFrom(TREASURY, BOB, pulled));
            assertEq(token.allowance(TREASURY, BOB), allowance - pulled);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IERC20Errors.ERC20InsufficientBalance.selector,
                    TREASURY,
                    treasuryBalance,
                    pulled
                )
            );
            vm.prank(BOB);
            token.transferFrom(TREASURY, BOB, pulled);
        }

        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(TREASURY) + token.balanceOf(ALICE) + token.balanceOf(BOB), SUPPLY);
    }

    function testTransferFromBeyondAllowanceReverts() public {
        vm.prank(TREASURY);
        token.approve(ALICE, 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, ALICE, 1 ether, 1 ether + 1
            )
        );
        vm.prank(ALICE);
        token.transferFrom(TREASURY, BOB, 1 ether + 1);
    }
}
