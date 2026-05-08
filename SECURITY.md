# Security Policy

BridgeAxis security review starts with the AIUSD contract package and the runtime accounting paths that settle platform fees, venue funding, strategy allocation, and return flows.

## Supported Review Scope

Current review scope:

- AIUSD, bUSDC, and controller contracts.
- Base deployment scripts and verification scripts.
- AIUSD onchain balance reads in the client workspace.
- AIUSD fee-discount settlement in DEX accounting.
- Hyperliquid funding and return accounting.
- Dockerized production runtime layout.

Out of scope for the current public review:

- Undisclosed production secrets.
- Private RPC keys.
- Operator credentials.
- External venue custody systems outside BridgeAxis code.

## Reporting

For private vulnerability reports, contact the BridgeAxis operator team through the official channels listed on the public site:

- Website: `https://bridgeaxis.io`
- GitHub organization: `https://github.com/bridgeaxis-protocol`
- Discord: `https://discord.gg/bridgeaxis`
- X: `https://x.com/bridgeaxis`
- Telegram: `https://t.me/bridgeaxis`

## Audit Materials

- [Audit brief](./AUDIT.md)
- [AIUSD audit package](./docs/security/AIUSD_AUDIT_PACKAGE.md)
- [AIUSD threat model](./docs/security/AIUSD_THREAT_MODEL.md)
- [AIUSD test matrix](./docs/security/AIUSD_TEST_MATRIX.md)
- [Generated audit report](./reports/aiusd-audit-report.md)

## Secret Handling

The repository intentionally ignores:

- `.env`
- `.env.local`
- `.env.*.local`
- sqlite databases
- runtime state
- generated deployment records containing live deployment metadata
- local operator evidence and server reports

Never commit private keys, RPC credentials, operator access keys, production sqlite files, or exchange secrets.
