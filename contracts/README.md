# Contracts

BridgeAxis now has a small onchain `AIUSD` layer built around an internal
reserve token and an execution controller:

- `contracts/aiusd/BUSDC.sol`
- `contracts/aiusd/AIUSD.sol`
- `contracts/aiusd/AIUSDController.sol`
- `contracts/aiusd/IAIUSDController.sol`

Implemented model:

- `bUSDC` is the internal reserve credit.
- reserve admins can mint `bUSDC` with a `reasonId`.
- the controller burns `bUSDC` before minting `AIUSD` 1:1.
- `AIUSD` cannot be minted directly by holders or by the token owner.
- desk operators can allocate tradable or time-locked strategy balance.
- managed balance can be burned by the controller without holder approval.
- transfers are constrained while managed balance remains inside an active
  execution window.

Compile with:

```bash
npm run contracts:compile
```

Test with:

```bash
npm test
npm run contracts:test:foundry
npm run contracts:audit:aiusd
```

Deploy to Base with:

```bash
npm run contracts:deploy:busdc:base
npm run contracts:deploy:aiusd:base
npm run contracts:check:aiusd:base
npm run contracts:smoke:aiusd:base
npm run contracts:monitor:aiusd:base
npm run contracts:verify:aiusd:base
```

`contracts:deploy:aiusd:base` deploys `bUSDC` automatically unless
`BRIDGEAXIS_BUSDC_ADDRESS` points at an existing reserve token.

Artifacts are written to:

- `artifacts/contracts/aiusd/*.json`
- deployment records: `artifacts/deployments/aiusd/*.json`
- audit reports: `reports/aiusd-audit-report.md`
- audit stats: `reports/aiusd-audit-stats.json`

Current AIUSD test package metrics:

- `8` JS contract tests
- `72` Foundry Solidity tests
- `32` unit tests
- `6` integration tests
- `8` security tests
- `22` fuzz tests
- `4` invariant tests

Supporting security docs:

- `docs/security/AIUSD_AUDIT_PACKAGE.md`
- `docs/security/AIUSD_THREAT_MODEL.md`
- `docs/security/AIUSD_TEST_MATRIX.md`
