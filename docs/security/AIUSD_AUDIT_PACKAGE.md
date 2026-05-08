# AIUSD Audit Package

This package is intended to support external reviewers and security tooling with
reproducible evidence around the current `AIUSD` contract surface.

## Included

- Solidity `Foundry` test suites for:
  - unit tests
  - integration tests
  - security/authorization tests
  - fuzz/property tests
  - invariants
- deployment and verification runbooks
- critical-path coverage matrix
- threat model for the current contract scope

## Commands

Run the full `Foundry` suite:

```bash
$HOME/.foundry/bin/forge test
```

Generate the audit report with current metrics:

```bash
node scripts/aiusd-audit-package.mjs
```

## Notes

- This is not a substitute for an external audit.
- Test metrics are generated from the current repository state and should be
  regenerated whenever the contracts or test suites change.
