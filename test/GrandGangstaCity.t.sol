// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Test} from "forge-std/Test.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";

contract GrandGangstaCityTest is Test {
    uint256 internal constant SUPPLY = 1_000_000_000 ether;

    GrandGangstaCity internal token;
    address internal owner = makeAddr("owner");
    address internal recipient = makeAddr("recipient");
    address internal spender = makeAddr("spender");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        token = new GrandGangstaCity(owner);
    }

    function testMetadata() public view {
        assertEq(token.name(), "Grand Gangsta City");
        assertEq(token.symbol(), "GGC");
        assertEq(token.decimals(), 18);
    }

    function testOwnerAndInitialSupply() public view {
        assertEq(token.owner(), owner);
        assertEq(token.INITIAL_SUPPLY(), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(owner), SUPPLY);
    }

    function testDeployerReceivesNoTokensWhenDifferentFromOwner() public view {
        assertTrue(address(this) != owner);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferSucceedsAndSupplyDoesNotChange() public {
        uint256 amount = 1_234 ether;

        vm.prank(owner);
        assertTrue(token.transfer(recipient, amount));

        assertEq(token.balanceOf(owner), SUPPLY - amount);
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testTransferToZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(address(0), 1);
    }

    function testTransferAboveBalanceReverts() public {
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, recipient, 0, 1));
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(owner, 1);
    }

    function testTransferFromAfterApproval() public {
        uint256 amount = 500 ether;

        vm.prank(owner);
        assertTrue(token.approve(spender, amount));

        vm.prank(spender);
        assertTrue(token.transferFrom(owner, recipient, amount));

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.allowance(owner, spender), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testTransferFromAboveAllowanceReverts() public {
        uint256 allowanceAmount = 10 ether;

        vm.prank(owner);
        token.approve(spender, allowanceAmount);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowanceAmount, allowanceAmount + 1
            )
        );
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(owner, recipient, allowanceAmount + 1);
    }

    function testZeroInitialOwnerReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new GrandGangstaCity(address(0));
    }

    function testNonOwnerCannotTransferOwnership() public {
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        token.transferOwnership(attacker);
    }

    function testOwnerCanTransferOwnership() public {
        vm.prank(owner);
        token.transferOwnership(recipient);

        assertEq(token.owner(), recipient);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(owner), SUPPLY);
    }

    function testNoCallableMintFunction() public {
        (bool mintToSucceeded,) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", attacker, 1));
        (bool mintSucceeded,) = address(token).call(abi.encodeWithSignature("mint(uint256)", 1));

        assertFalse(mintToSucceeded);
        assertFalse(mintSucceeded);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testNoPrivilegedTokenControlFunctions() public {
        bytes[] memory forbiddenCalls = new bytes[](11);
        forbiddenCalls[0] = abi.encodeWithSignature("pause()");
        forbiddenCalls[1] = abi.encodeWithSignature("unpause()");
        forbiddenCalls[2] = abi.encodeWithSignature("blacklist(address)", attacker);
        forbiddenCalls[3] = abi.encodeWithSignature("setBlacklist(address,bool)", attacker, true);
        forbiddenCalls[4] = abi.encodeWithSignature("setTax(uint256)", 1);
        forbiddenCalls[5] = abi.encodeWithSignature("setFee(uint256)", 1);
        forbiddenCalls[6] = abi.encodeWithSignature("seize(address,uint256)", owner, 1);
        forbiddenCalls[7] = abi.encodeWithSignature("freeze(address)", owner);
        forbiddenCalls[8] = abi.encodeWithSignature("setBalance(address,uint256)", owner, 0);
        forbiddenCalls[9] = abi.encodeWithSignature("upgradeTo(address)", attacker);
        forbiddenCalls[10] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", attacker, bytes(""));

        for (uint256 i; i < forbiddenCalls.length; ++i) {
            vm.prank(owner);
            (bool succeeded,) = address(token).call(forbiddenCalls[i]);
            assertFalse(succeeded);
        }

        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(owner), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzzTransferConservesBalancesAndSupply(uint256 amount) public {
        amount = bound(amount, 0, SUPPLY);

        vm.prank(owner);
        assertTrue(token.transfer(recipient, amount));

        assertEq(token.balanceOf(owner) + token.balanceOf(recipient), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
