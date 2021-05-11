component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for CsvSerializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes CSV AST or records into standard RFC 4180 CSV string.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var delim = structKeyExists(arguments.options, "delimiter") ? arguments.options.delimiter : ",";
        var headers = structKeyExists(arguments.ast, "headers") ? arguments.ast.headers : [];
        var records = structKeyExists(arguments.ast, "records") ? arguments.ast.records : [];

        var sb = createObject("java", "java.lang.StringBuilder").init();

        // Write header row
        for (var hIdx = 1; hIdx <= arrayLen(headers); hIdx++) {
            if (hIdx > 1) sb.append(delim);
            sb.append(escapeCell(headers[hIdx], delim));
        }
        sb.append(chr(10));

        // Write data rows
        for (var rec in records) {
            for (var hIdx = 1; hIdx <= arrayLen(headers); hIdx++) {
                if (hIdx > 1) sb.append(delim);
                var hName = headers[hIdx];
                var cellVal = structKeyExists(rec, hName) ? toString(rec[hName]) : "";
                sb.append(escapeCell(cellVal, delim));
            }
            sb.append(chr(10));
        }

        return sb.toString();
    }

    private string function escapeCell(required string text, required string delim) {
        var needsQuotes = (find(arguments.delim, arguments.text) > 0 || find('"', arguments.text) > 0 || find(chr(10), arguments.text) > 0);
        if (needsQuotes) {
            var escaped = replace(arguments.text, '"', '""', "all");
            return '"' & escaped & '"';
        }
        return arguments.text;
    }
}
