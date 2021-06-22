/**
 * Keystone B2B Transaction Mesh - Dead Letter Queue (DLQ)
 *
 * Captures, isolates, and preserves poison messages, unroutable payloads, and failed saga transactions.
 * Supports manual and automated re-drive operations, diagnostic inspections, and audit triage.
 */
component {

    property name="storageDir" type="string";
    property name="lockName" type="string";
    property name="logger" type="any";
    property name="eventBus" type="any";

    /**
     * Initializes the DeadLetterQueue.
     */
    public any function init(
        string storageDir = "storage/dlq",
        any logger = "",
        any eventBus = ""
    ) {
        variables.storageDir = arguments.storageDir;
        variables.logger = arguments.logger;
        variables.eventBus = arguments.eventBus;
        variables.lockName = "keystone_dlq_lock";

        ensureDirectory();

        return this;
    }

    private void function ensureDirectory() {
        if (!directoryExists(variables.storageDir)) {
            directoryCreate(variables.storageDir);
        }
    }

    /**
     * Enqueues a failed message into the dead letter queue.
     *
     * @messageId Unique tracking identifier
     * @topic Original topic or routing channel
     * @payload Unprocessed or failed message body
     * @reason Diagnostic explanation for failure
     * @metadata Diagnostic context, headers, or execution stack trace
     * @return Message identifier
     */
    public string function enqueue(
        required string messageId,
        required string topic,
        required any payload,
        required string reason,
        struct metadata = {}
    ) {
        ensureDirectory();
        var entry = {
            "id": arguments.messageId,
            "topic": arguments.topic,
            "payload": arguments.payload,
            "reason": arguments.reason,
            "metadata": arguments.metadata,
            "status": "PENDING_REVIEW",
            "enqueuedAt": now(),
            "replayedAt": "",
            "replayCount": 0,
            "discardReason": ""
        };

        var filePath = variables.storageDir & "/" & arguments.messageId & ".json";
        lock name="#variables.lockName#_#arguments.messageId#" type="exclusive" timeout="10" {
            fileWrite(filePath, serializeJson(entry), "utf-8");
        }

        if (isObject(variables.logger)) {
            variables.logger.error("Dead-lettered message [#arguments.messageId#] on topic [#arguments.topic#]: #arguments.reason#");
        }

        if (isObject(variables.eventBus)) {
            variables.eventBus.publish("dlq.message_enqueued", {
                "messageId": arguments.messageId,
                "topic": arguments.topic,
                "reason": arguments.reason
            });
        }

        return arguments.messageId;
    }

    /**
     * Retrieves an individual message by identifier.
     */
    public struct function getMessage(required string messageId) {
        var filePath = variables.storageDir & "/" & arguments.messageId & ".json";
        if (!fileExists(filePath)) {
            throw(type="DLQMessageNotFoundException", message="DLQ message [#arguments.messageId#] does not exist");
        }

        lock name="#variables.lockName#_#arguments.messageId#" type="readOnly" timeout="10" {
            return deserializeJson(fileRead(filePath, "utf-8"));
        }
    }

    /**
     * Lists dead letter queue messages with optional filtering.
     */
    public array function list(numeric limit = 100, string statusFilter = "") {
        ensureDirectory();
        var results = [];
        var files = directoryList(variables.storageDir, false, "query", "*.json", "dateLastModified desc");

        for (var row in files) {
            if (arrayLen(results) >= arguments.limit) {
                break;
            }

            try {
                var content = fileRead(row.directory & "/" & row.name, "utf-8");
                var item = deserializeJson(content);
                if (len(trim(arguments.statusFilter)) == 0 || item.status == arguments.statusFilter) {
                    arrayAppend(results, item);
                }
            } catch (any e) {
                // Ignore transient write lock
            }
        }

        return results;
    }

    /**
     * Re-drives / replays a dead-lettered message to a target handler.
     */
    public struct function replay(required string messageId, required any targetHandler) {
        var msg = getMessage(arguments.messageId);
        var success = false;
        var error = "";

        try {
            if (isCustomFunction(arguments.targetHandler) || isClosure(arguments.targetHandler)) {
                var fn = arguments.targetHandler;
                var res = fn(msg.payload, msg.metadata);
                success = isBoolean(res) ? res : (isStruct(res) && structKeyExists(res, "success") ? res.success : true);
            } else if (isObject(arguments.targetHandler) && structKeyExists(arguments.targetHandler, "handle")) {
                var resObj = arguments.targetHandler.handle(msg.payload, msg.metadata);
                success = isBoolean(resObj) ? resObj : (isStruct(resObj) && structKeyExists(resObj, "success") ? resObj.success : true);
            }
        } catch (any e) {
            success = false;
            error = e.message & " " & e.detail;
        }

        if (success) {
            msg.status = "REPLAYED";
            msg.replayedAt = now();
            msg.replayCount++;
            var filePath = variables.storageDir & "/" & arguments.messageId & ".json";
            lock name="#variables.lockName#_#arguments.messageId#" type="exclusive" timeout="10" {
                fileWrite(filePath, serializeJson(msg), "utf-8");
            }
            if (isObject(variables.eventBus)) {
                variables.eventBus.publish("dlq.message_replayed", { "messageId": arguments.messageId });
            }
            return { "success": true, "messageId": arguments.messageId };
        } else {
            msg.replayCount++;
            var filePath2 = variables.storageDir & "/" & arguments.messageId & ".json";
            lock name="#variables.lockName#_#arguments.messageId#" type="exclusive" timeout="10" {
                fileWrite(filePath2, serializeJson(msg), "utf-8");
            }
            return { "success": false, "messageId": arguments.messageId, "error": error };
        }
    }

    /**
     * Permanently discards a dead-lettered message.
     */
    public void function discard(required string messageId, string reason = "") {
        var msg = getMessage(arguments.messageId);
        msg.status = "DISCARDED";
        msg.discardReason = arguments.reason;

        var filePath = variables.storageDir & "/" & arguments.messageId & ".json";
        lock name="#variables.lockName#_#arguments.messageId#" type="exclusive" timeout="10" {
            fileWrite(filePath, serializeJson(msg), "utf-8");
        }

        if (isObject(variables.eventBus)) {
            variables.eventBus.publish("dlq.message_discarded", { "messageId": arguments.messageId, "reason": arguments.reason });
        }
    }

    /**
     * Returns summary metrics of the dead letter queue.
     */
    public struct function getSummary() {
        var pending = 0;
        var replayed = 0;
        var discarded = 0;

        var allItems = list(10000);
        for (var item in allItems) {
            if (item.status == "PENDING_REVIEW") {
                pending++;
            } else if (item.status == "REPLAYED") {
                replayed++;
            } else if (item.status == "DISCARDED") {
                discarded++;
            }
        }

        return {
            "total": arrayLen(allItems),
            "pending": pending,
            "replayed": replayed,
            "discarded": discarded
        };
    }

}
