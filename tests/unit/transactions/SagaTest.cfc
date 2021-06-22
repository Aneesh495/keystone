/**
 * Keystone Unit Tests - Saga Orchestration & Transaction Management
 */
component {

    public void function run(required any suite) {
        suite.describe("Transactions: Distributed Saga Orchestrator", function(s) {

            s.it("executes multi-step saga successfully when all forward steps pass", function() {
                var coordinator = new app.transactions.SagaCoordinator();
                var definition = new app.transactions.SagaDefinition("ORDER_FULFILLMENT");

                definition.addStep("VALIDATE_INVENTORY", function(ctx) {
                    ctx.inventoryReserved = true;
                    return { "success": true, "contextUpdates": { "inventoryId": "INV-99" } };
                }, function(ctx) {
                    ctx.inventoryReserved = false;
                });

                definition.addStep("CHARGE_PAYMENT", function(ctx) {
                    ctx.paymentCaptured = true;
                    return { "success": true, "contextUpdates": { "paymentRef": "PAY-777" } };
                }, function(ctx) {
                    ctx.paymentCaptured = false;
                });

                definition.addStep("DISPATCH_WAREHOUSE", function(ctx) {
                    ctx.dispatched = true;
                    return { "success": true, "contextUpdates": { "shipmentId": "SHIP-101" } };
                }, function(ctx) {
                    ctx.dispatched = false;
                });

                coordinator.registerDefinition(definition);

                var execution = coordinator.execute("ORDER_FULFILLMENT", { "orderId": "ORD-12345" });

                s.assertEquals("COMPLETED", execution.getStatus());
                s.assertEquals("INV-99", execution.getContextValue("inventoryId"));
                s.assertEquals("PAY-777", execution.getContextValue("paymentRef"));
                s.assertEquals("SHIP-101", execution.getContextValue("shipmentId"));
                s.assertEquals(3, arrayLen(execution.getStepHistory()));
                s.assertEquals(0, arrayLen(execution.getCompensationHistory()));
            });

            s.it("triggers backward compensation in reverse order when a forward step fails", function() {
                var coordinator = new app.transactions.SagaCoordinator();
                var definition = new app.transactions.SagaDefinition("RESERVATION_WITH_ROLLBACK");

                var compensationLog = [];

                definition.addStep("STEP_ONE", function(ctx) {
                    return { "success": true };
                }, function(ctx) {
                    arrayAppend(compensationLog, "COMPENSATE_STEP_ONE");
                    return { "success": true };
                });

                definition.addStep("STEP_TWO", function(ctx) {
                    return { "success": true };
                }, function(ctx) {
                    arrayAppend(compensationLog, "COMPENSATE_STEP_TWO");
                    return { "success": true };
                });

                definition.addStep("STEP_THREE_FAILS", function(ctx) {
                    throw(type="DatabaseOutageException", message="Connection reset by peer");
                }, function(ctx) {
                    arrayAppend(compensationLog, "COMPENSATE_STEP_THREE");
                    return { "success": true };
                }, 1000, 1, 10);

                coordinator.registerDefinition(definition);

                var execution = coordinator.execute("RESERVATION_WITH_ROLLBACK");

                s.assertEquals("COMPENSATED", execution.getStatus());
                s.assertEquals(2, arrayLen(compensationLog));
                // Reverse order: STEP_TWO compensated first, then STEP_ONE
                s.assertEquals("COMPENSATE_STEP_TWO", compensationLog[1]);
                s.assertEquals("COMPENSATE_STEP_ONE", compensationLog[2]);
            });

            s.it("records FAILED status when backward compensation encounters an error", function() {
                var coordinator = new app.transactions.SagaCoordinator();
                var definition = new app.transactions.SagaDefinition("FATAL_ROLLBACK");

                definition.addStep("INITIAL_RESERVE", function(ctx) {
                    return { "success": true };
                }, function(ctx) {
                    throw(type="FatalCompensationException", message="Cannot revert resource");
                });

                definition.addStep("CRITICAL_ACTION", function(ctx) {
                    return { "success": false, "message": "Third party service rejected payload" };
                }, "", 1000, 0);

                coordinator.registerDefinition(definition);

                var execution = coordinator.execute("FATAL_ROLLBACK");
                s.assertEquals("FAILED", execution.getStatus());
            });

            s.it("persists and reconstitutes saga execution state via SagaJournal", function() {
                var testJournalDir = "storage/test_journal_" & createUUID();
                var journal = new app.transactions.SagaJournal(testJournalDir);
                var exec = new app.transactions.SagaExecution("TEST-SAGA-001", "PO_INGEST", { "poNumber": "PO-888" });
                exec.setStatus("RUNNING");

                journal.recordStart(exec);
                journal.recordStepSuccess(exec, "VALIDATE", { "valid": true });
                exec.setStatus("COMPLETED");
                journal.recordComplete(exec);

                var loaded = journal.loadExecution("TEST-SAGA-001");
                s.assertEquals("TEST-SAGA-001", loaded.getId());
                s.assertEquals("COMPLETED", loaded.getStatus());
                s.assertEquals("PO-888", loaded.getContextValue("poNumber"));

                // Cleanup
                try {
                    directoryDelete(testJournalDir, true);
                } catch (any e) {}
            });

            s.it("enforces atomic check and set and cached results via IdempotencyStore", function() {
                var testIdemDir = "storage/test_idem_" & createUUID();
                var store = new app.transactions.IdempotencyStore(testIdemDir, 3600);

                var res1 = store.tryAcquire("MSG-UNIQUE-999");
                s.assertTrue(res1.acquired);
                s.assertEquals("IN_PROGRESS", res1.status);

                // Second call while in progress should not acquire
                var res2 = store.tryAcquire("MSG-UNIQUE-999");
                s.assertFalse(res2.acquired);
                s.assertEquals("IN_PROGRESS", res2.status);

                // Mark completed
                store.complete("MSG-UNIQUE-999", { "status": "DELIVERED", "code": 200 });

                // Third call should see COMPLETED with cached result
                var res3 = store.tryAcquire("MSG-UNIQUE-999");
                s.assertFalse(res3.acquired);
                s.assertEquals("COMPLETED", res3.status);
                s.assertTrue(isStruct(res3.cachedResult));
                s.assertEquals("DELIVERED", res3.cachedResult.status);

                // Cleanup
                try {
                    directoryDelete(testIdemDir, true);
                } catch (any e) {}
            });

            s.it("routes permanent failures through Outbox to DeadLetterQueue and supports replay", function() {
                var testOutboxDir = "storage/test_outbox_" & createUUID();
                var testDlqDir = "storage/test_dlq_" & createUUID();

                var dlq = new app.transactions.DeadLetterQueue(testDlqDir);
                var outbox = new app.transactions.OutboxProcessor(
                    storageDir = testOutboxDir,
                    dlq = dlq,
                    maxAttempts = 2,
                    baseDelayMs = 10
                );

                var msgId = outbox.enqueue("EDI.X12.850.OUTBOUND", { "order": "PO-100" });

                // First attempt: failing dispatcher
                var stats1 = outbox.processBatch(10, function(entry) {
                    return { "success": false, "message": "Downstream endpoint connection refused" };
                });
                s.assertEquals(1, stats1.processed);
                s.assertEquals(1, stats1.failed);

                // Wait briefly for backoff
                sleep(50);

                // Second attempt: fails again, should dead-letter
                var stats2 = outbox.processBatch(10, function(entry) {
                    return { "success": false, "message": "Downstream endpoint permanently unreachable" };
                });
                s.assertEquals(1, stats2.processed);
                s.assertEquals(1, stats2.deadLettered);

                // Verify message arrived in DLQ
                var dlqMsg = dlq.getMessage(msgId);
                s.assertEquals(msgId, dlqMsg.id);
                s.assertEquals("PENDING_REVIEW", dlqMsg.status);

                // Replay message with working handler
                var replayed = false;
                var replayRes = dlq.replay(msgId, function(payload, meta) {
                    replayed = true;
                    return true;
                });

                s.assertTrue(replayRes.success);
                s.assertTrue(replayed);
                var updatedMsg = dlq.getMessage(msgId);
                s.assertEquals("REPLAYED", updatedMsg.status);

                // Cleanup
                try {
                    directoryDelete(testOutboxDir, true);
                    directoryDelete(testDlqDir, true);
                } catch (any e) {}
            });

        });
    }

}
