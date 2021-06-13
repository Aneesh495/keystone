/**
 * Keystone B2B Transaction Mesh - Saga Definition
 *
 * Defines the declarative multi-step execution graph for distributed transaction workflows,
 * supporting forward chaining and compensation rollback strategies.
 */
component {

    property name="sagaName" type="string";
    property name="description" type="string";
    property name="steps" type="array";
    property name="compensationStrategy" type="string";

    /**
     * Initializes a new SagaDefinition.
     *
     * @sagaName Unique identifier for this workflow pattern
     * @description Human-readable documentation of the business transaction
     * @compensationStrategy Rollback ordering strategy (BACKWARD_CHAIN default)
     */
    public any function init(
        required string sagaName,
        string description = "",
        string compensationStrategy = "BACKWARD_CHAIN"
    ) {
        variables.sagaName = arguments.sagaName;
        variables.description = arguments.description;
        variables.compensationStrategy = arguments.compensationStrategy;
        variables.steps = [];

        return this;
    }

    public string function getName() {
        return variables.sagaName;
    }

    public string function getDescription() {
        return variables.description;
    }

    public string function getCompensationStrategy() {
        return variables.compensationStrategy;
    }

    public array function getSteps() {
        return variables.steps;
    }

    public numeric function getStepCount() {
        return arrayLen(variables.steps);
    }

    /**
     * Appends a step to the saga sequence.
     */
    public any function addStep(
        required any stepOrName,
        any forwardAction = "",
        any compensationAction = "",
        numeric timeoutMs = 30000,
        numeric retryLimit = 3,
        numeric retryDelayMs = 500
    ) {
        if (isObject(arguments.stepOrName)) {
            arrayAppend(variables.steps, arguments.stepOrName);
        } else {
            var step = new app.transactions.SagaStep(
                stepName = arguments.stepOrName,
                forwardAction = arguments.forwardAction,
                compensationAction = arguments.compensationAction,
                timeoutMs = arguments.timeoutMs,
                retryLimit = arguments.retryLimit,
                retryDelayMs = arguments.retryDelayMs
            );
            arrayAppend(variables.steps, step);
        }

        return this;
    }

    /**
     * Retrieves a step definition by its name.
     */
    public any function getStep(required string stepName) {
        for (var step in variables.steps) {
            if (step.getName() == arguments.stepName) {
                return step;
            }
        }
        throw(type="SagaStepNotFoundException", message="Step [#arguments.stepName#] not found in saga [#variables.sagaName#]");
    }

    /**
     * Returns true if a step with the specified name exists.
     */
    public boolean function hasStep(required string stepName) {
        for (var step in variables.steps) {
            if (step.getName() == arguments.stepName) {
                return true;
            }
        }
        return false;
    }

}
