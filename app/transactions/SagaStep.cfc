/**
 * Keystone B2B Transaction Mesh - Saga Step Definition
 *
 * Encapsulates an individual forward action and its matching backward compensation action
 * within a distributed saga transaction workflow.
 */
component {

    property name="stepName" type="string";
    property name="forwardAction" type="any";
    property name="compensationAction" type="any";
    property name="timeoutMs" type="numeric";
    property name="retryLimit" type="numeric";
    property name="retryDelayMs" type="numeric";

    /**
     * Initializes a new SagaStep with forward and compensation execution logic.
     *
     * @stepName Unique identifier for this step within the saga
     * @forwardAction Callable closure or method executing the forward transaction
     * @compensationAction Callable closure or method executing compensation upon rollback
     * @timeoutMs Timeout limit in milliseconds
     * @retryLimit Maximum retry attempts on transient forward failure
     * @retryDelayMs Base delay in milliseconds between retries
     */
    public any function init(
        required string stepName,
        required any forwardAction,
        any compensationAction = "",
        numeric timeoutMs = 30000,
        numeric retryLimit = 3,
        numeric retryDelayMs = 500
    ) {
        variables.stepName = arguments.stepName;
        variables.forwardAction = arguments.forwardAction;
        variables.compensationAction = arguments.compensationAction;
        variables.timeoutMs = arguments.timeoutMs;
        variables.retryLimit = arguments.retryLimit;
        variables.retryDelayMs = arguments.retryDelayMs;

        return this;
    }

    public string function getName() {
        return variables.stepName;
    }

    public any function getForwardAction() {
        return variables.forwardAction;
    }

    public any function getCompensationAction() {
        return variables.compensationAction;
    }

    public numeric function getTimeoutMs() {
        return variables.timeoutMs;
    }

    public numeric function getRetryLimit() {
        return variables.retryLimit;
    }

    public numeric function getRetryDelayMs() {
        return variables.retryDelayMs;
    }

    public boolean function hasCompensation() {
        return !isSimpleValue(variables.compensationAction) || len(trim(variables.compensationAction)) > 0;
    }

    /**
     * Executes the forward action with the provided shared saga context.
     */
    public struct function executeForward(required struct context) {
        var result = {};
        if (isCustomFunction(variables.forwardAction) || isClosure(variables.forwardAction)) {
            var fn = variables.forwardAction;
            var output = fn(arguments.context);
            if (isStruct(output)) {
                return output;
            }
            return { "success": true, "result": output };
        } else if (isObject(variables.forwardAction)) {
            if (structKeyExists(variables.forwardAction, "execute")) {
                return variables.forwardAction.execute(arguments.context);
            }
        }
        return { "success": true, "result": "NOOP" };
    }

    /**
     * Executes the compensation action with the provided shared saga context.
     */
    public struct function executeCompensation(required struct context) {
        if (!hasCompensation()) {
            return { "success": true, "compensated": false, "reason": "No compensation defined" };
        }

        if (isCustomFunction(variables.compensationAction) || isClosure(variables.compensationAction)) {
            var fn = variables.compensationAction;
            var output = fn(arguments.context);
            if (isStruct(output)) {
                return output;
            }
            return { "success": true, "compensated": true, "result": output };
        } else if (isObject(variables.compensationAction)) {
            if (structKeyExists(variables.compensationAction, "compensate")) {
                return variables.compensationAction.compensate(arguments.context);
            }
        }
        return { "success": true, "compensated": true };
    }

}
