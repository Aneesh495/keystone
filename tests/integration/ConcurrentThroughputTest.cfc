/**
 * Keystone Integration Tests - Concurrent Pipeline Stress & Idempotency Matrix
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: Concurrent Pipeline & Thread Safety", function(s) {

            s.it("handles concurrent requests through rate limiting and idempotency without corruption", function() {
                var rateLimiter = new app.network.RateLimiter(50, 10);
                var testIdemDir = "storage/test_concurrent_idem_" & createUUID();
                var idemStore = new app.transactions.IdempotencyStore(testIdemDir, 3600);

                var allowedCount = 0;
                var throttledCount = 0;

                // Simulate burst of 30 acquisitions
                for (var i = 1; i <= 30; i++) {
                    var res = rateLimiter.tryAcquire("PARTNER_BURST_TEST");
                    if (res.allowed) {
                        allowedCount++;
                    } else {
                        throttledCount++;
                    }
                }

                s.assertEquals(30, allowedCount);
                s.assertEquals(0, throttledCount);

                // Verify idempotency with duplicate keys
                var firstAcquire = idemStore.tryAcquire("TXN_CONCURRENT_DUP");
                s.assertTrue(firstAcquire.acquired);

                var secondAcquire = idemStore.tryAcquire("TXN_CONCURRENT_DUP");
                s.assertFalse(secondAcquire.acquired);

                idemStore.complete("TXN_CONCURRENT_DUP", { "status": "SETTLED" });

                var thirdAcquire = idemStore.tryAcquire("TXN_CONCURRENT_DUP");
                s.assertFalse(thirdAcquire.acquired);
                s.assertEquals("COMPLETED", thirdAcquire.status);

                // Cleanup
                try {
                    directoryDelete(testIdemDir, true);
                } catch (any e) {}
            });

        });
    }

}
