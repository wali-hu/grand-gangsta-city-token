// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DeployGGCVestingTestnet} from "../script/DeployGGCVestingTestnet.s.sol";
import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";
import {GGCTokenomics} from "../src/GGCTokenomics.sol";
import {GGCVestingFactory} from "../src/GGCVestingFactory.sol";
import {GGCVestingWallet} from "../src/GGCVestingWallet.sol";

contract DeployGGCVestingTestnetTest is Test {
    address internal funder = makeAddr("funder");
    DeployGGCVestingTestnet internal deployment;
    GrandGangstaCity internal token;

    function setUp() public {
        vm.chainId(97);
        token = new GrandGangstaCity(funder);
        deployment = new DeployGGCVestingTestnet();
        vm.setEnv("GGC_TOKEN_ADDRESS", vm.toString(address(token)));
        vm.setEnv("VESTING_FUNDER", vm.toString(funder));
        vm.setEnv("VESTING_BENEFICIARY", vm.toString(funder));
    }

    function testRejectsWrongChain() public {
        vm.chainId(56);
        vm.expectRevert(abi.encodeWithSelector(DeployGGCVestingTestnet.WrongChainId.selector, 56));
        deployment.run();
    }

    function testRejectsFunderWithoutEntireSupply() public {
        vm.prank(funder);
        assertTrue(token.transfer(makeAddr("recipient"), 1));

        vm.expectRevert(
            abi.encodeWithSelector(
                DeployGGCVestingTestnet.FunderInvariantFailed.selector,
                GGCTokenomics.TOTAL_SUPPLY,
                GGCTokenomics.TOTAL_SUPPLY - 1
            )
        );
        deployment.run();
    }

    function testDeploysExpectedTestnetDemoPlan() public {
        (GGCVestingFactory factory, GGCVestingWallet[10] memory wallets, uint64 tgeTimestamp) = deployment.run();

        assertTrue(address(factory) != address(0));
        assertEq(tgeTimestamp, block.timestamp);
        assertEq(token.balanceOf(funder), GGCTokenomics.TOTAL_TGE_ALLOCATION);

        uint256 totalLocked;
        for (uint256 i; i < wallets.length; ++i) {
            totalLocked += token.balanceOf(address(wallets[i]));
        }
        assertEq(totalLocked, GGCTokenomics.POST_TGE_VESTING_BALANCE);
    }
}
