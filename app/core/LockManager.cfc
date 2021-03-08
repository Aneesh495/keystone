component {

    property name="lockDir" type="string";
    property name="logger" type="any";
    property name="inMemoryLocks" type="struct";

    /**
     * Constructor for LockManager.
     *
     * @lockDir Directory for persistent lock leases
     * @logger Logger instance
     */
    public any function init(required string lockDir, required any logger) {
        variables.lockDir = arguments.lockDir;
        variables.logger = arguments.logger;
        variables.inMemoryLocks = {};

        if (!directoryExists(variables.lockDir)) {
            directoryCreate(variables.lockDir);
        }

        return this;
    }

    /**
     * Attempts to acquire a named lock with lease expiration.
     *
     * @resourceKey Unique name of the lock resource
     * @leaseSeconds Duration in seconds before lock expires automatically
     * @timeoutSeconds Maximum time to wait attempting to acquire the lock
     * @return Lock token string if acquired, empty string if failed
     */
    public string function acquire(required string resourceKey, numeric leaseSeconds = 30, numeric timeoutSeconds = 5) {
        var cleanKey = reReplace(arguments.resourceKey, "[^a-zA-Z0-9_\-\.]", "_", "all");
        var lockFile = variables.lockDir & "/" & cleanKey & ".lock";
        var token = createUUID();
        var startTime = createObject("java", "java.lang.System").currentTimeMillis();
        var timeoutMs = arguments.timeoutSeconds * 1000;

        while (true) {
            var acquired = false;
            lock name="keystone_lockmgr_" & cleanKey type="exclusive" timeout="2" {
                var nowMs = createObject("java", "java.lang.System").currentTimeMillis();
                var leaseMs = arguments.leaseSeconds * 1000;
                var isExpired = false;

                if (structKeyExists(variables.inMemoryLocks, cleanKey)) {
                    var existing = variables.inMemoryLocks[cleanKey];
                    if (nowMs > existing.expiresAt) {
                        isExpired = true;
                    }
                } else {
                    isExpired = true;
                }

                if (isExpired) {
                    variables.inMemoryLocks[cleanKey] = {
                        "token": token,
                        "resource": arguments.resourceKey,
                        "acquiredAt": nowMs,
                        "expiresAt": nowMs + leaseMs
                    };

                    // Write lock file
                    var lockRecord = {
                        "token": token,
                        "resource": arguments.resourceKey,
                        "acquiredAt": nowMs,
                        "expiresAt": nowMs + leaseMs
                    };
                    try {
                        fileWrite(lockFile, serializeJson(lockRecord), "utf-8");
                    } catch (any e) {
                        // ignore file write error in memory mode
                    }

                    acquired = true;
                }
            }

            if (acquired) {
                return token;
            }

            var elapsed = createObject("java", "java.lang.System").currentTimeMillis() - startTime;
            if (elapsed >= timeoutMs) {
                return "";
            }

            // Sleep briefly before retry
            createObject("java", "java.lang.Thread").sleep(50);
        }
    }

    /**
     * Releases an acquired lock if the token matches.
     */
    public boolean function release(required string resourceKey, required string token) {
        var cleanKey = reReplace(arguments.resourceKey, "[^a-zA-Z0-9_\-\.]", "_", "all");
        var lockFile = variables.lockDir & "/" & cleanKey & ".lock";
        var released = false;

        lock name="keystone_lockmgr_" & cleanKey type="exclusive" timeout="2" {
            if (structKeyExists(variables.inMemoryLocks, cleanKey)) {
                if (variables.inMemoryLocks[cleanKey].token == arguments.token) {
                    structDelete(variables.inMemoryLocks, cleanKey);
                    if (fileExists(lockFile)) {
                        try {
                            fileDelete(lockFile);
                        } catch (any e) {
                            // ignore
                        }
                    }
                    released = true;
                }
            }
        }

        return released;
    }

    /**
     * Renews the lease duration for an active lock.
     */
    public boolean function extend(required string resourceKey, required string token, numeric additionalSeconds = 30) {
        var cleanKey = reReplace(arguments.resourceKey, "[^a-zA-Z0-9_\-\.]", "_", "all");
        var extended = false;

        lock name="keystone_lockmgr_" & cleanKey type="exclusive" timeout="2" {
            if (structKeyExists(variables.inMemoryLocks, cleanKey)) {
                if (variables.inMemoryLocks[cleanKey].token == arguments.token) {
                    var nowMs = createObject("java", "java.lang.System").currentTimeMillis();
                    variables.inMemoryLocks[cleanKey].expiresAt = nowMs + (arguments.additionalSeconds * 1000);
                    extended = true;
                }
            }
        }

        return extended;
    }

    /**
     * Executes a callback closure within a managed lock lease.
     */
    public any function withLock(required string resourceKey, required any action, numeric leaseSeconds = 30, numeric timeoutSeconds = 5) {
        var token = acquire(arguments.resourceKey, arguments.leaseSeconds, arguments.timeoutSeconds);
        if (len(token) == 0) {
            throw(type="LockAcquisitionTimeoutException", message="Failed to acquire lock for resource: " & arguments.resourceKey);
        }

        try {
            return arguments.action();
        } finally {
            release(arguments.resourceKey, token);
        }
    }

    public struct function getActiveLocks() {
        var result = {};
        lock name="keystone_lockmgr_global" type="readOnly" timeout="2" {
            result = duplicate(variables.inMemoryLocks);
        }
        return result;
    }
}
