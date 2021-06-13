/**
 * Keystone B2B Transaction Mesh - Saga Execution State
 *
 * Tracks the live lifecycle, step execution outcomes, and compensation journal
 * for an active or completed saga instance.
 */
component {

    property name="sagaId" type="string";
    property name="sagaName" type="string";
    property name="status" type="string";
    property name="context" type="struct";
    property name="stepHistory" type="array";
    property name="compensationHistory" type="array";
    property name="createdAt" type="date";
    property name="updatedAt" type="date";
    property name="completedAt" type="any";
    property name="failureReason" type="string";

    /**
     * Initializes a new SagaExecution context instance.
     */
    public any function init(
        required string sagaId,
        required string sagaName,
        struct initialContext = {}
    ) {
        variables.sagaId = arguments.sagaId;
        variables.sagaName = arguments.sagaName;
        variables.status = "PENDING";
        variables.context = duplicate(arguments.initialContext);
        variables.stepHistory = [];
        variables.compensationHistory = [];
        variables.createdAt = now();
        variables.updatedAt = now();
        variables.completedAt = "";
        variables.failureReason = "";

        return this;
    }

    public string function getId() {
        return variables.sagaId;
    }

    public string function getName() {
        return variables.sagaName;
    }

    public string function getStatus() {
        return variables.status;
    }

    public void function setStatus(required string newStatus) {
        variables.status = arguments.newStatus;
        variables.updatedAt = now();
        if (arguments.newStatus == "COMPLETED" || arguments.newStatus == "COMPENSATED" || arguments.newStatus == "FAILED") {
            variables.completedAt = now();
        }
    }

    public struct function getContext() {
        return variables.context;
    }

    public void function setContext(required struct newContext) {
        variables.context = arguments.newContext;
        variables.updatedAt = now();
    }

    public any function getContextValue(required string key, any defaultValue = "") {
        if (structKeyExists(variables.context, arguments.key)) {
            return variables.context[arguments.key];
        }
        return arguments.defaultValue;
    }

    public void function setContextValue(required string key, required any value) {
        variables.context[arguments.key] = arguments.value;
        variables.updatedAt = now();
    }

    public array function getStepHistory() {
        return variables.stepHistory;
    }

    public array function getCompensationHistory() {
        return variables.compensationHistory;
    }

    public string function getFailureReason() {
        return variables.failureReason;
    }

    public void function setFailureReason(required string reason) {
        variables.failureReason = arguments.reason;
        variables.updatedAt = now();
    }

    /**
     * Records the start of a step.
     */
    public void function recordStepStart(required string stepName) {
        arrayAppend(variables.stepHistory, {
            "stepName": arguments.stepName,
            "status": "RUNNING",
            "startedAt": getTickCount(),
            "completedAt": 0,
            "durationMs": 0,
            "result": {},
            "error": ""
        });
        variables.updatedAt = now();
    }

    /**
     * Records successful completion of a step.
     */
    public void function recordStepComplete(required string stepName, struct stepResult = {}) {
        var len = arrayLen(variables.stepHistory);
        for (var i = len; i >= 1; i--) {
            if (variables.stepHistory[i].stepName == arguments.stepName && variables.stepHistory[i].status == "RUNNING") {
                var finish = getTickCount();
                variables.stepHistory[i].status = "COMPLETED";
                variables.stepHistory[i].completedAt = finish;
                variables.stepHistory[i].durationMs = finish - variables.stepHistory[i].startedAt;
                variables.stepHistory[i].result = arguments.stepResult;
                break;
            }
        }
        variables.updatedAt = now();
    }

    /**
     * Records failure of a forward step.
     */
    public void function recordStepFailure(required string stepName, required string errorMessage) {
        var len = arrayLen(variables.stepHistory);
        for (var i = len; i >= 1; i--) {
            if (variables.stepHistory[i].stepName == arguments.stepName && variables.stepHistory[i].status == "RUNNING") {
                var finish = getTickCount();
                variables.stepHistory[i].status = "FAILED";
                variables.stepHistory[i].completedAt = finish;
                variables.stepHistory[i].durationMs = finish - variables.stepHistory[i].startedAt;
                variables.stepHistory[i].error = arguments.errorMessage;
                break;
            }
        }
        variables.failureReason = arguments.errorMessage;
        variables.updatedAt = now();
    }

    /**
     * Records successful compensation of a step.
     */
    public void function recordCompensation(required string stepName, required boolean success, string errorMessage = "") {
        arrayAppend(variables.compensationHistory, {
            "stepName": arguments.stepName,
            "success": arguments.success,
            "timestamp": now(),
            "error": arguments.errorMessage
        });
        variables.updatedAt = now();
    }

    /**
     * Serializes execution state to a struct representation.
     */
    public struct function toStruct() {
        return {
            "sagaId": variables.sagaId,
            "sagaName": variables.sagaName,
            "status": variables.status,
            "context": variables.context,
            "stepHistory": variables.stepHistory,
            "compensationHistory": variables.compensationHistory,
            "createdAt": dateTimeFormat(variables.createdAt, "yyyy-mm-dd'T'HH:nn:ss.l'Z'"),
            "updatedAt": dateTimeFormat(variables.updatedAt, "yyyy-mm-dd'T'HH:nn:ss.l'Z'"),
            "completedAt": isDate(variables.completedAt) ? dateTimeFormat(variables.completedAt, "yyyy-mm-dd'T'HH:nn:ss.l'Z'") : "",
            "failureReason": variables.failureReason
        };
    }

}
