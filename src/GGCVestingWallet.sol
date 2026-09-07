// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Irrevocable, discrete-month vesting for one GGC tokenomics category.
/// @dev Release rights follow OpenZeppelin VestingWallet ownership. There is no admin withdrawal or acceleration path.
contract GGCVestingWallet is VestingWallet {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint64 public constant MONTH = 30 days;

    bytes32 public immutable categoryId;
    uint16 public immutable tgeBps;
    uint16 public immutable cliffMonths;
    uint16 public immutable vestingMonths;

    error EmptyCategoryId();
    error InvalidTgeBps(uint16 tgeBps);
    error ZeroVestingMonths();

    constructor(
        address beneficiary,
        uint64 tgeTimestamp,
        bytes32 categoryId_,
        uint16 tgeBps_,
        uint16 cliffMonths_,
        uint16 vestingMonths_
    )
        VestingWallet(
            beneficiary, tgeTimestamp, uint64((uint256(cliffMonths_) + uint256(vestingMonths_)) * uint256(MONTH))
        )
    {
        if (categoryId_ == bytes32(0)) revert EmptyCategoryId();
        if (tgeBps_ > BPS_DENOMINATOR) revert InvalidTgeBps(tgeBps_);
        if (vestingMonths_ == 0) revert ZeroVestingMonths();

        categoryId = categoryId_;
        tgeBps = tgeBps_;
        cliffMonths = cliffMonths_;
        vestingMonths = vestingMonths_;
    }

    /// @notice First timestamp at which one post-TGE monthly tranche is vested.
    function firstVestingTimestamp() external view returns (uint256) {
        return start() + (uint256(cliffMonths) + 1) * uint256(MONTH);
    }

    /// @notice Number of post-TGE monthly tranches vested at a timestamp.
    function vestedMonths(uint64 timestamp) public view returns (uint256) {
        if (timestamp < start()) return 0;

        uint256 elapsedMonths = (uint256(timestamp) - start()) / uint256(MONTH);
        if (elapsedMonths <= cliffMonths) return 0;

        return Math.min(elapsedMonths - cliffMonths, vestingMonths);
    }

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (timestamp < start()) return 0;

        uint256 tgeAllocation = Math.mulDiv(totalAllocation, tgeBps, BPS_DENOMINATOR);
        uint256 monthsVested = vestedMonths(timestamp);

        if (monthsVested == 0) return tgeAllocation;
        if (monthsVested == vestingMonths) return totalAllocation;

        uint256 postTgeAllocation = totalAllocation - tgeAllocation;
        return tgeAllocation + Math.mulDiv(postTgeAllocation, monthsVested, vestingMonths);
    }
}
