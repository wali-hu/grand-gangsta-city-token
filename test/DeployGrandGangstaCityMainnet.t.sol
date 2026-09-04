// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DeployGrandGangstaCityMainnet} from "../script/DeployGrandGangstaCityMainnet.s.sol";
import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";

contract DeployGrandGangstaCityMainnetTest is Test {
    address internal owner = makeAddr("mainnetOwner");
    DeployGrandGangstaCityMainnet internal deployment;

    function setUp() public {
        deployment = new DeployGrandGangstaCityMainnet();
        vm.setEnv("MAINNET_INITIAL_OWNER", vm.toString(owner));
        vm.setEnv("MAINNET_DEPLOYMENT_CONFIRMATION", "DEPLOY_GGC_TO_BSC_MAINNET");
    }

    function testRejectsBscTestnet() public {
        vm.chainId(97);

        vm.expectRevert(abi.encodeWithSelector(DeployGrandGangstaCityMainnet.WrongChainId.selector, 97));
        deployment.run();
    }

    function testRejectsAnyUnexpectedChain() public {
        vm.chainId(1);

        vm.expectRevert(abi.encodeWithSelector(DeployGrandGangstaCityMainnet.WrongChainId.selector, 1));
        deployment.run();
    }

    function testRejectsZeroOwner() public {
        vm.chainId(56);
        vm.setEnv("MAINNET_INITIAL_OWNER", vm.toString(address(0)));

        vm.expectRevert(DeployGrandGangstaCityMainnet.ZeroInitialOwner.selector);
        deployment.run();
    }

    function testRejectsInvalidConfirmation() public {
        vm.chainId(56);
        vm.setEnv("MAINNET_DEPLOYMENT_CONFIRMATION", "NOT_CONFIRMED");

        vm.expectRevert(DeployGrandGangstaCityMainnet.InvalidMainnetConfirmation.selector);
        deployment.run();
    }

    function testDeploysWithExpectedStateOnChain56() public {
        vm.chainId(56);

        GrandGangstaCity token = deployment.run();

        assertEq(token.owner(), owner);
        assertEq(token.name(), "Grand Gangsta City");
        assertEq(token.symbol(), "GGC");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000_000 ether);
        assertEq(token.balanceOf(owner), token.totalSupply());
    }
}
