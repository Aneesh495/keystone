component {

    property name="success" type="boolean";
    property name="ast" type="struct";
    property name="errors" type="array";
    property name="warnings" type="array";
    property name="metadata" type="struct";

    /**
     * Constructor for ParseResult.
     */
    public any function init(
        boolean success = true,
        struct ast = {},
        array errors = [],
        array warnings = [],
        struct metadata = {}
    ) {
        variables.success = arguments.success;
        variables.ast = arguments.ast;
        variables.errors = arguments.errors;
        variables.warnings = arguments.warnings;
        variables.metadata = arguments.metadata;

        if (arrayLen(variables.errors) > 0) {
            variables.success = false;
        }

        return this;
    }

    public boolean function isSuccess() {
        return variables.success && arrayLen(variables.errors) == 0;
    }

    public boolean function hasErrors() {
        return arrayLen(variables.errors) > 0;
    }

    public boolean function hasWarnings() {
        return arrayLen(variables.warnings) > 0;
    }

    public void function addError(required string message, string code = "PARSE_ERROR", numeric line = 0, numeric column = 0, string segmentId = "") {
        variables.success = false;
        arrayAppend(variables.errors, {
            "message": arguments.message,
            "code": arguments.code,
            "line": arguments.line,
            "column": arguments.column,
            "segmentId": arguments.segmentId
        });
    }

    public void function addWarning(required string message, string code = "PARSE_WARNING", numeric line = 0, numeric column = 0) {
        arrayAppend(variables.warnings, {
            "message": arguments.message,
            "code": arguments.code,
            "line": arguments.line,
            "column": arguments.column
        });
    }

    public struct function getAst() { return variables.ast; }
    public any function getData() { return variables.ast; }
    public void function setAst(required struct ast) { variables.ast = arguments.ast; }
    public array function getErrors() { return variables.errors; }
    public array function getWarnings() { return variables.warnings; }
    public struct function getMetadata() { return variables.metadata; }
    public void function setMetadata(required struct metadata) { variables.metadata = arguments.metadata; }

    /**
     * Traverses the AST segments recursively to find all matching segment IDs.
     */
    public array function findSegments(required string segmentId) {
        var matches = [];
        if (!structKeyExists(variables.ast, "segments") || !isArray(variables.ast.segments)) {
            return matches;
        }

        for (var seg in variables.ast.segments) {
            if (structKeyExists(seg, "id") && ucase(seg.id) == ucase(arguments.segmentId)) {
                arrayAppend(matches, seg);
            }
        }

        return matches;
    }

    /**
     * Finds the first segment matching the given ID or empty struct if not found.
     */
    public struct function findFirstSegment(required string segmentId) {
        var list = findSegments(arguments.segmentId);
        return arrayLen(list) > 0 ? list[1] : {};
    }

    public string function toJson(boolean pretty = true) {
        var payload = {
            "success": isSuccess(),
            "errors": variables.errors,
            "warnings": variables.warnings,
            "metadata": variables.metadata,
            "ast": variables.ast
        };
        return serializeJson(payload);
    }
}
