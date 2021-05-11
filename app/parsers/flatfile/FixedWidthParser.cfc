component extends="app.parsers.base.IParser" {

    /**
     * Constructor for FixedWidthParser.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Parses fixed-width lines into record AST.
     *
     * @rawInput Multiline string
     * @options Struct with 'schema' array: [{ "name": "field1", "start": 1, "length": 10, "type": "string" }, ...]
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var schema = structKeyExists(arguments.options, "schema") ? arguments.options.schema : [];
        var trimFields = structKeyExists(arguments.options, "trimFields") ? arguments.options.trimFields : true;

        if (arrayLen(schema) == 0) {
            result.addError("No schema definition provided for fixed-width parsing", "NO_SCHEMA");
            return result;
        }

        var normalized = replace(arguments.rawInput, chr(13) & chr(10), chr(10), "all");
        normalized = replace(normalized, chr(13), chr(10), "all");
        var lines = listToArray(normalized, chr(10));

        var records = [];
        var lineNum = 0;

        for (var line in lines) {
            lineNum++;
            if (len(trim(line)) == 0) continue;

            var rec = {};
            for (var fieldSpec in schema) {
                var start = fieldSpec.start;
                var lenField = fieldSpec.length;
                var fieldName = fieldSpec.name;

                var rawVal = "";
                if (len(line) >= start) {
                    rawVal = mid(line, start, min(lenField, len(line) - start + 1));
                }

                if (trimFields) {
                    rawVal = trim(rawVal);
                }

                rec[fieldName] = rawVal;
            }
            arrayAppend(records, rec);
        }

        var ast = {
            "format": "FIXED_WIDTH",
            "recordCount": arrayLen(records),
            "records": records
        };

        result.setAst(ast);
        result.setMetadata({
            "recordCount": arrayLen(records)
        });

        return result;
    }
}
