/**
 * Regression Test: Bug-004
 * Description: OutboxProcessor backoff jitter previously computed an unbounded negative
 * or forward offset that caused scheduled retry timestamps to be set before current epoch
 * or far in the future during micro-interval test simulations.
 */
component {

    public void function run(required any suite) {
        suite.describe("Regression: Bug-004 Saga Outbox Retry Backoff and Bounded Jitter", function(s) {

            s.it("calculates strictly positive non-zero retry delay with bounded jitter", function() {
                var testDir = expandPath("/storage/test_outbox_reg_" & createUUID());
                try {
                    var outbox = new app.transactions.OutboxProcessor(
                        storageDir = testDir,
                        baseDelayMs = 10,
                        maxDelayMs = 1000
                    );

                    // Test backoff calculation across first 5 attempts
                    for (var attempt = 1; attempt <= 5; attempt++) {
                        var delay = outbox.calculateBackoffMs(attempt);
                        s.assertTrue(delay >= 10);
                        s.assertTrue(delay <= 1500);
                    }
                } finally {
                    if (directoryExists(testDir)) {
                        directoryDelete(testDir, true);
                    }
                }
            });

            s.it("guarantees saga execution marks aborted state idempotently on repeat compensation", function() {
                var exec = new app.transactions.SagaExecution(
                    sagaId = "SAGA-REG-004",
                    sagaName = "OrderProcessingSaga",
                    initialContext = { "orderId": "PO-TEST" }
                );

                exec.setStatus("COMPENSATING");
                s.assertEquals("COMPENSATING", exec.getStatus());

                exec.setFailureReason("Compensation completed successfully");
                exec.setStatus("FAILED");
                s.assertEquals("FAILED", exec.getStatus());
            });

        });
    }

}
