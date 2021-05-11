component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for FixedWidthSerializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes records into aligned fixed-width lines.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var schema = structKeyExists(arguments.options, "schema") ? arguments.options.schema : [];
        var records = arguments.ast.records ?: [];
        var sb = createObject("java", "java.lang.StringBuilder").init();

        for (var rec in records) {
            for (var fieldSpec in schema) {
                var fieldName = fieldSpec.name;
                var targetLen = fieldSpec.length;
                var align = structKeyExists(fieldSpec, "align") ? fieldSpec.align : "left";
                var padChar = structKeyExists(fieldSpec, "padChar") ? fieldSpec.padChar : " ";

                var rawVal = structKeyExists(rec, fieldName) ? toString(rec[fieldName]) : "";

                if (len(rawVal) > targetLen) {
                    rawVal = left(rawVal, targetLen);
                }

                while (len(rawVal) < targetLen) {
                    if (align == "right") {
                        rawVal = padChar & rawVal;
                    } else {
                        rawVal &= padChar;
                    }
                }

                sb.append(rawVal);
            }
            sb.append(chr(10));
        }

        return sb.toString();
    }
}
