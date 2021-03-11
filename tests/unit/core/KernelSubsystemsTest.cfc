component {

    public void function run(required any suite) {
        var baseDir = getDirectoryFromPath(getCurrentTemplatePath()) & "../../../";

        suite.describe("Core: Config Subsystem", function(s) {
            s.it("loads default settings cleanly", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                s.assertEquals(8088, config.getInt("server.httpPort"));
                s.assertEquals("development", config.getString("node.environment"));
                s.assertTrue(config.getBool("security.requireAuth"));
            });

            s.it("supports programmatic configuration mutations", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                config.set("custom.nested.flag", true);
                s.assertTrue(config.getBool("custom.nested.flag"));
            });
        });

        suite.describe("Core: IdGenerator Subsystem", function(s) {
            s.it("generates monotonically ordered unique IDs", function() {
                var gen = new app.core.IdGenerator(nodeId = 7);
                var id1 = gen.nextId();
                var id2 = gen.nextId();
                s.assertTrue(len(id1) > 0);
                s.assertTrue(len(id2) > 0);
                s.assertTrue(id1 != id2);
            });

            s.it("generates valid RFC 9562 UUIDv7 format", function() {
                var gen = new app.core.IdGenerator(nodeId = 1);
                var uuidStr = gen.nextUuidV7();
                s.assertEquals(36, len(uuidStr));
                s.assertEquals("7", mid(uuidStr, 15, 1));
            });

            s.it("generates zero-padded control numbers", function() {
                var gen = new app.core.IdGenerator(nodeId = 1);
                var ctl = gen.nextControlNumber(9);
                s.assertEquals(9, len(ctl));
                s.assertTrue(isNumeric(ctl));
            });
        });

        suite.describe("Core: EventBus Subsystem", function(s) {
            s.it("delivers events to prioritized subscribers", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                var logger = new app.core.Logger(config = config, logDir = baseDir & "logs");
                var bus = new app.core.EventBus(logger = logger);

                var executionOrder = [];
                bus.subscribe("order.created", function(payload, evt) {
                    arrayAppend(executionOrder, "low");
                }, 10);

                bus.subscribe("order.created", function(payload, evt) {
                    arrayAppend(executionOrder, "high");
                }, 90);

                bus.publish("order.created", {"orderId": "ORD-123"});

                s.assertEquals(2, arrayLen(executionOrder));
                s.assertEquals("high", executionOrder[1]);
                s.assertEquals("low", executionOrder[2]);
            });

            s.it("supports wildcard event pattern routing", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                var logger = new app.core.Logger(config = config, logDir = baseDir & "logs");
                var bus = new app.core.EventBus(logger = logger);

                var captured = false;
                bus.subscribe("transaction.*", function(payload, evt) {
                    captured = true;
                });

                bus.publish("transaction.committed", {"tx": "100"});
                s.assertTrue(captured);
            });
        });

        suite.describe("Core: CacheStore Subsystem", function(s) {
            s.it("respects max capacity and enforces LRU eviction", function() {
                var cache = new app.core.CacheStore(maxSize = 2, defaultTtlSeconds = 60);
                cache.put("k1", "v1");
                cache.put("k2", "v2");
                s.assertEquals("v1", cache.get("k1"));

                // Inserting k3 should evict k2 (since k1 was just accessed)
                cache.put("k3", "v3");

                s.assertEquals("v1", cache.get("k1"));
                s.assertEquals("v3", cache.get("k3"));
                s.assertTrue(isNull(cache.get("k2")));
            });

            s.it("computes missing keys atomically via getOrElse", function() {
                var cache = new app.core.CacheStore(maxSize = 10, defaultTtlSeconds = 60);
                var callCount = 0;
                var res1 = cache.getOrElse("lazy_key", function() {
                    callCount++;
                    return "computed_val";
                });
                var res2 = cache.getOrElse("lazy_key", function() {
                    callCount++;
                    return "computed_val";
                });

                s.assertEquals("computed_val", res1);
                s.assertEquals("computed_val", res2);
                s.assertEquals(1, callCount);
            });
        });

        suite.describe("Core: LockManager Subsystem", function(s) {
            s.it("acquires and releases exclusive named lock leases", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                var logger = new app.core.Logger(config = config, logDir = baseDir & "logs");
                var lockMgr = new app.core.LockManager(lockDir = baseDir & "storage/locks", logger = logger);

                var token = lockMgr.acquire("resource_alpha", 10, 1);
                s.assertTrue(len(token) > 0);

                // Second acquire should fail / timeout
                var token2 = lockMgr.acquire("resource_alpha", 10, 1);
                s.assertEquals(0, len(token2));

                // Release first lock
                var released = lockMgr.release("resource_alpha", token);
                s.assertTrue(released);

                // Now acquire succeeds
                var token3 = lockMgr.acquire("resource_alpha", 10, 1);
                s.assertTrue(len(token3) > 0);
                lockMgr.release("resource_alpha", token3);
            });
        });
    }
}
