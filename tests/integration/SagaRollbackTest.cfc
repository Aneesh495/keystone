/**
 * Keystone Integration Tests - Multi-Step Distributed Saga Rollback Flow
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: Distributed Saga Rollback & Compensation", function(s) {

            s.it("rolls back prior completed steps when downstream gateway fails and journals state", function() {
                var testJournalDir = "storage/test_saga_rollback_" & createUUID();
                var journal = new app.transactions.SagaJournal(testJournalDir);
                var coordinator = new app.transactions.SagaCoordinator();
                coordinator.setJournal(journal);

                var inventoryReverted = false;
                var allocationCancelled = false;

                var definition = new app.transactions.SagaDefinition("PAYMENT_SETTLEMENT_SAGA");

                definition.addStep("ALLOCATE_CREDIT", function(ctx) {
                    ctx.creditAllocated = true;
                    return { "success": true, "contextUpdates": { "allocationId": "ALLOC-88" } };
                }, function(ctx) {
                    allocationCancelled = true;
                    return { "success": true };
                });

                definition.addStep("RESERVE_INVENTORY", function(ctx) {
                    ctx.inventoryReserved = true;
                    return { "success": true, "contextUpdates": { "reservationId": "RES-99" } };
                }, function(ctx) {
                    inventoryReverted = true;
                    return { "success": true };
                });

                definition.addStep("TRANSMIT_SETTLEMENT", function(ctx) {
                    throw(type="BankClearinghouseTimeoutException", message="Clearinghouse endpoint timed out after 30000ms");
                }, "", 1000, 0);

                coordinator.registerDefinition(definition);

                var execution = coordinator.execute("PAYMENT_SETTLEMENT_SAGA", { "txId": "TXN-ROLL-1" });

                s.assertEquals("COMPENSATED", execution.getStatus());
                s.assertTrue(inventoryReverted);
                s.assertTrue(allocationCancelled);

                // Verify journal captured terminal status
                var loaded = journal.loadExecution(execution.getId());
                s.assertEquals("COMPENSATED", loaded.getStatus());

                // Cleanup
                try {
                    directoryDelete(testJournalDir, true);
                } catch (any e) {}
            });

        });
    }

}
