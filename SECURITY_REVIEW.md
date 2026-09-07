# GGC Vesting Security Review Record

Date: 2026-09-07

## Library-first review

- The project was inspected before integration and the deployed fixed-supply token was left unchanged.
- OpenZeppelin Contracts v5.6 `VestingWallet` was selected as the closest existing component.
- The installed OpenZeppelin source and upstream finance tests were read before integration.
- Only the documented virtual `_vestingSchedule` extension point is overridden.
- OpenZeppelin `SafeERC20` and `Math.mulDiv` are imported rather than reimplemented.
- The OpenZeppelin Contracts CLI was checked. It has no Solidity vesting generator, so direct source-pattern
  integration was used.

## Automated checks

- Foundry unit, integration, fuzz, chain-guard, allocation, TGE, cliff, monthly-boundary, final-dust, and atomicity
  tests.
- Foundry formatting, compilation, lint, gas report, and coverage.
- Live BSC Testnet fork simulation against the deployed GGC contract.
- Aderyn static analysis with 88 detectors over all four `src` files.

## Aderyn triage

### “Contract locks Ether without a withdraw function” — false positive

`GGCVestingWallet` inherits both native-currency `release()` and ERC-20 `release(address)` from OpenZeppelin
`VestingWallet`. The scanner restricted reporting to local `src` files and did not recognize the inherited withdrawal
path. `testInheritedNativeReleasePreventsEtherLock` explicitly funds the wallet with native currency and proves that
the vested amount is released to the beneficiary.

### “Centralization Risk” on `GrandGangstaCity` — informational

The token inherits OpenZeppelin `Ownable`, but ownership has no mint, pause, blacklist, fee, confiscation, upgrade, or
arbitrary-balance capability. Existing tests prove that those privileged token-control entry points do not exist.

### Large literals / literal constants — stylistic

Human-readable whole-token literals are intentional because they make the approved tokenomics auditable against the
spreadsheet. The compiler resolves `ether` denomination literals exactly at build time.

### Revert inside factory loop — intentional safety property

The complete tokenomics deployment is intentionally atomic. A bad beneficiary, failed transfer, wrong received
balance, or any wallet deployment failure must revert the whole `deployPlan` transaction; partial allocation is not
acceptable.

## Residual considerations before mainnet

- This review is not an independent third-party audit.
- OpenZeppelin `VestingWallet` ownership is transferable. Transferring a wallet's ownership transfers the right to
  receive its unreleased tokens but does not change its schedule.
- Tokens sent to a vesting wallet later are treated as if present since the original TGE, per OpenZeppelin semantics.
- Production category beneficiaries and the final TGE timestamp must be separately approved and re-tested.
- Mainnet contract source must be explorer-verified, and all allocations must be independently reconciled on-chain.

## Post-deployment verification

The canonical BSC Testnet deployment at Git commit `b87048de736d21e0a41e0858c7011febc2c20cde` was independently
checked after broadcast:

- all three transaction receipts have status `1`;
- the deployed factory runtime bytecode hash exactly matches the local compiled hash;
- the factory and all ten vesting wallets have Sourcify `exact_match` verification;
- every wallet has the intended category, beneficiary, TGE basis points, cliff, duration, and non-empty runtime code;
- initial TGE releases total `83,650,000 GGC` and every wallet reports zero additionally releasable GGC;
- ten wallet balances total `766,350,000 GGC`;
- the beneficiary's liquid balance is `233,650,000 GGC`, including the `150,000,000 GGC` liquidity allocation;
- the factory balance and remaining ERC-20 allowance are both zero; and
- total supply remains exactly `1,000,000,000 GGC`.

Full transaction and wallet evidence is recorded in
[`deployments/bsc-testnet-vesting.json`](deployments/bsc-testnet-vesting.json).
