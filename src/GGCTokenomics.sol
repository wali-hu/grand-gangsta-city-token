// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Canonical GGC allocation and vesting parameters approved for the testnet implementation.
library GGCTokenomics {
    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000 ether;
    uint256 internal constant LIQUIDITY_ALLOCATION = 150_000_000 ether;
    uint256 internal constant VESTING_ALLOCATION = 850_000_000 ether;
    uint256 internal constant TOTAL_TGE_ALLOCATION = 233_650_000 ether;
    uint256 internal constant VESTING_TGE_ALLOCATION = 83_650_000 ether;
    uint256 internal constant POST_TGE_VESTING_BALANCE = 766_350_000 ether;
    uint256 internal constant SCHEDULE_COUNT = 10;

    bytes32 internal constant SEED = "SEED";
    bytes32 internal constant PRIVATE = "PRIVATE";
    bytes32 internal constant PUBLIC = "PUBLIC";
    bytes32 internal constant TEAM = "TEAM";
    bytes32 internal constant ADVISORS = "ADVISORS";
    bytes32 internal constant MARKETING = "MARKETING";
    bytes32 internal constant AIRDROP = "AIRDROP";
    bytes32 internal constant RESERVE = "RESERVE";
    bytes32 internal constant REWARDS = "REWARDS";
    bytes32 internal constant DEVELOPMENT = "DEVELOPMENT";
    bytes32 internal constant LIQUIDITY = "LIQUIDITY";

    struct Schedule {
        bytes32 categoryId;
        uint256 allocation;
        uint16 tgeBps;
        uint16 cliffMonths;
        uint16 vestingMonths;
    }

    function vestingSchedules() internal pure returns (Schedule[10] memory schedules) {
        schedules[0] = Schedule(SEED, 160_000_000 ether, 1_000, 3, 12);
        schedules[1] = Schedule(PRIVATE, 50_000_000 ether, 1_500, 3, 12);
        schedules[2] = Schedule(PUBLIC, 130_000_000 ether, 4_000, 1, 4);
        schedules[3] = Schedule(TEAM, 100_000_000 ether, 0, 6, 36);
        schedules[4] = Schedule(ADVISORS, 60_000_000 ether, 500, 4, 24);
        schedules[5] = Schedule(MARKETING, 100_000_000 ether, 300, 3, 48);
        schedules[6] = Schedule(AIRDROP, 20_000_000 ether, 1_000, 0, 5);
        schedules[7] = Schedule(RESERVE, 30_000_000 ether, 0, 8, 64);
        schedules[8] = Schedule(REWARDS, 150_000_000 ether, 10, 0, 72);
        schedules[9] = Schedule(DEVELOPMENT, 50_000_000 ether, 0, 3, 36);
    }
}
