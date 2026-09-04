// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Grand Gangsta City Token
/// @notice A fixed-supply ERC-20 token deployed for BNB Smart Chain Testnet.
/// @dev The complete one-billion-token supply is minted exactly once to
///      `initialOwner` during construction. Ownership only exposes OpenZeppelin's
///      standard ownership-management functions; it grants no minting, freezing,
///      confiscation, taxation, pausing, or arbitrary balance-management power.
contract GrandGangstaCity is ERC20, Ownable {
    /// @notice The immutable supply created during construction, in token base units.
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @param initialOwner The owner of the contract and recipient of the entire fixed supply.
    constructor(address initialOwner) ERC20("Grand Gangsta City", "GGC") Ownable(initialOwner) {
        _mint(initialOwner, INITIAL_SUPPLY);
    }
}
