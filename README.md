# Grand Gangsta City Token

`GrandGangstaCity` is a fixed-supply ERC-20 token for BNB Smart Chain Testnet. ERC-20 contracts use the
same EVM token interface on BSC, so the deployment is BEP-20 compatible.

## Token configuration

| Property | Value |
| --- | --- |
| Contract | `GrandGangstaCity` |
| Name | `Grand Gangsta City` |
| Symbol | `GGC` |
| Decimals | `18` |
| Total supply | `1,000,000,000 GGC` |
| Raw supply | `1000000000000000000000000000` |
| Owner/initial recipient | Supplied through `INITIAL_OWNER` |
| OpenZeppelin Contracts | `v5.6.1` |
| Solidity | `0.8.24` |
| Optimizer | Enabled, 200 runs |

The entire supply is minted once in the constructor directly to `initialOwner`. There is no external or
privileged mint, burn, pause, blacklist, tax, fee, freeze, confiscation, upgrade, or arbitrary balance function.
Ownership only provides OpenZeppelin's standard `owner`, `transferOwnership`, and `renounceOwnership` behavior.

## BSC Testnet deployment

| Property | Value |
| --- | --- |
| Chain ID | `97` |
| Contract address | `0x229d9a0ADEfea5A4f21477C1D83288D04b6D1a06` |
| Transaction | `0x93c0eadbfe28a32d6f2d4c4f544fd87a8ea7678b9af14f2b64dd5e3bb46a088d` |
| Block | `129119129` |
| Deployer/owner/recipient | `0x00b684Ca54D3174a13b28B9d08BcbbE18101e9A9` |
| Gas used | `655274` |
| Deployment fee | `0.0000655274 tBNB` |
| Sourcify verification | `exact_match` (creation and runtime bytecode) |

- [Contract on BscScan Testnet](https://testnet.bscscan.com/address/0x229d9a0ADEfea5A4f21477C1D83288D04b6D1a06)
- [Deployment transaction on BscScan Testnet](https://testnet.bscscan.com/tx/0x93c0eadbfe28a32d6f2d4c4f544fd87a8ea7678b9af14f2b64dd5e3bb46a088d)
- [Exact-match source on Sourcify](https://repo.sourcify.dev/97/0x229d9a0ADEfea5A4f21477C1D83288D04b6D1a06)

## Project structure

```text
src/GrandGangstaCity.sol
test/GrandGangstaCity.t.sol
script/DeployGrandGangstaCity.s.sol
lib/openzeppelin-contracts/  # pinned v5.6.1
lib/forge-std/
broadcast/
foundry.toml
remappings.txt
```

## Build and test

```bash
forge fmt --check
forge build
forge test -vvv
```

## Secure keystore setup

Never put a raw private key in this repository, an environment variable, documentation, or shell history.
Import it into Foundry's encrypted keystore from an interactive local prompt:

```bash
cast wallet import ggc-testnet-deployer --interactive
```

## Reproducing a BSC Testnet deployment

Network: BNB Smart Chain Testnet; chain ID: `97`; currency: `tBNB`; explorer:
`https://testnet.bscscan.com`. Copy `.env.example` to a local ignored `.env`, set the public values, and load it.
The script independently refuses to run unless `block.chainid == 97`.

```bash
set -a
source .env
set +a

cast chain-id --rpc-url "$BSC_TESTNET_RPC_URL"
forge script script/DeployGrandGangstaCity.s.sol:DeployGrandGangstaCity \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --account ggc-testnet-deployer \
  --sender 0xYOUR_DEPLOYER_ADDRESS \
  --broadcast \
  -vvvv
```

Enter the encrypted-keystore password only at Foundry's local prompt.

## Source verification

Set `CONTRACT_ADDRESS` to the deployed testnet address. Supply the explorer key only through the local
`ETHERSCAN_API_KEY` environment variable.

```bash
forge verify-contract \
  --chain 97 \
  --watch \
  --constructor-args "$(cast abi-encode 'constructor(address)' "$INITIAL_OWNER")" \
  "$CONTRACT_ADDRESS" \
  src/GrandGangstaCity.sol:GrandGangstaCity
```

## Independent read-only checks

```bash
cast call "$CONTRACT_ADDRESS" 'name()(string)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'symbol()(string)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'decimals()(uint8)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'totalSupply()(uint256)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'owner()(address)' --rpc-url "$BSC_TESTNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'balanceOf(address)(uint256)' "$INITIAL_OWNER" --rpc-url "$BSC_TESTNET_RPC_URL"
```

Expected raw total supply and owner balance:
`1000000000000000000000000000`.

## MetaMask import

1. Select **BNB Smart Chain Testnet**.
2. Choose **Import tokens**.
3. Paste the deployed contract address.
4. Confirm symbol `GGC` and decimals `18`.

This is a testnet deployment, not the mainnet token. A future mainnet deployment must have a different
contract address and must account for any existing GGC supply on other chains before launch.

## Mainnet operator handoff

Mainnet is not deployed from the testnet script. An authorized deployment operator must follow the separate
[BNB Smart Chain Mainnet deployment guide](MAINNET_DEPLOYMENT_GUIDE.md), which uses a dedicated chain-`56`
guarded script and encrypted-keystore workflow.
