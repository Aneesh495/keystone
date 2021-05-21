component {

    property name="sourceData" type="struct";
    property name="targetData" type="struct";
    property name="variablesScope" type="struct";
    property name="errors" type="array";

    /**
     * Constructor for MappingContext.
     */
    public any function init(struct sourceData = {}) {
        variables.sourceData = arguments.sourceData;
        variables.targetData = {};
        variables.variablesScope = {};
        variables.errors = [];
        return this;
    }

    public struct function getSourceData() { return variables.sourceData; }
    public struct function getTargetData() { return variables.targetData; }

    public void function setVar(required string name, required any value) {
        variables.variablesScope[arguments.name] = arguments.value;
    }

    public any function getVar(required string name, any defaultValue = "") {
        return structKeyExists(variables.variablesScope, arguments.name) ? variables.variablesScope[arguments.name] : arguments.defaultValue;
    }

    /**
     * Sets a value in the targetData structure using dot-notation.
     * E.g. setTarget("header.poNumber", "12345")
     */
    public void function setTarget(required string path, required any value) {
        var parts = listToArray(arguments.path, ".");
        var curr = variables.targetData;

        for (var i = 1; i < arrayLen(parts); i++) {
            var part = parts[i];
            if (!structKeyExists(curr, part) || !isStruct(curr[part])) {
                curr[part] = {};
            }
            curr = curr[part];
        }

        curr[parts[arrayLen(parts)]] = arguments.value;
    }

    /**
     * Appends an item to a target array at dot-notation path.
     */
    public void function appendTargetArray(required string path, required any item) {
        var parts = listToArray(arguments.path, ".");
        var curr = variables.targetData;

        for (var i = 1; i < arrayLen(parts); i++) {
            var part = parts[i];
            if (!structKeyExists(curr, part) || !isStruct(curr[part])) {
                curr[part] = {};
            }
            curr = curr[part];
        }

        var arrayField = parts[arrayLen(parts)];
        if (!structKeyExists(curr, arrayField) || !isArray(curr[arrayField])) {
            curr[arrayField] = [];
        }

        arrayAppend(curr[arrayField], arguments.item);
    }

    public void function addError(required string message) {
        arrayAppend(variables.errors, arguments.message);
    }

    public array function getErrors() { return variables.errors; }
}
