// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GGCTokenomics} from "./GGCTokenomics.sol";
import {GGCVestingWallet} from "./GGCVestingWallet.sol";

/// @notice Stateless factory that atomically creates and funds the complete GGC tokenomics plan.
/// @dev The factory has no owner, admin functions, token custody, or upgrade mechanism.
contract GGCVestingFactory {
    using SafeERC20 for IERC20;

    uint256 private constant MONTH = 30 days;

    event VestingWalletCreated(
        bytes32 indexed categoryId,
        address indexed vestingWallet,
        address indexed beneficiary,
        uint256 allocation,
        uint256 tgeAllocation,
        uint16 cliffMonths,
        uint16 vestingMonths
    );
    event ImmediateAllocation(bytes32 indexed categoryId, address indexed beneficiary, uint256 allocation);
    event VestingPlanDeployed(
        address indexed token, address indexed funder, uint64 indexed tgeTimestamp, uint256 totalAllocation
    );

    error ZeroToken();
    error ZeroBeneficiary(uint256 categoryIndex);
    error ZeroLiquidityBeneficiary();
    error StaleTgeTimestamp(uint64 tgeTimestamp, uint256 currentTimestamp);
    error UnexpectedTotalSupply(uint256 actualSupply);
    error UnexpectedWalletBalance(bytes32 categoryId, uint256 expected, uint256 actual);
    error FactoryRetainedTokens(uint256 balance);

    function deployPlan(
        IERC20 token,
        address[10] calldata beneficiaries,
        address liquidityBeneficiary,
        uint64 tgeTimestamp
    ) external returns (GGCVestingWallet[10] memory wallets) {
        if (address(token) == address(0)) revert ZeroToken();
        if (liquidityBeneficiary == address(0)) revert ZeroLiquidityBeneficiary();
        if (uint256(tgeTimestamp) + MONTH <= block.timestamp) {
            revert StaleTgeTimestamp(tgeTimestamp, block.timestamp);
        }

        uint256 supply = token.totalSupply();
        if (supply != GGCTokenomics.TOTAL_SUPPLY) revert UnexpectedTotalSupply(supply);

        GGCTokenomics.Schedule[10] memory schedules = GGCTokenomics.vestingSchedules();

        for (uint256 i; i < schedules.length; ++i) {
            if (beneficiaries[i] == address(0)) revert ZeroBeneficiary(i);

            GGCTokenomics.Schedule memory schedule = schedules[i];
            GGCVestingWallet wallet = new GGCVestingWallet(
                beneficiaries[i],
                tgeTimestamp,
                schedule.categoryId,
                schedule.tgeBps,
                schedule.cliffMonths,
                schedule.vestingMonths
            );
            wallets[i] = wallet;

            token.safeTransferFrom(msg.sender, address(wallet), schedule.allocation);

            uint256 tgeAllocation = Math.mulDiv(schedule.allocation, schedule.tgeBps, 10_000);
            if (tgeAllocation != 0 && tgeTimestamp <= block.timestamp) {
                wallet.release(address(token));
            }

            uint256 expectedWalletBalance = schedule.allocation - tgeAllocation;
            if (tgeTimestamp > block.timestamp) expectedWalletBalance = schedule.allocation;

            uint256 actualWalletBalance = token.balanceOf(address(wallet));
            if (actualWalletBalance != expectedWalletBalance) {
                revert UnexpectedWalletBalance(schedule.categoryId, expectedWalletBalance, actualWalletBalance);
            }

            emit VestingWalletCreated(
                schedule.categoryId,
                address(wallet),
                beneficiaries[i],
                schedule.allocation,
                tgeTimestamp <= block.timestamp ? tgeAllocation : 0,
                schedule.cliffMonths,
                schedule.vestingMonths
            );
        }

        token.safeTransferFrom(msg.sender, liquidityBeneficiary, GGCTokenomics.LIQUIDITY_ALLOCATION);

        uint256 retainedBalance = token.balanceOf(address(this));
        if (retainedBalance != 0) revert FactoryRetainedTokens(retainedBalance);

        emit ImmediateAllocation(GGCTokenomics.LIQUIDITY, liquidityBeneficiary, GGCTokenomics.LIQUIDITY_ALLOCATION);
        emit VestingPlanDeployed(address(token), msg.sender, tgeTimestamp, GGCTokenomics.TOTAL_SUPPLY);
    }
}
