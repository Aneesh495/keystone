component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for HL7Serializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes an HL7 AST into standard pipe-and-hat wire format.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var fieldSep = structKeyExists(arguments.options, "fieldSeparator") ? arguments.options.fieldSeparator : "|";
        var compSep = structKeyExists(arguments.options, "componentSeparator") ? arguments.options.componentSeparator : "^";
        var repSep = structKeyExists(arguments.options, "repetitionSeparator") ? arguments.options.repetitionSeparator : "~";
        var lineTerm = structKeyExists(arguments.options, "lineTerminator") ? arguments.options.lineTerminator : chr(13);

        if (structKeyExists(arguments.ast, "delimiters") && isStruct(arguments.ast.delimiters)) {
            if (!structKeyExists(arguments.options, "fieldSeparator")) fieldSep = arguments.ast.delimiters.field ?: "|";
            if (!structKeyExists(arguments.options, "componentSeparator")) compSep = arguments.ast.delimiters.component ?: "^";
            if (!structKeyExists(arguments.options, "repetitionSeparator")) repSep = arguments.ast.delimiters.repetition ?: "~";
        }

        var sb = createObject("java", "java.lang.StringBuilder").init();
        var segments = structKeyExists(arguments.ast, "segments") ? arguments.ast.segments : [];

        for (var seg in segments) {
            var segId = seg.id;
            var elems = seg.elements ?: [];
            sb.append(segId);

            if (segId == "MSH") {
                // MSH special formatting: MSH|^~\&|...
                // elems[1] is field separator, elems[2] is encoding characters
                var encChars = (arrayLen(elems) >= 2) ? toString(elems[2]) : "^~\&";
                sb.append(fieldSep);
                sb.append(encChars);

                for (var e = 3; e <= arrayLen(elems); e++) {
                    sb.append(fieldSep);
                    sb.append(formatField(elems[e], compSep, repSep));
                }
            } else {
                for (var e = 1; e <= arrayLen(elems); e++) {
                    sb.append(fieldSep);
                    sb.append(formatField(elems[e], compSep, repSep));
                }
            }

            sb.append(lineTerm);
        }

        return sb.toString();
    }

    private string function formatField(required any val, required string compSep, required string repSep) {
        if (isArray(arguments.val)) {
            // Check if array of repetitions or array of components
            var parts = [];
            for (var item in arguments.val) {
                if (isArray(item)) {
                    // Sub-components joined by compSep
                    arrayAppend(parts, arrayToList(item, arguments.compSep));
                } else {
                    arrayAppend(parts, toString(item));
                }
            }
            return arrayToList(parts, arguments.compSep);
        }
        return toString(arguments.val);
    }
}
