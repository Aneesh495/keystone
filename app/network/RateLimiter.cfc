/**
 * Keystone B2B Transaction Mesh - Token Bucket Rate Limiter
 *
 * Implements high-throughput token bucket rate limiting for inbound API and partner gateways
 * to protect backends from traffic spikes, denial-of-service, and contractual quota overruns.
 */
component {

    property name="defaultCapacity" type="numeric";
    property name="defaultRefillRate" type="numeric";
    property name="buckets" type="struct";
    property name="lockName" type="string";

    /**
     * Initializes the RateLimiter.
     *
     * @capacity Maximum token burst capacity per bucket (default: 100)
     * @refillRate Tokens added per second (default: 20)
     */
    public any function init(numeric capacity = 100, numeric refillRate = 20) {
        variables.defaultCapacity = arguments.capacity;
        variables.defaultRefillRate = arguments.refillRate;
        variables.buckets = {};
        variables.lockName = "keystone_rate_limiter_lock";

        return this;
    }

    /**
     * Attempts to acquire execution tokens from a named bucket.
     *
     * @key Unique bucket identifier (e.g. partner ID or client IP)
     * @tokens Number of tokens requested (default: 1)
     * @capacity Optional bucket-specific capacity override
     * @refillRate Optional bucket-specific refill rate override
     * @return Struct { "allowed": boolean, "remaining": numeric, "resetSeconds": numeric }
     */
    public struct function tryAcquire(
        required string key,
        numeric tokens = 1,
        numeric capacity = 0,
        numeric refillRate = 0
    ) {
        var cap = arguments.capacity > 0 ? arguments.capacity : variables.defaultCapacity;
        var rate = arguments.refillRate > 0 ? arguments.refillRate : variables.defaultRefillRate;
        var nowEpoch = getTickCount();
        var safeKey = reReplace(arguments.key, "[^a-zA-Z0-9_\-]", "_", "all");

        lock name="#variables.lockName#_#safeKey#" type="exclusive" timeout="5" {
            var bucket = "";
            if (structKeyExists(variables.buckets, safeKey)) {
                bucket = variables.buckets[safeKey];
                // Calculate elapsed time and refill tokens
                var elapsedSec = (nowEpoch - bucket.lastRefill) / 1000.0;
                var tokensToAdd = elapsedSec * rate;
                bucket.tokens = min(cap, bucket.tokens + tokensToAdd);
                bucket.lastRefill = nowEpoch;
            } else {
                bucket = {
                    "tokens": cap,
                    "lastRefill": nowEpoch,
                    "capacity": cap,
                    "rate": rate
                };
                variables.buckets[safeKey] = bucket;
            }

            if (bucket.tokens >= arguments.tokens) {
                bucket.tokens -= arguments.tokens;
                return {
                    "allowed": true,
                    "remaining": floor(bucket.tokens),
                    "resetSeconds": 0
                };
            } else {
                var needed = arguments.tokens - bucket.tokens;
                var waitSec = rate > 0 ? ceiling(needed / rate) : 60;
                return {
                    "allowed": false,
                    "remaining": floor(bucket.tokens),
                    "resetSeconds": waitSec
                };
            }
        }
    }

    /**
     * Resets a bucket back to full capacity.
     */
    public void function reset(required string key) {
        var safeKey = reReplace(arguments.key, "[^a-zA-Z0-9_\-]", "_", "all");
        lock name="#variables.lockName#_#safeKey#" type="exclusive" timeout="5" {
            structDelete(variables.buckets, safeKey);
        }
    }

    /**
     * Returns total active buckets currently tracked in memory.
     */
    public numeric function getActiveBucketCount() {
        return structCount(variables.buckets);
    }

}
