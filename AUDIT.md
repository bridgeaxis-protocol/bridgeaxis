# BridgeAxis Audit Brief

This document is the short audit entry point for BridgeAxis reviewers. It points to the contract package, runtime accounting paths, generated reports, and test commands that should be evaluated before production expansion.

## Review Scope

Primary onchain scope:

- `contracts/aiusd/BUSDC.sol`
- `contracts/aiusd/AIUSD.sol`
- `contracts/aiusd/AIUSDController.sol`
- `contracts/aiusd/IAIUSDController.sol`

Primary application/runtime scope:

- `lib/aiusd/onchain.js`
- `lib/server/aiusd-onchain-wallet-domain.js`
- `lib/server/dex-execution-accounting-domain/fees.js`
- `lib/server/dex-execution-accounting-domain/accounting.js`
- `lib/server/dex-live-execution-service/intents-impl/reconciliation-success-accounting.js`
- `lib/server/client-account-read-repository/treasury-aiusd-view.js`
- `components/app/aiusd-fee-payment-toggle.jsx`

## Contract Model

AIUSD uses a controlled reserve model:

- bUSDC is an internal reserve token.
- The controller burns bUSDC reserve before minting AIUSD.
- AIUSD can be minted as tradable balance or managed balance.
- Managed balance is non-transferable while an execution window is active.
- Authorized desk settlement can burn managed or tradable AIUSD according to controller roles.

## Current Deployment Assumptions

- Base mainnet is the current AIUSD deployment target.
- Base USDC is the active client deposit rail.
- Hyperliquid is the active execution venue.
- Momentum Alpha is the active live strategy.
- Additional venues and strategies are intentionally disabled or marked as roadmap until tested through the current rail.

## Test Coverage Summary

Generated from `reports/aiusd-audit-stats.json`:

| Category | Count |
| --- | ---: |
| Total AIUSD contract tests | 72 |
| Unit tests | 32 |
| Integration tests | 6 |
| Security tests | 8 |
| Fuzz tests | 22 |
| Invariant tests | 4 |
| Critical paths covered | 13 / 13 |

## Test Commands

```bash
npm ci
npm run contracts:compile
npm test
npm run contracts:test:foundry
npm run contracts:audit:aiusd
npm run test:server
npm run build
```

## Detailed Materials

- [AIUSD contract README](./contracts/aiusd/README.md)
- [Base deployment runbook](./contracts/aiusd/BASE_RUNBOOK.md)
- [AIUSD audit package](./docs/security/AIUSD_AUDIT_PACKAGE.md)
- [AIUSD threat model](./docs/security/AIUSD_THREAT_MODEL.md)
- [AIUSD test matrix](./docs/security/AIUSD_TEST_MATRIX.md)
- [Generated audit report](./reports/aiusd-audit-report.md)
- [Docker deployment notes](./docs/DOCKER.md)

## Public CI

CI is expected to run the contract tests, Foundry suite, audit report generation, production build, health check, and smoke check:

- `https://github.com/bridgeaxis-protocol/bridgeaxis/actions`

