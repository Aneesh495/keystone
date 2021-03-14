component {

    property name="type" type="string";
    property name="value" type="string";
    property name="line" type="numeric";
    property name="column" type="numeric";
    property name="offset" type="numeric";

    /**
     * Constructor for lexical Token.
     */
    public any function init(
        required string type,
        required string value,
        numeric line = 1,
        numeric column = 1,
        numeric offset = 0
    ) {
        variables.type = arguments.type;
        variables.value = arguments.value;
        variables.line = arguments.line;
        variables.column = arguments.column;
        variables.offset = arguments.offset;
        return this;
    }

    public string function getType() { return variables.type; }
    public string function getValue() { return variables.value; }
    public numeric function getLine() { return variables.line; }
    public numeric function getColumn() { return variables.column; }
    public numeric function getOffset() { return variables.offset; }

    public struct function toStruct() {
        return {
            "type": variables.type,
            "value": variables.value,
            "line": variables.line,
            "column": variables.column,
            "offset": variables.offset
        };
    }
}
