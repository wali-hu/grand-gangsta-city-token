# GGC Vesting — BSC Testnet Runbook

This runbook deploys the complete GGC tokenomics plan against the already deployed BSC Testnet token. It must not be
used on BSC Mainnet. The deployment script has an explicit chain-ID `97` guard.

## Approved testnet interpretation

- The spreadsheet's final allocation table is authoritative.
- Seed TGE is `10%` (`16,000,000 GGC`).
- Airdrop TGE is `10%` (`2,000,000 GGC`).
- Development cliff is `3` months.
- One vesting month is exactly `30 days` (`2,592,000` seconds).
- Unlocking is discrete at monthly boundaries, not continuous per-second vesting.
- A cliff of `N` months means no post-TGE tranche during months `1..N`; tranche one unlocks at month `N+1`.
- TGE is the vesting-plan deployment timestamp.
- The testnet demo assigns every category, including liquidity, to one test beneficiary. Mainnet beneficiary addresses
  must be approved separately before any mainnet vesting deployment is prepared.

## Canonical allocation

| Category | Allocation | TGE | Cliff | Monthly vesting | Fully vested |
| --- | ---: | ---: | ---: | ---: | ---: |
| Seed | 160,000,000 | 10% | 3 months | 12 months | Month 15 |
| Private | 50,000,000 | 15% | 3 months | 12 months | Month 15 |
| Public | 130,000,000 | 40% | 1 month | 4 months | Month 5 |
| Team | 100,000,000 | 0% | 6 months | 36 months | Month 42 |
| Advisors | 60,000,000 | 5% | 4 months | 24 months | Month 28 |
| Marketing | 100,000,000 | 3% | 3 months | 48 months | Month 51 |
| Airdrop | 20,000,000 | 10% | 0 months | 5 months | Month 5 |
| Reserve | 30,000,000 | 0% | 8 months | 64 months | Month 72 |
| Liquidity | 150,000,000 | 100% | None | None | TGE |
| Rewards | 150,000,000 | 0.1% | 0 months | 72 months | Month 72 |
| Development | 50,000,000 | 0% | 3 months | 36 months | Month 39 |

Strategic allocation is `0 GGC`, so no wallet is created for it.

At deployment:

- Total allocated: `1,000,000,000 GGC`
- Total TGE/liquid balance: `233,650,000 GGC`
- Remaining across ten vesting wallets: `766,350,000 GGC`
- Factory balance and allowance after completion: `0 GGC`

## Security model

- `GGCVestingWallet` extends OpenZeppelin Contracts v5.6 `VestingWallet`.
- OpenZeppelin `SafeERC20` performs every plan transfer.
- OpenZeppelin `Math.mulDiv` performs proportional vesting calculations.
- The factory has no owner, upgrade path, withdrawal function, or retained token custody.
- Creation, full-supply allocation, and initial TGE release happen atomically inside `deployPlan`; a failure reverts the
  complete plan transaction.
- A vesting wallet has no clawback or schedule-acceleration function. Its OpenZeppelin owner is the beneficiary and can
  transfer wallet ownership; the schedule itself does not change.
- Anyone can call `release(address)`, but released tokens can only go to the wallet's current beneficiary/owner.

Using audited OpenZeppelin primitives reduces implementation risk, but this custom schedule and integration have not
received an independent external audit. Passing tests is not a replacement for an audit before production use.

## 1. Local quality gates

```bash
forge fmt --check
forge build
forge test -vvv
forge test --gas-report
```

## 2. Load public testnet configuration

The local `.env` is ignored by Git. Never put a private key, mnemonic, or keystore password in `.env`.

```bash
set -a
source .env
set +a

cast chain-id --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$GGC_TOKEN_ADDRESS" 'totalSupply()(uint256)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$GGC_TOKEN_ADDRESS" 'balanceOf(address)(uint256)' "$VESTING_FUNDER" \
  --rpc-url "$BSC_TESTNET_RPC_URL"
```

Expected chain ID: `97`. Expected raw supply and pre-deployment funder balance:
`1000000000000000000000000000`.

## 3. Simulate without broadcasting

```bash
forge script script/DeployGGCVestingTestnet.s.sol:DeployGGCVestingTestnet \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --sender "$VESTING_FUNDER" \
  -vvvv
```

Simulation must show all invariants passing. It does not spend tBNB or alter chain state.

The final 2026-09-07 live-state simulation estimated `14,114,738` gas at `0.1 gwei`, or
`0.0014114738 tBNB`. Keep at least `0.003 tBNB` available for a safe testnet buffer and re-check the estimate if
network gas pricing changes.

## 4. Broadcast only after final review

```bash
forge script script/DeployGGCVestingTestnet.s.sol:DeployGGCVestingTestnet \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --account ggc-testnet-deployer \
  --sender "$VESTING_FUNDER" \
  --broadcast \
  --slow \
  -vvvv
```

Enter the encrypted-keystore password only in Foundry's local terminal prompt. The script sends three transactions:
factory deployment, exact-supply approval, then atomic plan deployment/funding.

## 5. Independent post-deployment checks

Copy the factory and ten wallet addresses printed by the script. For each vesting wallet:

```bash
cast call 0xVESTING_WALLET 'owner()(address)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call 0xVESTING_WALLET 'categoryId()(bytes32)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call 0xVESTING_WALLET 'start()(uint256)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call 0xVESTING_WALLET 'tgeBps()(uint16)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call 0xVESTING_WALLET 'cliffMonths()(uint16)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call 0xVESTING_WALLET 'vestingMonths()(uint16)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$GGC_TOKEN_ADDRESS" 'balanceOf(address)(uint256)' 0xVESTING_WALLET \
  --rpc-url "$BSC_TESTNET_RPC_URL"
```

At any later unlock boundary, anyone may trigger a release; GGC always goes to the wallet owner:

```bash
cast send 0xVESTING_WALLET 'release(address)' "$GGC_TOKEN_ADDRESS" \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --account ggc-testnet-deployer
```

The broadcast artifact is written under
`broadcast/DeployGGCVestingTestnet.s.sol/97/run-latest.json`. Review it before recording or sharing addresses.
