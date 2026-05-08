# AIUSD Base Runbook

`AIUSD`, `bUSDC`, and `AIUSDController` deploy to Base with one deployer wallet
as the initial owner/admin. No multisig or pending action workflow is required
for this deployment model.

## Scope

- deploy or reuse `BUSDC`
- deploy `AIUSD`
- deploy `AIUSDController`
- connect the token to the execution hub
- grant the controller `BUSDC.BURNER_ROLE`
- optionally grant the desk operator role
- verify the deployed configuration against the saved deployment record
- execute a reusable onchain smoke against the live deployment
- run a deployment monitor that can escalate to Telegram

## Required env

Fill `.env.aiusd.local` for contract deployments. Leave `.env.local` for the
web app, runtime workers, and trading rails.

```bash
BRIDGEAXIS_AIUSD_DEPLOY_CHAIN=base
BRIDGEAXIS_AIUSD_DEPLOY_RPC_URL=
BRIDGEAXIS_AIUSD_DEPLOY_PRIVATE_KEY=
```

## Optional env

```bash
BRIDGEAXIS_BUSDC_ADDRESS=
BRIDGEAXIS_AIUSD_DESK_OPERATOR=
BRIDGEAXIS_AIUSD_DEPLOY_OUTPUT=
BRIDGEAXIS_AIUSD_DEPLOYMENT_FILE=
BRIDGEAXIS_BASESCAN_API_KEY=
BRIDGEAXIS_AIUSD_MONITOR_MIN_DEPLOYER_ETH=0.03
BRIDGEAXIS_AIUSD_MONITOR_ALERT_COOLDOWN_HOURS=12
BRIDGEAXIS_TELEGRAM_BOT_TOKEN=
BRIDGEAXIS_TELEGRAM_CHAT_ID=
```

Deployment ownership:

- the deployer wallet is the `bUSDC` admin
- the deployer wallet is the `AIUSD` token admin
- the deployer wallet is the `AIUSDController` owner
- if `desk operator` is omitted, no operator grant is attempted
- if `BRIDGEAXIS_BUSDC_ADDRESS` is omitted, the AIUSD deploy script deploys a
  fresh `BUSDC`
- the deploy script wires the stack immediately and fails if the deployer cannot
  execute a privileged setup transaction

## Commands

Compile contracts:

```bash
npm run contracts:compile
```

Deploy only a fresh `BUSDC` reserve token:

```bash
npm run contracts:deploy:busdc:base
```

Deploy the full AIUSD stack to Base:

```bash
npm run contracts:deploy:aiusd:base
```

Check the latest deployment record:

```bash
npm run contracts:check:aiusd:base
```

Run the reusable live smoke:

```bash
npm run contracts:smoke:aiusd:base
```

Run the deployment monitor:

```bash
npm run contracts:monitor:aiusd:base
```

Submit verified source to BaseScan:

```bash
npm run contracts:verify:aiusd:base
```

## Ops examples

Mint reserve:

```bash
npm run contracts:ops:aiusd:base -- mint-busdc 10000000 treasury-backup
```

Burn reserve and mint tradable AIUSD to the operator wallet:

```bash
npm run contracts:ops:aiusd:base -- route-capital 1000 treasury-route
```

Burn reserve from a treasury account and mint locked AIUSD to a beneficiary:

```bash
npm run contracts:ops:aiusd:base -- allocate-epoch-from-reserve 0xReserve 0xBeneficiary 1000 31536000 annual-lock
```

## Safety guardrails

- scripts verify the connected RPC chain id before submitting transactions
- default deployment chain is Base mainnet (`8453`)
- deployment records are written to `artifacts/deployments/aiusd/`
- monitor state is written under `artifacts/runtime/aiusd/`
- dynamic deployment JSON files are git-ignored on purpose
