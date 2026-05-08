# AIUSD Threat Model

## Scope

Contracts in scope:

- `contracts/aiusd/BUSDC.sol`
- `contracts/aiusd/AIUSD.sol`
- `contracts/aiusd/AIUSDController.sol`
- `contracts/aiusd/IAIUSDController.sol`

## Trust Assumptions

- `BUSDC.DEFAULT_ADMIN_ROLE` is a trusted reserve governance account.
- `BUSDC.MINTER_ROLE` can create internal reserve credit and must be treated as treasury-critical.
- `BUSDC.BURNER_ROLE` is granted to `AIUSDController` so it can consume reserve without holder approval.
- `AIUSDController.owner()` is a trusted governance or treasury control account.
- `OPERATOR_ROLE` represents a trusted execution desk role delegated by the owner.
- `AIUSD` supply changes are expected to happen only through the configured execution hub.

## Primary Risks Modeled

1. Unauthorized `bUSDC` minting.
2. `AIUSD` minting without first burning `bUSDC`.
3. Unauthorized execution-window settlement or reserve dispatch.
4. Managed balances escaping transfer restrictions before the execution window expires.
5. Incorrect accounting between token balances and controller state.
6. Supply cap bypass.
7. Stale execution-window state after expiry or settlement.
8. Multi-account leakage where one account's managed state affects another.

## Out of Scope

1. Reserve governance key compromise.
2. External market risk for future public AIUSD liquidity.
3. Multisig or governance process failures outside the contracts.
4. Cross-chain bridge risk.
5. Oracle or pricing logic, because the current contracts do not consume oracle data.
6. Frontend, signing, or session-management bugs in the application layer.

## Security Objectives

- `AIUSD` total supply must remain bounded by `MAX_SUPPLY`.
- `AIUSD` issuance through the controller must consume `bUSDC` first.
- Transfer restrictions must enforce the execution window for managed balances.
- Controller and token read models must remain aligned.
- Unauthorized actors must not mint reserve, allocate, settle, dispatch, or administer roles.
- Expired windows must unlock balances cleanly.
