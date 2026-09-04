# BNB Smart Chain Mainnet Deployment Handoff

This runbook is for the authorized deployment operator. It deploys exactly one fixed-supply
`GrandGangstaCity` contract to BNB Smart Chain Mainnet, chain ID `56`.

## Non-negotiable checks

- Mainnet uses real BNB and every broadcast is irreversible.
- Obtain an independent professional review before deployment.
- Confirm the intended mainnet owner/initial-recipient address through a trusted private channel.
- The owner/recipient address may differ from the deployer. The deployer only signs the creation transaction
  and pays gas; the constructor sends the complete supply to `MAINNET_INITIAL_OWNER`.
- The owner address, token allocation, constructor input, and ownership event are public after deployment.
- Check all existing or planned GGC supplies on other chains before creating the mainnet supply.
- Never reuse the BSC Testnet contract address as a mainnet address.
- Never place a private key, mnemonic, keystore password, or API key in this repository or shell history.

## Fixed token configuration

| Property | Value |
| --- | --- |
| Contract | `GrandGangstaCity` |
| Name | `Grand Gangsta City` |
| Symbol | `GGC` |
| Decimals | `18` |
| Supply | `1,000,000,000 GGC` |
| Raw supply | `1000000000000000000000000000` |
| OpenZeppelin Contracts | `v5.6.1` |
| Solidity | `0.8.24` |
| Optimizer | Enabled, 200 runs |

There is no callable mint, burn, pause, blacklist, tax, fee, freeze, seizure, upgrade, or arbitrary balance
function. OpenZeppelin `Ownable` only supplies standard ownership-management functions.

## 1. Clone and validate

```bash
git clone https://github.com/wali-hu/grand-gangsta-city-token.git
cd grand-gangsta-city-token

forge --version
cast --version
forge fmt --check
forge build
forge test -vvv
```

Do not continue unless every test passes and the reviewed Git commit is the intended release commit.

## 2. Create an encrypted deployer keystore

The deployer wallet must contain enough real BNB for gas. It does not need to receive or own any GGC.

```bash
cast wallet import ggc-mainnet-deployer --interactive
```

Enter the private key and a strong keystore password only in the local interactive prompts. Record the public
deployer address shown by Foundry, but never copy the private key into a command or environment variable.

## 3. Create ignored mainnet configuration

```bash
cp .env.mainnet.example .env.mainnet
chmod 600 .env.mainnet
```

Edit `.env.mainnet` locally and replace `0xPUBLIC_OWNER_ADDRESS` with the independently confirmed public
owner/initial-recipient address. Do not add secrets.

```bash
set -a
source .env.mainnet
set +a

cast to-check-sum-address "$MAINNET_INITIAL_OWNER"
```

Stop if the address is malformed or is the zero address.

## 4. Mandatory preflight

Set the public deployer address printed during keystore import:

```bash
DEPLOYER_ADDRESS=0xPUBLIC_DEPLOYER_ADDRESS
```

Confirm the RPC is BSC Mainnet and never proceed unless the first command prints exactly `56`:

```bash
cast chain-id --rpc-url "$BSC_MAINNET_RPC_URL"
cast balance "$DEPLOYER_ADDRESS" --ether --rpc-url "$BSC_MAINNET_RPC_URL"
cast nonce "$DEPLOYER_ADDRESS" --rpc-url "$BSC_MAINNET_RPC_URL"
```

Run a non-broadcast simulation:

```bash
forge script script/DeployGrandGangstaCityMainnet.s.sol:DeployGrandGangstaCityMainnet \
  --rpc-url "$BSC_MAINNET_RPC_URL" \
  --sender "$DEPLOYER_ADDRESS" \
  -vvvv
```

Verify the simulation prints:

- chain `56`;
- owner equal to `MAINNET_INITIAL_OWNER`;
- supply and owner balance equal to `1000000000000000000000000000`;
- exactly one contract-creation transaction;
- an affordable gas estimate and sufficient deployer balance.

## 5. Final broadcast

Before running this command, re-check the owner address, reviewed Git commit, chain ID, deployer balance, and
estimated fee with another authorized reviewer. The script itself rejects every chain except `56` and requires
the exact `DEPLOY_GGC_TO_BSC_MAINNET` confirmation from `.env.mainnet`.

```bash
forge script script/DeployGrandGangstaCityMainnet.s.sol:DeployGrandGangstaCityMainnet \
  --rpc-url "$BSC_MAINNET_RPC_URL" \
  --account ggc-mainnet-deployer \
  --sender "$DEPLOYER_ADDRESS" \
  --broadcast \
  -vvvv
```

Enter the encrypted-keystore password only at Foundry's local prompt. Save the contract address, transaction
hash, block number, deployer address, gas used, gas price, fee, Git commit, and broadcast artifact.

## 6. Verify source

Set the deployed public address:

```bash
CONTRACT_ADDRESS=0xDEPLOYED_MAINNET_CONTRACT_ADDRESS
```

Sourcify verification does not require an explorer API key:

```bash
forge verify-contract \
  --chain 56 \
  --verifier sourcify \
  --watch \
  --constructor-args "$(cast abi-encode 'constructor(address)' "$MAINNET_INITIAL_OWNER")" \
  "$CONTRACT_ADDRESS" \
  src/GrandGangstaCity.sol:GrandGangstaCity
```

For BscScan/Etherscan-native verification, enter the API key without echoing or storing it:

```bash
read -rsp "Etherscan API key: " ETHERSCAN_API_KEY
echo
export ETHERSCAN_API_KEY

forge verify-contract \
  --chain 56 \
  --verifier etherscan \
  --watch \
  --constructor-args "$(cast abi-encode 'constructor(address)' "$MAINNET_INITIAL_OWNER")" \
  "$CONTRACT_ADDRESS" \
  src/GrandGangstaCity.sol:GrandGangstaCity

unset ETHERSCAN_API_KEY
```

Verification failure must not trigger a redeployment. Diagnose and retry verification against the same address.

## 7. Independent on-chain checks

```bash
cast receipt "$DEPLOYMENT_TX_HASH" --rpc-url "$BSC_MAINNET_RPC_URL"
cast code "$CONTRACT_ADDRESS" --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'name()(string)' --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'symbol()(string)' --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'decimals()(uint8)' --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'totalSupply()(uint256)' --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'owner()(address)' --rpc-url "$BSC_MAINNET_RPC_URL"
cast call "$CONTRACT_ADDRESS" 'balanceOf(address)(uint256)' "$MAINNET_INITIAL_OWNER" \
  --rpc-url "$BSC_MAINNET_RPC_URL"
```

Required results:

- transaction receipt status is successful;
- runtime bytecode is non-empty;
- name is `Grand Gangsta City`;
- symbol is `GGC`;
- decimals are `18`;
- total supply is `1000000000000000000000000000`;
- `owner()` equals `MAINNET_INITIAL_OWNER`;
- owner balance equals total supply.

Mainnet explorer URLs:

```text
https://bscscan.com/address/<CONTRACT_ADDRESS>
https://bscscan.com/tx/<DEPLOYMENT_TX_HASH>
```

Do not send tokens, transfer ownership, or renounce ownership as part of deployment verification unless separately
authorized by the relevant owner.
