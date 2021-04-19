component extends="app.parsers.base.IParser" {

    property name="lexer" type="any";

    /**
     * Constructor for EdifactParser.
     */
    public any function init(any lexer = nullValue()) {
        super.init();
        variables.lexer = isNull(arguments.lexer) ? new app.parsers.edifact.EdifactLexer() : arguments.lexer;
        return this;
    }

    public boolean function canParse(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        return left(trimmed, 3) == "UNA" || left(trimmed, 3) == "UNB";
    }

    /**
     * Parses raw EDIFACT message into hierarchical AST.
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var delimiters = variables.lexer.detectDelimiters(arguments.rawInput);
        var rawSegments = variables.lexer.splitSegments(arguments.rawInput);

        var ast = {
            "format": "EDIFACT",
            "delimiters": delimiters,
            "interchanges": [],
            "segments": []
        };

        var currentInterchange = nullValue();
        var currentGroup = nullValue();
        var currentMessage = nullValue();
        var messageSegmentCount = 0;

        for (var sIdx = 1; sIdx <= arrayLen(rawSegments); sIdx++) {
            var rawSegText = rawSegments[sIdx];
            var rawParts = variables.lexer.splitTokens(rawSegText, delimiters.element);
            if (arrayLen(rawParts) == 0) continue;

            var segId = ucase(trim(rawParts[1]));
            var elems = [];

            // Process data elements
            for (var p = 2; p <= arrayLen(rawParts); p++) {
                var elemPart = rawParts[p];
                var comps = variables.lexer.splitTokens(elemPart, delimiters.component);
                if (arrayLen(comps) > 1) {
                    var unescapedComps = [];
                    for (var c in comps) {
                        arrayAppend(unescapedComps, variables.lexer.unescape(c));
                    }
                    arrayAppend(elems, unescapedComps);
                } else {
                    arrayAppend(elems, variables.lexer.unescape(elemPart));
                }
            }

            var currentSegment = {
                "id": segId,
                "line": sIdx,
                "column": 1,
                "elements": elems
            };
            arrayAppend(ast.segments, currentSegment);

            // Hierarchy tracking
            if (segId == "UNB") {
                currentInterchange = {
                    "syntaxIdentifier": arrayLen(elems) >= 1 ? elems[1] : "",
                    "sender": arrayLen(elems) >= 2 ? elems[2] : "",
                    "recipient": arrayLen(elems) >= 3 ? elems[3] : "",
                    "dateTime": arrayLen(elems) >= 4 ? elems[4] : "",
                    "controlReference": arrayLen(elems) >= 5 ? elems[5] : "",
                    "recipientsRefPassword": arrayLen(elems) >= 6 ? elems[6] : "",
                    "applicationRef": arrayLen(elems) >= 7 ? elems[7] : "",
                    "messages": [],
                    "groups": []
                };
                arrayAppend(ast.interchanges, currentInterchange);
            } else if (segId == "UNZ") {
                if (isNull(currentInterchange)) {
                    result.addError("Unexpected UNZ segment without preceding UNB interchange header", "UNZ_WITHOUT_UNB", sIdx, 1, "UNZ");
                } else {
                    var expectedUnbRef = isArray(currentInterchange.controlReference) ? currentInterchange.controlReference[1] : currentInterchange.controlReference;
                    var actualUnzRef = arrayLen(elems) >= 2 ? (isArray(elems[2]) ? elems[2][1] : elems[2]) : "";

                    if (expectedUnbRef != actualUnzRef) {
                        result.addError("UNB/UNZ control reference mismatch: expected [" & expectedUnbRef & "] got [" & actualUnzRef & "]", "INTERCHANGE_REF_MISMATCH", sIdx, 1, "UNZ");
                    }
                }
            } else if (segId == "UNH") {
                messageSegmentCount = 1;
                var msgRef = arrayLen(elems) >= 1 ? (isArray(elems[1]) ? elems[1][1] : elems[1]) : "";
                var msgIdDetails = arrayLen(elems) >= 2 ? elems[2] : [];

                var msgType = "";
                var msgVersion = "";
                var msgRelease = "";
                var msgAgency = "";

                if (isArray(msgIdDetails)) {
                    if (arrayLen(msgIdDetails) >= 1) msgType = msgIdDetails[1];
                    if (arrayLen(msgIdDetails) >= 2) msgVersion = msgIdDetails[2];
                    if (arrayLen(msgIdDetails) >= 3) msgRelease = msgIdDetails[3];
                    if (arrayLen(msgIdDetails) >= 4) msgAgency = msgIdDetails[4];
                } else {
                    msgType = toString(msgIdDetails);
                }

                currentMessage = {
                    "messageReference": msgRef,
                    "type": msgType,
                    "version": msgVersion,
                    "release": msgRelease,
                    "agency": msgAgency,
                    "segments": [currentSegment]
                };

                if (!isNull(currentInterchange)) {
                    arrayAppend(currentInterchange.messages, currentMessage);
                }
            } else if (segId == "UNT") {
                if (isNull(currentMessage)) {
                    result.addError("UNT segment outside of UNH message", "UNT_WITHOUT_UNH", sIdx, 1, "UNT");
                } else {
                    messageSegmentCount++;
                    arrayAppend(currentMessage.segments, currentSegment);

                    var declaredCount = arrayLen(elems) >= 1 ? val(elems[1]) : 0;
                    var expectedRef = currentMessage.messageReference;
                    var actualRef = arrayLen(elems) >= 2 ? (isArray(elems[2]) ? elems[2][1] : elems[2]) : "";

                    if (expectedRef != actualRef) {
                        result.addError("UNH/UNT message reference mismatch: expected [" & expectedRef & "] got [" & actualRef & "]", "MESSAGE_REF_MISMATCH", sIdx, 1, "UNT");
                    }

                    if (declaredCount > 0 && declaredCount != messageSegmentCount) {
                        result.addWarning("UNT01 segment count declared [" & declaredCount & "] differs from counted segments [" & messageSegmentCount & "]", "UNT_SEGMENT_COUNT_MISMATCH", sIdx, 1);
                    }

                    currentMessage = nullValue();
                }
            } else {
                if (!isNull(currentMessage)) {
                    messageSegmentCount++;
                    arrayAppend(currentMessage.segments, currentSegment);
                }
            }
        }

        result.setAst(ast);
        result.setMetadata({
            "segmentCount": arrayLen(ast.segments),
            "interchangeCount": arrayLen(ast.interchanges),
            "delimiters": delimiters
        });

        return result;
    }
}
