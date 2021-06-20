/**
 * Keystone B2B Transaction Mesh - Idempotency Store
 *
 * Implements atomic check-and-set key reservation and cached response retrieval
 * to prevent duplicate processing of B2B transmissions across retries and network replays.
 */
component {

    property name="storageDir" type="string";
    property name="defaultTtlSeconds" type="numeric";
    property name="lockName" type="string";
    property name="memoryCache" type="struct";

    /**
     * Initializes the IdempotencyStore.
     *
     * @storageDir Filesystem directory for persistent idempotency keys
     * @defaultTtlSeconds Expiration window in seconds (default: 86400, 24 hours)
     */
    public any function init(
        string storageDir = "storage/idempotency",
        numeric defaultTtlSeconds = 86400
    ) {
        variables.storageDir = arguments.storageDir;
        variables.defaultTtlSeconds = arguments.defaultTtlSeconds;
        variables.lockName = "keystone_idempotency_store_lock";
        variables.memoryCache = {};

        ensureDirectory();

        return this;
    }

    private void function ensureDirectory() {
        if (!directoryExists(variables.storageDir)) {
            directoryCreate(variables.storageDir);
        }
    }

    /**
     * Attempts to atomically reserve an idempotency key.
     *
     * @key Unique idempotency key (e.g. sender + control number or payload hash)
     * @ttlSeconds Optional custom TTL in seconds
     * @return Struct { "acquired": boolean, "status": string, "cachedResult": any }
     */
    public struct function tryAcquire(required string key, numeric ttlSeconds = 0) {
        var ttl = arguments.ttlSeconds > 0 ? arguments.ttlSeconds : variables.defaultTtlSeconds;
        var nowEpoch = getTickCount();
        var safeKey = reReplace(arguments.key, "[^a-zA-Z0-9_\-]", "_", "all");

        lock name="#variables.lockName#_#safeKey#" type="exclusive" timeout="10" {
            // Check memory cache first
            if (structKeyExists(variables.memoryCache, safeKey)) {
                var memEntry = variables.memoryCache[safeKey];
                if (nowEpoch <= memEntry.expiresAt) {
                    if (memEntry.status == "COMPLETED") {
                        return { "acquired": false, "status": "COMPLETED", "cachedResult": memEntry.result };
                    } else if (memEntry.status == "IN_PROGRESS") {
                        return { "acquired": false, "status": "IN_PROGRESS", "cachedResult": "" };
                    }
                }
            }

            // Check disk storage
            var keyPath = variables.storageDir & "/" & safeKey & ".json";
            if (fileExists(keyPath)) {
                try {
                    var diskEntry = deserializeJson(fileRead(keyPath, "utf-8"));
                    if (nowEpoch <= diskEntry.expiresAt) {
                        variables.memoryCache[safeKey] = diskEntry;
                        if (diskEntry.status == "COMPLETED") {
                            return { "acquired": false, "status": "COMPLETED", "cachedResult": diskEntry.result };
                        } else if (diskEntry.status == "IN_PROGRESS") {
                            return { "acquired": false, "status": "IN_PROGRESS", "cachedResult": "" };
                        }
                    }
                } catch (any e) {
                    // Stale or corrupt file; will overwrite
                }
            }

            // Key is free: atomically acquire lease
            var newEntry = {
                "key": arguments.key,
                "status": "IN_PROGRESS",
                "createdAt": nowEpoch,
                "expiresAt": nowEpoch + (ttl * 1000),
                "result": ""
            };

            variables.memoryCache[safeKey] = newEntry;
            fileWrite(keyPath, serializeJson(newEntry), "utf-8");

            return { "acquired": true, "status": "IN_PROGRESS", "cachedResult": "" };
        }
    }

    /**
     * Marks an in-progress idempotency key as COMPLETED and stores its output.
     */
    public void function complete(required string key, required any result, numeric ttlSeconds = 0) {
        var ttl = arguments.ttlSeconds > 0 ? arguments.ttlSeconds : variables.defaultTtlSeconds;
        var nowEpoch = getTickCount();
        var safeKey = reReplace(arguments.key, "[^a-zA-Z0-9_\-]", "_", "all");
        var keyPath = variables.storageDir & "/" & safeKey & ".json";

        lock name="#variables.lockName#_#safeKey#" type="exclusive" timeout="10" {
            var entry = {
                "key": arguments.key,
                "status": "COMPLETED",
                "createdAt": nowEpoch,
                "expiresAt": nowEpoch + (ttl * 1000),
                "result": arguments.result
            };

            variables.memoryCache[safeKey] = entry;
            fileWrite(keyPath, serializeJson(entry), "utf-8");
        }
    }

    /**
     * Releases or marks an in-progress idempotency key as FAILED.
     */
    public void function fail(required string key, string reason = "") {
        var safeKey = reReplace(arguments.key, "[^a-zA-Z0-9_\-]", "_", "all");
        var keyPath = variables.storageDir & "/" & safeKey & ".json";

        lock name="#variables.lockName#_#safeKey#" type="exclusive" timeout="10" {
            structDelete(variables.memoryCache, safeKey);
            if (fileExists(keyPath)) {
                fileDelete(keyPath);
            }
        }
    }

    /**
     * Returns true if the key has been processed to completion.
     */
    public boolean function isCompleted(required string key) {
        var res = tryAcquire(arguments.key);
        return res.status == "COMPLETED";
    }

    /**
     * Clears expired keys from memory and disk.
     */
    public numeric function pruneExpired() {
        var nowEpoch = getTickCount();
        var count = 0;

        lock name="#variables.lockName#_global" type="exclusive" timeout="15" {
            for (var k in structKeyArray(variables.memoryCache)) {
                if (variables.memoryCache[k].expiresAt < nowEpoch) {
                    structDelete(variables.memoryCache, k);
                    count++;
                }
            }

            var files = directoryList(variables.storageDir, false, "query", "*.json");
            for (var f in files) {
                try {
                    var data = deserializeJson(fileRead(f.directory & "/" & f.name, "utf-8"));
                    if (data.expiresAt < nowEpoch) {
                        fileDelete(f.directory & "/" & f.name);
                        count++;
                    }
                } catch (any e) {
                    // Ignore transient file issue
                }
            }
        }

        return count;
    }

}
