/**
 * Keystone B2B Transaction Mesh - Durable Saga Journal
 *
 * Provides append-only, crash-safe state journaling for distributed saga transactions,
 * supporting crash recovery, reconstitution of in-flight sagas, and auditing.
 */
component {

    property name="journalDir" type="string";
    property name="lockName" type="string";

    /**
     * Initializes the SagaJournal with the specified durable storage directory.
     */
    public any function init(string journalDir = "storage/journal") {
        variables.journalDir = arguments.journalDir;
        variables.lockName = "keystone_saga_journal_lock";

        ensureDirectory();

        return this;
    }

    private void function ensureDirectory() {
        if (!directoryExists(variables.journalDir)) {
            directoryCreate(variables.journalDir);
        }
    }

    /**
     * Records the initial start transition of a saga.
     */
    public void function recordStart(required any execution) {
        appendEntry(arguments.execution.getId(), {
            "type": "SAGA_STARTED",
            "sagaId": arguments.execution.getId(),
            "sagaName": arguments.execution.getName(),
            "status": "RUNNING",
            "timestamp": now(),
            "context": arguments.execution.getContext()
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Records successful step completion.
     */
    public void function recordStepSuccess(required any execution, required string stepName, struct result = {}) {
        appendEntry(arguments.execution.getId(), {
            "type": "STEP_SUCCEEDED",
            "sagaId": arguments.execution.getId(),
            "stepName": arguments.stepName,
            "timestamp": now(),
            "result": arguments.result
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Records step execution failure.
     */
    public void function recordStepFailure(required any execution, required string stepName, required string error) {
        appendEntry(arguments.execution.getId(), {
            "type": "STEP_FAILED",
            "sagaId": arguments.execution.getId(),
            "stepName": arguments.stepName,
            "timestamp": now(),
            "error": arguments.error
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Records full saga completion.
     */
    public void function recordComplete(required any execution) {
        appendEntry(arguments.execution.getId(), {
            "type": "SAGA_COMPLETED",
            "sagaId": arguments.execution.getId(),
            "timestamp": now()
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Records full compensation completion.
     */
    public void function recordCompensated(required any execution) {
        appendEntry(arguments.execution.getId(), {
            "type": "SAGA_COMPENSATED",
            "sagaId": arguments.execution.getId(),
            "timestamp": now()
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Records saga terminal failure.
     */
    public void function recordFailed(required any execution, required string reason) {
        appendEntry(arguments.execution.getId(), {
            "type": "SAGA_FAILED",
            "sagaId": arguments.execution.getId(),
            "timestamp": now(),
            "reason": arguments.reason
        });
        saveSnapshot(arguments.execution);
    }

    /**
     * Persists a point-in-time snapshot of the execution state.
     */
    public void function saveSnapshot(required any execution) {
        ensureDirectory();
        var snapshotPath = variables.journalDir & "/" & arguments.execution.getId() & ".json";
        var jsonContent = serializeJson(arguments.execution.toStruct());

        lock name="#variables.lockName#_#arguments.execution.getId()#" type="exclusive" timeout="10" {
            fileWrite(snapshotPath, jsonContent, "utf-8");
        }
    }

    /**
     * Appends an event to the saga-specific journal stream.
     */
    private void function appendEntry(required string sagaId, required struct entry) {
        ensureDirectory();
        var logPath = variables.journalDir & "/" & arguments.sagaId & ".journal";
        var line = serializeJson(arguments.entry) & chr(10);

        lock name="#variables.lockName#_#arguments.sagaId#" type="exclusive" timeout="10" {
            var fileObj = fileOpen(logPath, "append", "utf-8");
            try {
                fileWriteLine(fileObj, line);
            } finally {
                fileClose(fileObj);
            }
        }
    }

    /**
     * Reconstitutes a SagaExecution from its durable snapshot.
     */
    public any function loadExecution(required string sagaId) {
        var snapshotPath = variables.journalDir & "/" & arguments.sagaId & ".json";
        if (!fileExists(snapshotPath)) {
            return "";
        }

        var json = "";
        lock name="#variables.lockName#_#arguments.sagaId#" type="readOnly" timeout="10" {
            json = fileRead(snapshotPath, "utf-8");
        }

        var raw = deserializeJson(json);
        var exec = new app.transactions.SagaExecution(
            sagaId = raw.sagaId,
            sagaName = raw.sagaName,
            initialContext = isStruct(raw.context) ? raw.context : {}
        );
        exec.setStatus(raw.status);

        if (structKeyExists(raw, "failureReason")) {
            exec.setFailureReason(raw.failureReason);
        }

        return exec;
    }

    /**
     * Lists active or recent sagas from the journal storage.
     */
    public array function listExecutions(numeric limit = 100, string statusFilter = "") {
        ensureDirectory();
        var results = [];
        var files = directoryList(variables.journalDir, false, "query", "*.json", "dateLastModified desc");

        for (var row in files) {
            if (arrayLen(results) >= arguments.limit) {
                break;
            }
            try {
                var content = fileRead(row.directory & "/" & row.name, "utf-8");
                var data = deserializeJson(content);
                if (len(trim(arguments.statusFilter)) == 0 || data.status == arguments.statusFilter) {
                    arrayAppend(results, data);
                }
            } catch (any e) {
                // Ignore transient write collisions
            }
        }

        return results;
    }

    /**
     * Detects incomplete in-flight sagas requiring recovery after system crash.
     */
    public array function recoverIncompleteSagas() {
        var running = listExecutions(1000, "RUNNING");
        var compensating = listExecutions(1000, "COMPENSATING");
        var incomplete = [];

        for (var r in running) {
            arrayAppend(incomplete, r);
        }
        for (var c in compensating) {
            arrayAppend(incomplete, c);
        }

        return incomplete;
    }

}
