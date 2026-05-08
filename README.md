# BridgeAxis Protocol

[![CI](https://github.com/bridgeaxis-protocol/bridgeaxis/actions/workflows/ci.yml/badge.svg)](https://github.com/bridgeaxis-protocol/bridgeaxis/actions/workflows/ci.yml)

BridgeAxis Protocol is the public audit repository for the BridgeAxis AIUSD contract system. It contains the contracts, test suites, security documentation, generated audit report, and CI workflow needed by reviewers.

This repository intentionally does **not** include the proprietary BridgeAxis web app, operator workspace, workers, exchange adapters, production database, runtime state, deployment secrets, or private infrastructure code.

## Public Scope

- AIUSD token contract.
- bUSDC reserve token contract.
- AIUSD controller contract.
- Foundry unit, integration, security, fuzz, and invariant tests.
- JS contract tests running against a local Ganache chain.
- Security docs, threat model, test matrix, and generated audit report.

## Test Coverage

| Category | Count |
| --- | ---: |
| Total AIUSD contract tests | 72 |
| Unit tests | 32 |
| Integration tests | 6 |
| Security tests | 8 |
| Fuzz tests | 22 |
| Invariant tests | 4 |
| Critical paths covered | 13 / 13 |

## Repository Map

- [Audit brief](./AUDIT.md)
- [Security policy](./SECURITY.md)
- [Contracts](./contracts/aiusd)
- [Contract package README](./contracts/aiusd/README.md)
- [Base deployment runbook](./contracts/aiusd/BASE_RUNBOOK.md)
- [Security docs](./docs/security)
- [Generated audit report](./reports/aiusd-audit-report.md)
- [Foundry tests](./test/foundry)
- [JS contract tests](./tests/contracts/aiusd.test.mjs)

## Install

Requirements:

- Node.js 22+
- npm
- Foundry

Install dependencies:

```bash
npm ci
forge install foundry-rs/forge-std --no-git
```

## Test Commands

```bash
npm run contracts:compile
npm test
npm run contracts:test:foundry
npm run contracts:audit:aiusd
```

## Contract Model

AIUSD uses a controlled reserve model:

- bUSDC is an internal reserve token.
- The controller burns bUSDC before minting AIUSD.
- AIUSD can be minted as tradable balance or as managed balance.
- Managed AIUSD cannot transfer while its execution window is active.
- Authorized desk settlement can burn locked managed AIUSD without holder approval.

## Official Links

- Website: https://bridgeaxis.io
- Discord: https://discord.gg/bridgeaxis
- X: https://x.com/bridgeaxis
- Telegram: https://t.me/bridgeaxis
- GitHub: https://github.com/bridgeaxis-protocol
