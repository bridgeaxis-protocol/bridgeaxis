# AIUSD Contract Model

`AIUSD` uses a `reserve token + controller + transfer token` structure.

## Contracts

- `BUSDC.sol`
  - internal BridgeAxis reserve credit
  - `18` decimals, `bUSDC` symbol
  - admins/operators can mint reserve with a `bytes32 reasonId`
  - authorized burners can burn reserve without allowance
- `AIUSD.sol`
  - ERC-20 transfer layer
  - no public holder issuance path
  - no direct owner mint path
  - accepts mint/burn only from the configured execution hub
  - enforces transfer constraints by querying the execution hub
- `AIUSDController.sol`
  - consumes `bUSDC` and mints `AIUSD` 1:1
  - tracks per-account execution windows
  - supports tradable and time-locked strategy allocations
  - supports holder settlement and operator settlement of managed balances
- `IAIUSDController.sol`
  - small interface for execution-window lookups used by `AIUSD`

## Implemented behavior

- reserve-backed issuance flows through `routeCapital(amount)`
- operator-led issuance flows through `allocateStrategyBalance(...)`
- treasury reserve allocation can use `allocateStrategyBalanceFromReserve(...)`
- scheduled issuance flows through `allocateStrategyBalanceForEpoch(...)`
- one-year or custom locks are represented as execution windows
- holder settlement flows through `settleStrategyBalance(amount)`
- operator settlement of currently managed balances flows through
  `settleManagedStrategyBalance(...)`
- transfers are blocked when they would move managed balance before the
  release time

## bUSDC to AIUSD path

The reserve conversion is deliberately simple:

1. Reserve admin mints `bUSDC` to a treasury/operator account with `reasonId`.
2. `AIUSDController` must have `BUSDC.BURNER_ROLE`.
3. Controller burns `bUSDC` from the reserve account.
4. Controller mints the same amount of `AIUSD` to the beneficiary.

No USDC-style decimal scaling is performed in this layer. `bUSDC` and `AIUSD`
are both `18` decimals, and the conversion is always `1:1`.

## Execution window semantics

Each account keeps one aggregated execution window:

- `amount`: managed balance
- `releaseTime`: when the restriction expires

If a new scheduled provision is added before an older one has expired:

- the managed balance increases
- the release time extends to the later timestamp

Expired execution windows are cleared lazily when the controller mutates that account,
and are ignored automatically by all read paths.

## Useful reads

- token:
  - `managedBalanceOf(account)`
  - `tradableBalanceOf(account)`
- controller:
  - `managedBalanceOf(account)`
  - `tradableBalanceOf(account)`
  - `executionWindowEndsAt(account)`
  - `executionWindowOf(account)`
  - `getExecutionWindowInfo(account)`

## Deployment order

1. Deploy `BUSDC(admin)`.
2. Deploy `AIUSD(admin)`.
3. Deploy `AIUSDController(busdc, aiusd, owner)`.
4. Call `AIUSD.setExecutionHub(controller)` once from the token admin.
5. Grant `BUSDC.BURNER_ROLE` to the controller.
6. Optionally grant `OPERATOR_ROLE` on the controller to the desk operator.

After step 5, all `AIUSD` issuance through the controller requires burning
`bUSDC` first.

## Base rollout

The repository includes a deploy path for `Base`:

```bash
npm run contracts:deploy:busdc:base
npm run contracts:deploy:aiusd:base
npm run contracts:check:aiusd:base
npm run contracts:smoke:aiusd:base
npm run contracts:monitor:aiusd:base
npm run contracts:verify:aiusd:base
```

`contracts:deploy:aiusd:base` deploys a fresh `BUSDC` by default. To
reuse an existing reserve token, set:

```bash
BRIDGEAXIS_BUSDC_ADDRESS=0x...
```

## Test coverage

The repository includes JS contract tests plus a Foundry audit suite:

- `8` JS contract tests
- `72` Foundry Solidity tests
- `32` unit tests
- `6` integration tests
- `8` security tests
- `22` fuzz/property tests
- `4` invariant tests

Run it with:

```bash
npm run contracts:test
npm run contracts:test:foundry
npm run contracts:audit:aiusd
```

The current contract tests cover:

- `bUSDC` minting, burning, and 1:1 controller conversion into `AIUSD`
- separate reserve-account consumption by an authorized operator
- managed balance cannot transfer before the execution window ends
- tradable balance can still move
- holder settlement is limited to tradable balance
- desk settlement is limited to managed balance
- new managed allocation extends the aggregated execution window
- invariant alignment between token and controller views
