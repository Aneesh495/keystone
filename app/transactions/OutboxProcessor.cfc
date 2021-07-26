/**
 * Keystone B2B Transaction Mesh - Transactional Outbox Relay
 *
 * Implements the Transactional Outbox pattern to guarantee at-least-once message delivery
 * to external trading partners, event brokers, and downstream endpoints without dual-write hazards.
 */
component {

    property name="storageDir" type="string";
    property name="dlq" type="any";
    property name="logger" type="any";
    property name="eventBus" type="any";
    property name="maxAttempts" type="numeric";
    property name="baseDelayMs" type="numeric";
    property name="maxDelayMs" type="numeric";
    property name="lockName" type="string";

    /**
     * Initializes the OutboxProcessor.
     */
    public any function init(
        string storageDir = "storage/outbox",
        any dlq = "",
        any logger = "",
        any eventBus = "",
        numeric maxAttempts = 5,
        numeric baseDelayMs = 1000,
        numeric maxDelayMs = 60000
    ) {
        variables.storageDir = arguments.storageDir;
        variables.dlq = arguments.dlq;
        variables.logger = arguments.logger;
        variables.eventBus = arguments.eventBus;
        variables.maxAttempts = arguments.maxAttempts;
        variables.baseDelayMs = arguments.baseDelayMs;
        variables.maxDelayMs = arguments.maxDelayMs;
        variables.lockName = "keystone_outbox_lock";

        ensureDirectory();

        return this;
    }

    private void function ensureDirectory() {
        if (!directoryExists(variables.storageDir)) {
            directoryCreate(variables.storageDir);
        }
    }

    public void function setDlq(required any dlq) {
        variables.dlq = arguments.dlq;
    }

    /**
     * Enqueues a message into the transactional outbox.
     *
     * @topic Destination channel or routing topic
     * @payload Message payload dictionary
     * @headers Transmission metadata headers
     * @destination Optional specific URL or endpoint
     * @return Message identifier
     */
    public string function enqueue(
        required string topic,
        required struct payload,
        struct headers = {},
        string destination = ""
    ) {
        ensureDirectory();
        var msgId = createUUID();
        var entry = {
            "id": msgId,
            "topic": arguments.topic,
            "payload": arguments.payload,
            "headers": arguments.headers,
            "destination": arguments.destination,
            "status": "PENDING",
            "attempts": 0,
            "createdAt": getTickCount(),
            "nextAttemptAt": getTickCount(),
            "lastError": ""
        };

        var filePath = variables.storageDir & "/" & msgId & ".json";
        lock name="#variables.lockName#_#msgId#" type="exclusive" timeout="10" {
            fileWrite(filePath, serializeJson(entry), "utf-8");
        }

        if (isObject(variables.eventBus)) {
            variables.eventBus.publish("outbox.enqueued", { "messageId": msgId, "topic": arguments.topic });
        }

        return msgId;
    }

    /**
     * Processes a batch of pending outbox messages ready for dispatch.
     *
     * @batchSize Maximum messages to process in this cycle
     * @dispatcher Callable function or object executing the external dispatch
     * @return Struct { "processed": numeric, "succeeded": numeric, "failed": numeric, "deadLettered": numeric }
     */
    public struct function processBatch(numeric batchSize = 20, any dispatcher = "") {
        ensureDirectory();
        var nowEpoch = getTickCount();
        var stats = { "processed": 0, "succeeded": 0, "failed": 0, "deadLettered": 0 };
        var files = directoryList(variables.storageDir, false, "query", "*.json", "dateLastModified asc");

        for (var row in files) {
            if (stats.processed >= arguments.batchSize) {
                break;
            }

            var filePath = row.directory & "/" & row.name;
            var entry = "";

            try {
                entry = deserializeJson(fileRead(filePath, "utf-8"));
            } catch (any e) {
                continue;
            }

            if (entry.status != "PENDING" || entry.nextAttemptAt > nowEpoch) {
                continue;
            }

            stats.processed++;
            var dispatchOk = false;
            var errMsg = "";

            try {
                if (isCustomFunction(arguments.dispatcher) || isClosure(arguments.dispatcher)) {
                    var fn = arguments.dispatcher;
                    var res = fn(entry);
                    dispatchOk = isBoolean(res) ? res : (isStruct(res) && structKeyExists(res, "success") ? res.success : true);
                } else if (isObject(arguments.dispatcher) && structKeyExists(arguments.dispatcher, "dispatch")) {
                    var resObj = arguments.dispatcher.dispatch(entry);
                    dispatchOk = isBoolean(resObj) ? resObj : (isStruct(resObj) && structKeyExists(resObj, "success") ? resObj.success : true);
                } else {
                    // Default simulate success
                    dispatchOk = true;
                }
            } catch (any e) {
                dispatchOk = false;
                errMsg = e.message & " " & e.detail;
            }

            if (dispatchOk) {
                stats.succeeded++;
                lock name="#variables.lockName#_#entry.id#" type="exclusive" timeout="10" {
                    if (fileExists(filePath)) {
                        fileDelete(filePath);
                    }
                }
                if (isObject(variables.eventBus)) {
                    variables.eventBus.publish("outbox.dispatched", { "messageId": entry.id, "topic": entry.topic });
                }
            } else {
                stats.failed++;
                entry.attempts++;
                entry.lastError = errMsg;

                if (entry.attempts >= variables.maxAttempts) {
                    stats.deadLettered++;
                    entry.status = "DEAD_LETTERED";

                    if (isObject(variables.dlq)) {
                        variables.dlq.enqueue(
                            messageId = entry.id,
                            topic = entry.topic,
                            payload = entry.payload,
                            reason = "Outbox dispatch exceeded maximum attempts (" & variables.maxAttempts & "): " & errMsg,
                            metadata = { "destination": entry.destination, "headers": entry.headers, "attempts": entry.attempts }
                        );
                    }

                    lock name="#variables.lockName#_#entry.id#" type="exclusive" timeout="10" {
                        if (fileExists(filePath)) {
                            fileDelete(filePath);
                        }
                    }

                    if (isObject(variables.eventBus)) {
                        variables.eventBus.publish("outbox.dead_lettered", { "messageId": entry.id, "reason": errMsg });
                    }
                } else {
                    // Exponential backoff with jitter
                    var backoff = variables.baseDelayMs * (2 ^ (entry.attempts - 1));
                    var jitter = variables.baseDelayMs > 0 ? randRange(1, max(2, int(variables.baseDelayMs / 2))) : 0;
                    entry.nextAttemptAt = getTickCount() + backoff + jitter;

                    lock name="#variables.lockName#_#entry.id#" type="exclusive" timeout="10" {
                        fileWrite(filePath, serializeJson(entry), "utf-8");
                    }
                }
            }
        }

        return stats;
    }

    /**
     * Calculates exponential backoff delay with bounded jitter for an attempt number.
     */
    public numeric function calculateBackoffMs(numeric attempt = 1) {
        var expBackoff = variables.baseDelayMs * (2 ^ (arguments.attempt - 1));
        var bounded = min(expBackoff, variables.maxDelayMs);
        var jitter = variables.baseDelayMs > 0 ? randRange(1, max(2, int(variables.baseDelayMs / 2))) : 0;
        return bounded + jitter;
    }

    /**
     * Returns total pending messages awaiting dispatch in the outbox.
     */
    public numeric function getPendingCount() {
        ensureDirectory();
        var files = directoryList(variables.storageDir, false, "query", "*.json");
        return files.recordCount;
    }

}
