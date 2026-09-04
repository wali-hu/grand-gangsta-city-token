// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";

contract DeployGrandGangstaCity is Script {
    uint256 internal constant BSC_TESTNET_CHAIN_ID = 97;
    uint256 internal constant EXPECTED_SUPPLY = 1_000_000_000 ether;

    error WrongChainId(uint256 actualChainId);
    error ZeroInitialOwner();
    error DeploymentInvariantFailed();

    function run() external returns (GrandGangstaCity token) {
        if (block.chainid != BSC_TESTNET_CHAIN_ID) revert WrongChainId(block.chainid);

        address initialOwner = vm.envAddress("INITIAL_OWNER");
        if (initialOwner == address(0)) revert ZeroInitialOwner();

        vm.startBroadcast();
        token = new GrandGangstaCity(initialOwner);
        vm.stopBroadcast();

        if (
            token.owner() != initialOwner || keccak256(bytes(token.name())) != keccak256("Grand Gangsta City")
                || keccak256(bytes(token.symbol())) != keccak256("GGC") || token.decimals() != 18
                || token.totalSupply() != EXPECTED_SUPPLY || token.balanceOf(initialOwner) != EXPECTED_SUPPLY
        ) revert DeploymentInvariantFailed();
    }
}
