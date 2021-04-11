component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for EdifactSerializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes an EDIFACT AST into standard UN/EDIFACT wire format.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var compSep = structKeyExists(arguments.options, "componentSeparator") ? arguments.options.componentSeparator : ":";
        var elemSep = structKeyExists(arguments.options, "elementSeparator") ? arguments.options.elementSeparator : "+";
        var decPoint = structKeyExists(arguments.options, "decimalPoint") ? arguments.options.decimalPoint : ".";
        var relChar = structKeyExists(arguments.options, "releaseCharacter") ? arguments.options.releaseCharacter : "?";
        var repSep = structKeyExists(arguments.options, "repetitionSeparator") ? arguments.options.repetitionSeparator : "*";
        var segTerm = structKeyExists(arguments.options, "segmentTerminator") ? arguments.options.segmentTerminator : "'";
        var emitUna = structKeyExists(arguments.options, "emitUna") ? arguments.options.emitUna : false;
        var addNewline = structKeyExists(arguments.options, "newlineAfterSegment") ? arguments.options.newlineAfterSegment : true;

        if (structKeyExists(arguments.ast, "delimiters") && isStruct(arguments.ast.delimiters)) {
            if (!structKeyExists(arguments.options, "componentSeparator")) compSep = arguments.ast.delimiters.component ?: ":";
            if (!structKeyExists(arguments.options, "elementSeparator")) elemSep = arguments.ast.delimiters.element ?: "+";
            if (!structKeyExists(arguments.options, "decimalPoint")) decPoint = arguments.ast.delimiters.decimal ?: ".";
            if (!structKeyExists(arguments.options, "releaseCharacter")) relChar = arguments.ast.delimiters.release ?: "?";
            if (!structKeyExists(arguments.options, "repetitionSeparator")) repSep = arguments.ast.delimiters.repetition ?: "*";
            if (!structKeyExists(arguments.options, "segmentTerminator")) segTerm = arguments.ast.delimiters.segment ?: "'";
            if (!structKeyExists(arguments.options, "emitUna")) emitUna = arguments.ast.delimiters.hasUna ?: false;
        }

        var sb = createObject("java", "java.lang.StringBuilder").init();
        var nl = addNewline ? chr(10) : "";

        // Emit UNA service string advice if required
        if (emitUna) {
            sb.append("UNA").append(compSep).append(elemSep).append(decPoint).append(relChar).append(repSep).append(segTerm).append(nl);
        }

        // Flat segments array serialization
        if (structKeyExists(arguments.ast, "segments") && isArray(arguments.ast.segments) && arrayLen(arguments.ast.segments) > 0) {
            for (var seg in arguments.ast.segments) {
                var lineStr = formatSegment(seg, elemSep, compSep, relChar, segTerm);
                sb.append(lineStr);
                sb.append(segTerm);
                sb.append(nl);
            }
            return sb.toString();
        }

        return "";
    }

    private string function formatSegment(required struct seg, required string elemSep, required string compSep, required string relChar, required string segTerm) {
        var sb = createObject("java", "java.lang.StringBuilder").init(arguments.seg.id);
        if (structKeyExists(arguments.seg, "elements") && isArray(arguments.seg.elements)) {
            for (var elem in arguments.seg.elements) {
                sb.append(arguments.elemSep);
                if (isArray(elem)) {
                    var compSb = createObject("java", "java.lang.StringBuilder").init();
                    for (var cIdx = 1; cIdx <= arrayLen(elem); cIdx++) {
                        if (cIdx > 1) compSb.append(arguments.compSep);
                        var rawComp = toString(elem[cIdx]);
                        compSb.append(escapeEdifact(rawComp, arguments.elemSep, arguments.compSep, arguments.relChar, arguments.segTerm));
                    }
                    sb.append(compSb.toString());
                } else {
                    var rawElem = toString(elem);
                    sb.append(escapeEdifact(rawElem, arguments.elemSep, arguments.compSep, arguments.relChar, arguments.segTerm));
                }
            }
        }
        return sb.toString();
    }

    private string function escapeEdifact(required string text, required string elemSep, required string compSep, required string relChar, required string segTerm) {
        var res = arguments.text;
        // Escape release character first
        res = replace(res, arguments.relChar, arguments.relChar & arguments.relChar, "all");
        // Escape separators
        res = replace(res, arguments.elemSep, arguments.relChar & arguments.elemSep, "all");
        res = replace(res, arguments.compSep, arguments.relChar & arguments.compSep, "all");
        res = replace(res, arguments.segTerm, arguments.relChar & arguments.segTerm, "all");
        return res;
    }
}
