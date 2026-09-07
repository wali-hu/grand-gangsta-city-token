// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {GrandGangstaCity} from "../src/GrandGangstaCity.sol";
import {GGCTokenomics} from "../src/GGCTokenomics.sol";
import {GGCVestingFactory} from "../src/GGCVestingFactory.sol";
import {GGCVestingWallet} from "../src/GGCVestingWallet.sol";

contract DeployGGCVestingTestnet is Script {
    uint256 internal constant BSC_TESTNET_CHAIN_ID = 97;

    error WrongChainId(uint256 actualChainId);
    error ZeroAddress();
    error TokenCodeMissing(address token);
    error TokenInvariantFailed();
    error FunderInvariantFailed(uint256 expectedBalance, uint256 actualBalance);
    error DeploymentInvariantFailed();

    function run()
        external
        returns (GGCVestingFactory factory, GGCVestingWallet[10] memory wallets, uint64 tgeTimestamp)
    {
        if (block.chainid != BSC_TESTNET_CHAIN_ID) revert WrongChainId(block.chainid);

        address tokenAddress = vm.envAddress("GGC_TOKEN_ADDRESS");
        address funder = vm.envAddress("VESTING_FUNDER");
        address beneficiary = vm.envAddress("VESTING_BENEFICIARY");
        if (tokenAddress == address(0) || funder == address(0) || beneficiary == address(0)) revert ZeroAddress();
        if (tokenAddress.code.length == 0) revert TokenCodeMissing(tokenAddress);

        GrandGangstaCity token = GrandGangstaCity(tokenAddress);
        if (
            keccak256(bytes(token.name())) != keccak256("Grand Gangsta City")
                || keccak256(bytes(token.symbol())) != keccak256("GGC") || token.decimals() != 18
                || token.totalSupply() != GGCTokenomics.TOTAL_SUPPLY || token.owner() != funder
        ) revert TokenInvariantFailed();

        uint256 funderBalance = token.balanceOf(funder);
        if (funderBalance != GGCTokenomics.TOTAL_SUPPLY) {
            revert FunderInvariantFailed(GGCTokenomics.TOTAL_SUPPLY, funderBalance);
        }

        address[10] memory beneficiaries;
        for (uint256 i; i < beneficiaries.length; ++i) {
            beneficiaries[i] = beneficiary;
        }

        tgeTimestamp = uint64(block.timestamp);
        uint256 initialBeneficiaryBalance = token.balanceOf(beneficiary);

        vm.startBroadcast(funder);
        factory = new GGCVestingFactory();
        token.approve(address(factory), GGCTokenomics.TOTAL_SUPPLY);
        wallets = factory.deployPlan(IERC20(tokenAddress), beneficiaries, beneficiary, tgeTimestamp);
        vm.stopBroadcast();

        _assertDeployment(token, factory, wallets, beneficiary, initialBeneficiaryBalance, funder == beneficiary);
        _logDeployment(factory, wallets, tgeTimestamp);
    }

    function _assertDeployment(
        GrandGangstaCity token,
        GGCVestingFactory factory,
        GGCVestingWallet[10] memory wallets,
        address beneficiary,
        uint256 initialBeneficiaryBalance,
        bool beneficiaryIsFunder
    ) internal view {
        GGCTokenomics.Schedule[10] memory schedules = GGCTokenomics.vestingSchedules();
        uint256 lockedBalance;

        for (uint256 i; i < schedules.length; ++i) {
            uint256 expectedTge = schedules[i].allocation * schedules[i].tgeBps / 10_000;
            if (
                wallets[i].owner() != beneficiary || wallets[i].categoryId() != schedules[i].categoryId
                    || wallets[i].tgeBps() != schedules[i].tgeBps
                    || wallets[i].cliffMonths() != schedules[i].cliffMonths
                    || wallets[i].vestingMonths() != schedules[i].vestingMonths
                    || token.balanceOf(address(wallets[i])) != schedules[i].allocation - expectedTge
                    || wallets[i].released(address(token)) != expectedTge
            ) revert DeploymentInvariantFailed();

            lockedBalance += token.balanceOf(address(wallets[i]));
        }

        uint256 expectedBeneficiaryBalance = beneficiaryIsFunder
            ? GGCTokenomics.TOTAL_TGE_ALLOCATION
            : initialBeneficiaryBalance + GGCTokenomics.TOTAL_TGE_ALLOCATION;

        if (
            lockedBalance != GGCTokenomics.POST_TGE_VESTING_BALANCE
                || token.balanceOf(beneficiary) != expectedBeneficiaryBalance || token.balanceOf(address(factory)) != 0
                || token.allowance(vm.envAddress("VESTING_FUNDER"), address(factory)) != 0
        ) revert DeploymentInvariantFailed();
    }

    function _logDeployment(GGCVestingFactory factory, GGCVestingWallet[10] memory wallets, uint64 tgeTimestamp)
        internal
        pure
    {
        GGCTokenomics.Schedule[10] memory schedules = GGCTokenomics.vestingSchedules();
        console2.log("GGC vesting factory:", address(factory));
        console2.log("TGE timestamp:", uint256(tgeTimestamp));

        for (uint256 i; i < wallets.length; ++i) {
            console2.logBytes32(schedules[i].categoryId);
            console2.logAddress(address(wallets[i]));
        }
    }
}
