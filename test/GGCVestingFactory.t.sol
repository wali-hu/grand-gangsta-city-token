// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";
import {GGCTokenomics} from "../src/GGCTokenomics.sol";
import {GGCVestingFactory} from "../src/GGCVestingFactory.sol";
import {GGCVestingWallet} from "../src/GGCVestingWallet.sol";

contract GGCVestingFactoryTest is Test {
    uint64 internal constant TGE = 1_900_000_000;

    GrandGangstaCity internal token;
    GGCVestingFactory internal factory;
    address internal beneficiary = makeAddr("beneficiary");

    function setUp() public {
        vm.warp(TGE);
        token = new GrandGangstaCity(address(this));
        factory = new GGCVestingFactory();
    }

    function testDeploysFundsAndReleasesCompletePlanAtomically() public {
        address[10] memory beneficiaries = _sameBeneficiaries(beneficiary);
        token.approve(address(factory), GGCTokenomics.TOTAL_SUPPLY);

        GGCVestingWallet[10] memory wallets = factory.deployPlan(IERC20(token), beneficiaries, beneficiary, TGE);

        GGCTokenomics.Schedule[10] memory schedules = GGCTokenomics.vestingSchedules();
        uint256 totalWalletBalances;
        uint256 totalReleased;
        uint256 totalAllocations = GGCTokenomics.LIQUIDITY_ALLOCATION;

        for (uint256 i; i < schedules.length; ++i) {
            uint256 expectedTge = schedules[i].allocation * schedules[i].tgeBps / 10_000;

            assertEq(wallets[i].owner(), beneficiary);
            assertEq(wallets[i].categoryId(), schedules[i].categoryId);
            assertEq(wallets[i].tgeBps(), schedules[i].tgeBps);
            assertEq(wallets[i].cliffMonths(), schedules[i].cliffMonths);
            assertEq(wallets[i].vestingMonths(), schedules[i].vestingMonths);
            assertEq(token.balanceOf(address(wallets[i])), schedules[i].allocation - expectedTge);
            assertEq(wallets[i].released(address(token)), expectedTge);

            totalWalletBalances += token.balanceOf(address(wallets[i]));
            totalReleased += expectedTge;
            totalAllocations += schedules[i].allocation;
        }

        assertEq(totalAllocations, GGCTokenomics.TOTAL_SUPPLY);
        assertEq(totalReleased, GGCTokenomics.VESTING_TGE_ALLOCATION);
        assertEq(totalWalletBalances, GGCTokenomics.POST_TGE_VESTING_BALANCE);
        assertEq(token.balanceOf(beneficiary), GGCTokenomics.TOTAL_TGE_ALLOCATION);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(factory)), 0);
        assertEq(token.allowance(address(this), address(factory)), 0);
    }

    function testEachCategoryFullyVestsAtItsConfiguredEnd() public {
        address[10] memory beneficiaries;
        for (uint256 i; i < beneficiaries.length; ++i) {
            beneficiaries[i] = makeAddr(string.concat("beneficiary", vm.toString(i)));
        }

        address liquidityBeneficiary = makeAddr("liquidity");
        token.approve(address(factory), GGCTokenomics.TOTAL_SUPPLY);
        GGCVestingWallet[10] memory wallets =
            factory.deployPlan(IERC20(token), beneficiaries, liquidityBeneficiary, TGE);
        GGCTokenomics.Schedule[10] memory schedules = GGCTokenomics.vestingSchedules();

        for (uint256 i; i < schedules.length; ++i) {
            uint64 endTimestamp =
                uint64(uint256(TGE) + (uint256(schedules[i].cliffMonths) + schedules[i].vestingMonths) * 30 days);
            assertEq(wallets[i].vestedAmount(address(token), endTimestamp), schedules[i].allocation);

            vm.warp(endTimestamp);
            wallets[i].release(address(token));
            assertEq(token.balanceOf(beneficiaries[i]), schedules[i].allocation);
            assertEq(token.balanceOf(address(wallets[i])), 0);
        }

        assertEq(token.balanceOf(liquidityBeneficiary), GGCTokenomics.LIQUIDITY_ALLOCATION);
    }

    function testRejectsStaleTgeBeforeMovingTokens() public {
        address[10] memory beneficiaries = _sameBeneficiaries(beneficiary);
        token.approve(address(factory), GGCTokenomics.TOTAL_SUPPLY);
        vm.warp(uint256(TGE) + 30 days);

        vm.expectRevert(abi.encodeWithSelector(GGCVestingFactory.StaleTgeTimestamp.selector, TGE, block.timestamp));
        factory.deployPlan(IERC20(token), beneficiaries, beneficiary, TGE);

        assertEq(token.balanceOf(address(this)), GGCTokenomics.TOTAL_SUPPLY);
        assertEq(token.balanceOf(address(factory)), 0);
    }

    function testRejectsZeroCategoryBeneficiary() public {
        address[10] memory beneficiaries = _sameBeneficiaries(beneficiary);
        beneficiaries[4] = address(0);
        token.approve(address(factory), GGCTokenomics.TOTAL_SUPPLY);

        vm.expectRevert(abi.encodeWithSelector(GGCVestingFactory.ZeroBeneficiary.selector, 4));
        factory.deployPlan(IERC20(token), beneficiaries, beneficiary, TGE);

        assertEq(token.balanceOf(address(this)), GGCTokenomics.TOTAL_SUPPLY);
    }

    function _sameBeneficiaries(address account) internal pure returns (address[10] memory beneficiaries) {
        for (uint256 i; i < beneficiaries.length; ++i) {
            beneficiaries[i] = account;
        }
    }
}
