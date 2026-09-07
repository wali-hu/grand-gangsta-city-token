// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";
import {GGCVestingWallet} from "../src/GGCVestingWallet.sol";

contract GGCVestingWalletTest is Test {
    uint64 internal constant START = 1_900_000_000;
    uint64 internal constant MONTH = 30 days;
    uint256 internal constant ALLOCATION = 1_000 ether;

    GrandGangstaCity internal token;
    GGCVestingWallet internal wallet;
    address internal beneficiary = makeAddr("beneficiary");
    address internal caller = makeAddr("caller");

    function setUp() public {
        token = new GrandGangstaCity(address(this));
        wallet = new GGCVestingWallet(beneficiary, START, "SEED", 1_000, 3, 12);
        assertTrue(token.transfer(address(wallet), ALLOCATION));
    }

    function testConfiguration() public view {
        assertEq(wallet.owner(), beneficiary);
        assertEq(wallet.categoryId(), "SEED");
        assertEq(wallet.tgeBps(), 1_000);
        assertEq(wallet.cliffMonths(), 3);
        assertEq(wallet.vestingMonths(), 12);
        assertEq(wallet.start(), START);
        assertEq(wallet.duration(), 15 * MONTH);
        assertEq(wallet.end(), START + 15 * MONTH);
        assertEq(wallet.firstVestingTimestamp(), START + 4 * MONTH);
    }

    function testDiscreteSeedScheduleAtBoundaries() public view {
        assertEq(wallet.vestedAmount(address(token), START - 1), 0);
        assertEq(wallet.vestedAmount(address(token), START), 100 ether);
        assertEq(wallet.vestedAmount(address(token), START + 3 * MONTH), 100 ether);
        assertEq(wallet.vestedAmount(address(token), START + 4 * MONTH - 1), 100 ether);
        assertEq(wallet.vestedAmount(address(token), START + 4 * MONTH), 175 ether);
        assertEq(wallet.vestedAmount(address(token), START + 9 * MONTH), 550 ether);
        assertEq(wallet.vestedAmount(address(token), START + 15 * MONTH), ALLOCATION);
        assertEq(wallet.vestedAmount(address(token), START + 50 * MONTH), ALLOCATION);
    }

    function testAnyoneCanTriggerReleaseButOnlyBeneficiaryReceives() public {
        vm.warp(START);

        vm.prank(caller);
        wallet.release(address(token));

        assertEq(token.balanceOf(caller), 0);
        assertEq(token.balanceOf(beneficiary), 100 ether);
        assertEq(token.balanceOf(address(wallet)), 900 ether);
        assertEq(wallet.released(address(token)), 100 ether);
    }

    function testInheritedNativeReleasePreventsEtherLock() public {
        vm.deal(address(wallet), 1 ether);
        vm.warp(START);

        vm.prank(caller);
        wallet.release();

        assertEq(beneficiary.balance, 0.1 ether);
        assertEq(address(wallet).balance, 0.9 ether);
        assertEq(wallet.released(), 0.1 ether);
    }

    function testReleaseIsCumulativeAndFinalStepClearsRoundingDust() public {
        vm.warp(START);
        wallet.release(address(token));

        vm.warp(START + 4 * MONTH);
        wallet.release(address(token));
        assertEq(token.balanceOf(beneficiary), 175 ether);

        vm.warp(START + 15 * MONTH);
        wallet.release(address(token));
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(address(wallet)), 0);
        assertEq(wallet.releasable(address(token)), 0);
    }

    function testAirdropWithNoCliffUnlocksFirstTrancheAtMonthOne() public {
        GGCVestingWallet airdrop = new GGCVestingWallet(beneficiary, START, "AIRDROP", 1_000, 0, 5);
        assertTrue(token.transfer(address(airdrop), ALLOCATION));

        assertEq(airdrop.vestedAmount(address(token), START), 100 ether);
        assertEq(airdrop.vestedAmount(address(token), START + MONTH - 1), 100 ether);
        assertEq(airdrop.vestedAmount(address(token), START + MONTH), 280 ether);
        assertEq(airdrop.vestedAmount(address(token), START + 5 * MONTH), ALLOCATION);
    }

    function testZeroTgeStartsOnlyAfterCliff() public {
        GGCVestingWallet team = new GGCVestingWallet(beneficiary, START, "TEAM", 0, 6, 36);
        assertTrue(token.transfer(address(team), ALLOCATION));

        assertEq(team.vestedAmount(address(token), START + 6 * MONTH), 0);
        assertEq(team.vestedAmount(address(token), START + 7 * MONTH), ALLOCATION / 36);
        assertEq(team.vestedAmount(address(token), START + 42 * MONTH), ALLOCATION);
    }

    function testRejectsInvalidConfiguration() public {
        vm.expectRevert(GGCVestingWallet.EmptyCategoryId.selector);
        new GGCVestingWallet(beneficiary, START, bytes32(0), 0, 0, 1);

        vm.expectRevert(abi.encodeWithSelector(GGCVestingWallet.InvalidTgeBps.selector, 10_001));
        new GGCVestingWallet(beneficiary, START, "BAD_BPS", 10_001, 0, 1);

        vm.expectRevert(GGCVestingWallet.ZeroVestingMonths.selector);
        new GGCVestingWallet(beneficiary, START, "NO_VEST", 10_000, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new GGCVestingWallet(address(0), START, "NO_OWNER", 0, 0, 1);
    }

    function testFuzzVestedAmountNeverExceedsAllocation(uint64 timestamp) public view {
        assertLe(wallet.vestedAmount(address(token), timestamp), ALLOCATION);
    }
}
