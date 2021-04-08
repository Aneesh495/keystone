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
        var tokens = variables.lexer.tokenize(arguments.rawInput);

        var ast = {
            "format": "EDIFACT",
            "delimiters": delimiters,
            "interchanges": [],
            "segments": []
        };

        var currentSegment = nullValue();
        var currentInterchange = nullValue();
        var currentGroup = nullValue();
        var currentMessage = nullValue();

        var messageSegmentCount = 0;
        var tokenCount = arrayLen(tokens);

        for (var i = 1; i <= tokenCount; i++) {
            var tok = tokens[i];

            if (tok.getType() == "SEGMENT_ID") {
                currentSegment = {
                    "id": ucase(trim(tok.getValue())),
                    "line": tok.getLine(),
                    "column": tok.getColumn(),
                    "offset": tok.getOffset(),
                    "elements": []
                };
            } else if (tok.getType() == "ELEMENT") {
                if (!isNull(currentSegment)) {
                    arrayAppend(currentSegment.elements, tok.getValue());
                }
            } else if (tok.getType() == "COMPONENT") {
                if (!isNull(currentSegment) && arrayLen(currentSegment.elements) > 0) {
                    var lastIdx = arrayLen(currentSegment.elements);
                    var lastElem = currentSegment.elements[lastIdx];
                    if (isSimpleValue(lastElem)) {
                        currentSegment.elements[lastIdx] = [lastElem, tok.getValue()];
                    } else if (isArray(lastElem)) {
                        arrayAppend(lastElem, tok.getValue());
                    }
                }
            } else if (tok.getType() == "SEGMENT_END") {
                if (!isNull(currentSegment)) {
                    arrayAppend(ast.segments, currentSegment);

                    var segId = currentSegment.id;
                    var elems = currentSegment.elements;

                    // UNB Interchange Header
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
                            result.addError("Unexpected UNZ segment without preceding UNB interchange header", "UNZ_WITHOUT_UNB", currentSegment.line, currentSegment.column, "UNZ");
                        } else {
                            var expectedUnbRef = isArray(currentInterchange.controlReference) ? currentInterchange.controlReference[1] : currentInterchange.controlReference;
                            var actualUnzRef = arrayLen(elems) >= 2 ? (isArray(elems[2]) ? elems[2][1] : elems[2]) : "";

                            if (expectedUnbRef != actualUnzRef) {
                                result.addError("UNB/UNZ control reference mismatch: expected [" & expectedUnbRef & "] got [" & actualUnzRef & "]", "INTERCHANGE_REF_MISMATCH", currentSegment.line, currentSegment.column, "UNZ");
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
                            result.addError("UNT segment outside of UNH message", "UNT_WITHOUT_UNH", currentSegment.line, currentSegment.column, "UNT");
                        } else {
                            messageSegmentCount++;
                            arrayAppend(currentMessage.segments, currentSegment);

                            var declaredCount = arrayLen(elems) >= 1 ? val(elems[1]) : 0;
                            var expectedRef = currentMessage.messageReference;
                            var actualRef = arrayLen(elems) >= 2 ? (isArray(elems[2]) ? elems[2][1] : elems[2]) : "";

                            if (expectedRef != actualRef) {
                                result.addError("UNH/UNT message reference mismatch: expected [" & expectedRef & "] got [" & actualRef & "]", "MESSAGE_REF_MISMATCH", currentSegment.line, currentSegment.column, "UNT");
                            }

                            if (declaredCount > 0 && declaredCount != messageSegmentCount) {
                                result.addWarning("UNT01 segment count declared [" & declaredCount & "] differs from counted segments [" & messageSegmentCount & "]", "UNT_SEGMENT_COUNT_MISMATCH", currentSegment.line, currentSegment.column);
                            }

                            currentMessage = nullValue();
                        }
                    } else {
                        if (!isNull(currentMessage)) {
                            messageSegmentCount++;
                            arrayAppend(currentMessage.segments, currentSegment);
                        }
                    }

                    currentSegment = nullValue();
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
