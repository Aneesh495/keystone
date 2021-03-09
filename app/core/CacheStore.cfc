component {

    property name="maxSize" type="numeric";
    property name="defaultTtlSeconds" type="numeric";
    property name="cacheData" type="struct";
    property name="accessOrder" type="array";
    property name="stats" type="struct";

    /**
     * Constructor for CacheStore.
     */
    public any function init(numeric maxSize = 10000, numeric defaultTtlSeconds = 3600) {
        variables.maxSize = arguments.maxSize;
        variables.defaultTtlSeconds = arguments.defaultTtlSeconds;
        variables.cacheData = {};
        variables.accessOrder = [];
        variables.stats = {
            "hits": 0,
            "misses": 0,
            "evictions": 0,
            "expirations": 0,
            "puts": 0
        };
        return this;
    }

    /**
     * Stores a key-value pair with optional TTL.
     */
    public void function put(required string key, required any value, numeric ttlSeconds = 0) {
        var ttl = arguments.ttlSeconds > 0 ? arguments.ttlSeconds : variables.defaultTtlSeconds;
        var nowMs = createObject("java", "java.lang.System").currentTimeMillis();
        var expiresAt = nowMs + (ttl * 1000);

        lock name="keystone_cachestore_lock" type="exclusive" timeout="2" {
            // Check if key already exists to update access order
            var existingIndex = arrayFind(variables.accessOrder, arguments.key);
            if (existingIndex > 0) {
                arrayDeleteAt(variables.accessOrder, existingIndex);
            }

            // Evict LRU if at capacity
            if (arrayLen(variables.accessOrder) >= variables.maxSize) {
                var oldestKey = variables.accessOrder[1];
                arrayDeleteAt(variables.accessOrder, 1);
                structDelete(variables.cacheData, oldestKey);
                variables.stats.evictions++;
            }

            variables.cacheData[arguments.key] = {
                "value": arguments.value,
                "expiresAt": expiresAt,
                "createdAt": nowMs,
                "lastAccessed": nowMs
            };

            arrayAppend(variables.accessOrder, arguments.key);
            variables.stats.puts++;
        }
    }

    /**
     * Retrieves a cached value if present and unexpired.
     */
    public any function get(required string key, any defaultValue = nullValue()) {
        var nowMs = createObject("java", "java.lang.System").currentTimeMillis();
        var result = nullValue();
        var found = false;

        lock name="keystone_cachestore_lock" type="exclusive" timeout="2" {
            if (structKeyExists(variables.cacheData, arguments.key)) {
                var entry = variables.cacheData[arguments.key];
                if (nowMs <= entry.expiresAt) {
                    // Cache hit, update access order
                    entry.lastAccessed = nowMs;
                    var idx = arrayFind(variables.accessOrder, arguments.key);
                    if (idx > 0) {
                        arrayDeleteAt(variables.accessOrder, idx);
                    }
                    arrayAppend(variables.accessOrder, arguments.key);

                    result = entry.value;
                    found = true;
                    variables.stats.hits++;
                } else {
                    // Expired entry
                    structDelete(variables.cacheData, arguments.key);
                    var idx = arrayFind(variables.accessOrder, arguments.key);
                    if (idx > 0) {
                        arrayDeleteAt(variables.accessOrder, idx);
                    }
                    variables.stats.expirations++;
                    variables.stats.misses++;
                }
            } else {
                variables.stats.misses++;
            }
        }

        if (found) {
            return result;
        }

        return arguments.defaultValue;
    }

    /**
     * Atomic get-or-compute helper.
     */
    public any function getOrElse(required string key, required any computeClosure, numeric ttlSeconds = 0) {
        var val = get(arguments.key);
        if (!isNull(val)) {
            return val;
        }

        var computed = arguments.computeClosure();
        put(arguments.key, computed, arguments.ttlSeconds);
        return computed;
    }

    /**
     * Invalidates a single key.
     */
    public boolean function invalidate(required string key) {
        var removed = false;
        lock name="keystone_cachestore_lock" type="exclusive" timeout="2" {
            if (structKeyExists(variables.cacheData, arguments.key)) {
                structDelete(variables.cacheData, arguments.key);
                var idx = arrayFind(variables.accessOrder, arguments.key);
                if (idx > 0) {
                    arrayDeleteAt(variables.accessOrder, idx);
                }
                removed = true;
            }
        }
        return removed;
    }

    /**
     * Clears all entries and resets access order.
     */
    public void function clear() {
        lock name="keystone_cachestore_lock" type="exclusive" timeout="2" {
            variables.cacheData = {};
            variables.accessOrder = [];
        }
    }

    public numeric function size() {
        var count = 0;
        lock name="keystone_cachestore_lock" type="readOnly" timeout="2" {
            count = structCount(variables.cacheData);
        }
        return count;
    }

    public struct function getStats() {
        var result = {};
        lock name="keystone_cachestore_lock" type="readOnly" timeout="2" {
            result = duplicate(variables.stats);
            result["currentSize"] = structCount(variables.cacheData);
            result["maxSize"] = variables.maxSize;
            var totalRequests = variables.stats.hits + variables.stats.misses;
            result["hitRate"] = totalRequests > 0 ? (variables.stats.hits / totalRequests) : 0.0;
        }
        return result;
    }
}
