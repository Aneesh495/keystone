/**
 * Keystone B2B Transaction Mesh - Saga Coordinator
 *
 * Orchestrates distributed transaction workflows using the Saga execution pattern.
 * Manages forward step progression, transient retry handling, backward compensation
 * cascading, event emission, and durability journal integration.
 */
component {

    property name="kernel" type="any";
    property name="logger" type="any";
    property name="eventBus" type="any";
    property name="idGenerator" type="any";
    property name="journal" type="any";
    property name="definitions" type="struct";
    property name="executions" type="struct";

    /**
     * Initializes the SagaCoordinator with optional subsystem dependencies.
     */
    public any function init(any kernel = "") {
        variables.kernel = arguments.kernel;
        variables.definitions = {};
        variables.executions = {};

        if (isObject(variables.kernel)) {
            variables.logger = variables.kernel.hasService("logger") ? variables.kernel.getService("logger") : "";
            variables.eventBus = variables.kernel.hasService("eventBus") ? variables.kernel.getService("eventBus") : "";
            variables.idGenerator = variables.kernel.hasService("idGenerator") ? variables.kernel.getService("idGenerator") : "";
            variables.journal = variables.kernel.hasService("sagaJournal") ? variables.kernel.getService("sagaJournal") : "";
        } else {
            variables.logger = "";
            variables.eventBus = "";
            variables.idGenerator = "";
            variables.journal = "";
        }

        return this;
    }

    public void function setJournal(required any journal) {
        variables.journal = arguments.journal;
    }

    /**
     * Registers a SagaDefinition in the coordinator's registry.
     */
    public any function registerDefinition(required any definition) {
        variables.definitions[arguments.definition.getName()] = arguments.definition;
        return this;
    }

    /**
     * Retrieves a registered SagaDefinition.
     */
    public any function getDefinition(required string sagaName) {
        if (!structKeyExists(variables.definitions, arguments.sagaName)) {
            throw(type="SagaDefinitionNotFoundException", message="Saga definition [#arguments.sagaName#] is not registered");
        }
        return variables.definitions[arguments.sagaName];
    }

    /**
     * Executes a saga workflow from beginning to end.
     *
     * @sagaName Name of registered SagaDefinition, or a SagaDefinition instance
     * @initialContext Initial payload dictionary passed across steps
     * @sagaId Optional external tracking identifier
     */
    public any function execute(
        required any sagaName,
        struct initialContext = {},
        string sagaId = ""
    ) {
        var definition = "";
        if (isObject(arguments.sagaName)) {
            definition = arguments.sagaName;
        } else {
            definition = getDefinition(arguments.sagaName);
        }

        var execId = len(trim(arguments.sagaId)) ? arguments.sagaId : generateId();
        var execution = new app.transactions.SagaExecution(
            sagaId = execId,
            sagaName = definition.getName(),
            initialContext = arguments.initialContext
        );

        variables.executions[execId] = execution;
        logInfo("Starting saga [#definition.getName()#] with id [#execId#]");
        emitEvent("saga.started", { "sagaId": execId, "sagaName": definition.getName() });

        if (isObject(variables.journal)) {
            variables.journal.recordStart(execution);
        }

        execution.setStatus("RUNNING");
        var steps = definition.getSteps();
        var succeededSteps = [];
        var failed = false;
        var failureStep = "";
        var failureMsg = "";

        for (var i = 1; i <= arrayLen(steps); i++) {
            var step = steps[i];
            var stepName = step.getName();
            execution.recordStepStart(stepName);

            emitEvent("saga.step.started", { "sagaId": execId, "stepName": stepName });

            var stepResult = executeWithRetry(step, execution.getContext());

            if (stepResult.success) {
                execution.recordStepComplete(stepName, stepResult.result);
                arrayAppend(succeededSteps, step);

                // Merge step modifications into context if returned
                if (structKeyExists(stepResult.result, "contextUpdates") && isStruct(stepResult.result.contextUpdates)) {
                    structAppend(execution.getContext(), stepResult.result.contextUpdates, true);
                }

                if (isObject(variables.journal)) {
                    variables.journal.recordStepSuccess(execution, stepName, stepResult.result);
                }

                emitEvent("saga.step.completed", { "sagaId": execId, "stepName": stepName, "result": stepResult.result });
            } else {
                failed = true;
                failureStep = stepName;
                failureMsg = stepResult.error;
                execution.recordStepFailure(stepName, failureMsg);

                if (isObject(variables.journal)) {
                    variables.journal.recordStepFailure(execution, stepName, failureMsg);
                }

                emitEvent("saga.step.failed", { "sagaId": execId, "stepName": stepName, "error": failureMsg });
                break;
            }
        }

        if (!failed) {
            execution.setStatus("COMPLETED");
            if (isObject(variables.journal)) {
                variables.journal.recordComplete(execution);
            }
            logInfo("Saga [#definition.getName()#] id [#execId#] completed successfully");
            emitEvent("saga.completed", { "sagaId": execId, "sagaName": definition.getName() });
            return execution;
        }

        // Forward execution failed: begin backward compensation cascade
        logWarn("Saga [#definition.getName()#] id [#execId#] failed at step [#failureStep#]: #failureMsg#. Triggering compensation");
        execution.setStatus("COMPENSATING");
        emitEvent("saga.compensating", { "sagaId": execId, "stepName": failureStep, "reason": failureMsg });

        var compensationSuccess = compensate(succeededSteps, execution);

        if (compensationSuccess) {
            execution.setStatus("COMPENSATED");
            if (isObject(variables.journal)) {
                variables.journal.recordCompensated(execution);
            }
            logInfo("Saga [#definition.getName()#] id [#execId#] successfully compensated all steps");
            emitEvent("saga.compensated", { "sagaId": execId, "sagaName": definition.getName() });
        } else {
            execution.setStatus("FAILED");
            if (isObject(variables.journal)) {
                variables.journal.recordFailed(execution, "Compensation cascade encountered failures");
            }
            logError("Saga [#definition.getName()#] id [#execId#] failed compensation");
            emitEvent("saga.failed", { "sagaId": execId, "sagaName": definition.getName(), "reason": "Compensation failure" });
        }

        return execution;
    }

    /**
     * Executes a step with bounded retry and exponential backoff.
     */
    private struct function executeWithRetry(required any step, required struct context) {
        var attempts = 0;
        var limit = step.getRetryLimit();
        var delay = step.getRetryDelayMs();
        var lastError = "";

        while (attempts <= limit) {
            attempts++;
            try {
                var res = step.executeForward(arguments.context);
                if (isStruct(res) && structKeyExists(res, "success") && !res.success) {
                    lastError = structKeyExists(res, "message") ? res.message : "Step reported unsuccessful outcome";
                } else {
                    return { "success": true, "result": isStruct(res) ? res : { "result": res }, "error": "" };
                }
            } catch (any e) {
                lastError = e.message & (len(trim(e.detail)) ? " " & e.detail : "");
            }

            if (attempts <= limit && delay > 0) {
                sleep(delay);
                delay = delay * 2; // exponential backoff
            }
        }

        return { "success": false, "result": {}, "error": lastError };
    }

    /**
     * Executes compensation actions in reverse order of forward success.
     */
    private boolean function compensate(required array succeededSteps, required any execution) {
        var allOk = true;
        var count = arrayLen(arguments.succeededSteps);

        for (var i = count; i >= 1; i--) {
            var step = arguments.succeededSteps[i];
            var stepName = step.getName();

            try {
                var compResult = step.executeCompensation(arguments.execution.getContext());
                var isOk = true;
                if (isStruct(compResult) && structKeyExists(compResult, "success") && !compResult.success) {
                    isOk = false;
                }

                if (isOk) {
                    arguments.execution.recordCompensation(stepName, true);
                    emitEvent("saga.step.compensated", { "sagaId": arguments.execution.getId(), "stepName": stepName });
                } else {
                    allOk = false;
                    var err = structKeyExists(compResult, "message") ? compResult.message : "Compensation failed";
                    arguments.execution.recordCompensation(stepName, false, err);
                    emitEvent("saga.step.compensation_failed", { "sagaId": arguments.execution.getId(), "stepName": stepName, "error": err });
                }
            } catch (any e) {
                allOk = false;
                var errDetail = e.message & " " & e.detail;
                arguments.execution.recordCompensation(stepName, false, errDetail);
                emitEvent("saga.step.compensation_failed", { "sagaId": arguments.execution.getId(), "stepName": stepName, "error": errDetail });
            }
        }

        return allOk;
    }

    /**
     * Retrieves an active or completed execution by its identifier.
     */
    public any function getExecution(required string sagaId) {
        if (structKeyExists(variables.executions, arguments.sagaId)) {
            return variables.executions[arguments.sagaId];
        }
        if (isObject(variables.journal)) {
            var loaded = variables.journal.loadExecution(arguments.sagaId);
            if (isObject(loaded)) {
                variables.executions[arguments.sagaId] = loaded;
                return loaded;
            }
        }
        throw(type="SagaExecutionNotFoundException", message="Saga execution [#arguments.sagaId#] not found");
    }

    public struct function getAllExecutions() {
        return variables.executions;
    }

    private string function generateId() {
        if (isObject(variables.idGenerator)) {
            return variables.idGenerator.generate();
        }
        return createUUID();
    }

    private void function emitEvent(required string topic, required struct payload) {
        if (isObject(variables.eventBus)) {
            variables.eventBus.publish(arguments.topic, arguments.payload);
        }
    }

    private void function logInfo(required string message) {
        if (isObject(variables.logger)) {
            variables.logger.info(arguments.message);
        }
    }

    private void function logWarn(required string message) {
        if (isObject(variables.logger)) {
            variables.logger.warn(arguments.message);
        }
    }

    private void function logError(required string message) {
        if (isObject(variables.logger)) {
            variables.logger.error(arguments.message);
        }
    }

}
