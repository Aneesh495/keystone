component {

    property name="task" type="any";
    property name="logger" type="any";

    public any function init(required any task, required any logger) {
        variables.task = arguments.task;
        variables.logger = arguments.logger;
        return this;
    }

    public void function run() {
        try {
            variables.task();
        } catch (any e) {
            variables.logger.error("Worker thread task execution failed: " & e.message, {
                "detail": structKeyExists(e, "detail") ? e.detail : "",
                "type": structKeyExists(e, "type") ? e.type : "GenericException"
            });
        }
    }
}
