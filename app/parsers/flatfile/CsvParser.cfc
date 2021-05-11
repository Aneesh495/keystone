component extends="app.parsers.base.IParser" {

    /**
     * Constructor for CsvParser.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Parses RFC 4180 CSV text into structured records.
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var delimiter = structKeyExists(arguments.options, "delimiter") ? arguments.options.delimiter : ",";
        var hasHeaders = structKeyExists(arguments.options, "hasHeaders") ? arguments.options.hasHeaders : true;

        var rows = parseRows(arguments.rawInput, delimiter);
        if (arrayLen(rows) == 0) {
            result.setAst({"format": "CSV", "headers": [], "records": [], "recordCount": 0});
            return result;
        }

        var headers = [];
        var records = [];
        var startIdx = 1;

        if (hasHeaders) {
            headers = rows[1];
            startIdx = 2;
        } else {
            for (var c = 1; c <= arrayLen(rows[1]); c++) {
                arrayAppend(headers, "column_" & c);
            }
        }

        for (var rIdx = startIdx; rIdx <= arrayLen(rows); rIdx++) {
            var row = rows[rIdx];
            var rec = {};
            for (var hIdx = 1; hIdx <= arrayLen(headers); hIdx++) {
                var hName = headers[hIdx];
                var cellVal = (hIdx <= arrayLen(row)) ? row[hIdx] : "";
                rec[hName] = cellVal;
            }
            arrayAppend(records, rec);
        }

        var ast = {
            "format": "CSV",
            "headers": headers,
            "records": records,
            "recordCount": arrayLen(records)
        };

        result.setAst(ast);
        result.setMetadata({"recordCount": arrayLen(records), "columnCount": arrayLen(headers)});
        return result;
    }

    private array function parseRows(required string rawInput, required string delim) {
        var rows = [];
        var currentRow = [];
        var currentCell = "";
        var inQuotes = false;
        var lenInput = len(arguments.rawInput);
        var i = 1;

        while (i <= lenInput) {
            var ch = mid(arguments.rawInput, i, 1);

            if (inQuotes) {
                if (ch == '"') {
                    if (i < lenInput && mid(arguments.rawInput, i + 1, 1) == '"') {
                        // Escaped quote
                        currentCell &= '"';
                        i += 2;
                        continue;
                    } else {
                        inQuotes = false;
                    }
                } else {
                    currentCell &= ch;
                }
            } else {
                if (ch == '"') {
                    inQuotes = true;
                } else if (ch == arguments.delim) {
                    arrayAppend(currentRow, currentCell);
                    currentCell = "";
                } else if (ch == chr(10)) {
                    arrayAppend(currentRow, currentCell);
                    currentCell = "";
                    if (arrayLen(currentRow) > 0) {
                        arrayAppend(rows, currentRow);
                    }
                    currentRow = [];
                } else if (ch != chr(13)) {
                    currentCell &= ch;
                }
            }

            i++;
        }

        if (len(currentCell) > 0 || arrayLen(currentRow) > 0) {
            arrayAppend(currentRow, currentCell);
            arrayAppend(rows, currentRow);
        }

        return rows;
    }
}
