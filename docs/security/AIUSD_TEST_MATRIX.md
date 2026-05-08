# AIUSD Critical Path Matrix

Critical path coverage here refers to identified user/admin flows, not raw line coverage.

| Critical Path | Covered | Test References |
| --- | --- | --- |
| Wallet burns bUSDC reserve into free AIUSD balance | Yes | `test_RouteCapitalBurnsReserveAndCreditsAIUSD`, `testFuzz_RouteCapitalCreditsOneToOne`, `testIntegration_FullWalletManagedLifecycle` |
| Operator consumes separate reserve account into AIUSD | Yes | `test_AllocateStrategyBalanceFromReserveConsumesSeparateReserveAccount`, `operator can consume a separate reserve account into a managed AIUSD window` |
| Treasury desk allocates managed AIUSD to beneficiary | Yes | `test_AllocateStrategyBalanceCreditsBeneficiary`, `testFuzz_AllocateStrategyBalanceCreditsBeneficiary` |
| Treasury desk allocates managed AIUSD with execution epoch | Yes | `test_AllocateStrategyBalanceForEpochStoresReleaseTime`, `testFuzz_ManagedAllocationTracksManagedBalance`, `testIntegration_AggregatedExecutionWindowExtendsAcrossAllocations` |
| Managed balance cannot transfer before release | Yes | `test_TransferRevertsWhenExceedingTradableBalance`, `testSecurity_ManagedWindowExpiresBeforeTransfersUnlock`, `testFuzz_TransferAboveTradableReverts` |
| Free balance can transfer while managed balance remains constrained | Yes | `test_TransferWithinTradableBalanceSucceeds`, `testFuzz_TradableTransferPreservesManagedBalance` |
| Holder can settle only free balance | Yes | `test_SettleStrategyBalanceBurnsTradableOnly`, `testFuzz_SettleTradableCannotExceedFreePortion` |
| Desk can settle only managed balance | Yes | `test_SettleManagedStrategyBalanceReducesManagedWindow`, `testSecurity_OperatorCannotSettleMoreThanManagedEvenWithLargeFreeBalance`, `testFuzz_SettleManagedCannotExceedManagedPortion` |
| Expired execution window unlocks balance | Yes | `test_ManagedBalanceReturnsZeroAfterWindowExpires`, `test_ExpiredExecutionWindowIsIgnoredByReads`, `testIntegration_ExpiredManagedWindowUnlocksRestrictedBalance` |
| Reserve dispatch stays owner/operator-gated | Yes | `test_DispatchCapitalRequiresAuthorization`, `testSecurity_UnauthorizedDeskCannotDispatchCapital`, `testFuzz_DispatchCapitalMovesExactAmount` |
| Role administration stays owner-gated | Yes | `test_SetDeskOperatorOnlyOwner`, `testSecurity_ZeroOperatorAddressRejected`, `testFuzz_OperatorGrantCanBeToggled` |
| Token/controller accounting stays aligned across state transitions | Yes | `test_TradableBalanceMatchesFreePortion`, `testIntegration_ReserveIsConsumedBeforeOutstandingAIUSDMints`, `invariant_ControllerAndTokenViewsStayAligned` |
| Supply cap remains enforced | Yes | `test_SupplyCapIsEnforced`, `invariant_TotalSupplyNeverExceedsCap` |
