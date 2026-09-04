// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";

/// @notice Mainnet-only deployment script intended for an independently authorized operator.
/// @dev Requires both BSC Mainnet chain ID 56 and an explicit environment confirmation.
contract DeployGrandGangstaCityMainnet is Script {
    uint256 internal constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 internal constant EXPECTED_SUPPLY = 1_000_000_000 ether;
    bytes32 internal constant EXPECTED_CONFIRMATION = keccak256("DEPLOY_GGC_TO_BSC_MAINNET");

    error WrongChainId(uint256 actualChainId);
    error ZeroInitialOwner();
    error InvalidMainnetConfirmation();
    error DeploymentInvariantFailed();

    function run() external returns (GrandGangstaCity token) {
        if (block.chainid != BSC_MAINNET_CHAIN_ID) revert WrongChainId(block.chainid);

        address initialOwner = vm.envAddress("MAINNET_INITIAL_OWNER");
        if (initialOwner == address(0)) revert ZeroInitialOwner();

        string memory confirmation = vm.envString("MAINNET_DEPLOYMENT_CONFIRMATION");
        if (keccak256(bytes(confirmation)) != EXPECTED_CONFIRMATION) revert InvalidMainnetConfirmation();

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
