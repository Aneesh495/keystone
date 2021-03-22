component extends="app.parsers.base.IParser" {

    property name="lexer" type="any";

    /**
     * Constructor for X12Parser.
     */
    public any function init(any lexer = nullValue()) {
        super.init();
        variables.lexer = isNull(arguments.lexer) ? new app.parsers.x12.X12Lexer() : arguments.lexer;
        return this;
    }

    public boolean function canParse(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        return left(trimmed, 3) == "ISA";
    }

    /**
     * Parses raw X12 wire format into hierarchical AST.
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var delimiters = variables.lexer.detectDelimiters(arguments.rawInput);
        var tokens = variables.lexer.tokenize(arguments.rawInput);

        var ast = {
            "format": "X12",
            "delimiters": delimiters,
            "interchanges": [],
            "segments": []
        };

        var currentSegment = nullValue();
        var currentInterchange = nullValue();
        var currentGroup = nullValue();
        var currentTransaction = nullValue();

        var segmentCountInTx = 0;
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
                    var lastElemIdx = arrayLen(currentSegment.elements);
                    var lastElem = currentSegment.elements[lastElemIdx];
                    if (isSimpleValue(lastElem)) {
                        currentSegment.elements[lastElemIdx] = [lastElem, tok.getValue()];
                    } else if (isArray(lastElem)) {
                        arrayAppend(lastElem, tok.getValue());
                    }
                }
            } else if (tok.getType() == "REPETITION") {
                if (!isNull(currentSegment) && arrayLen(currentSegment.elements) > 0) {
                    var lastElemIdx = arrayLen(currentSegment.elements);
                    var lastElem = currentSegment.elements[lastElemIdx];
                    if (isSimpleValue(lastElem)) {
                        currentSegment.elements[lastElemIdx] = [lastElem, tok.getValue()];
                    } else if (isArray(lastElem)) {
                        arrayAppend(lastElem, tok.getValue());
                    }
                }
            } else if (tok.getType() == "SEGMENT_END") {
                if (!isNull(currentSegment)) {
                    // Record flat segment
                    arrayAppend(ast.segments, currentSegment);

                    var segId = currentSegment.id;
                    var elems = currentSegment.elements;

                    // Envelope state machine
                    if (segId == "ISA") {
                        currentInterchange = {
                            "authorizationInfoQual": arrayLen(elems) >= 1 ? elems[1] : "",
                            "authorizationInfo": arrayLen(elems) >= 2 ? elems[2] : "",
                            "securityInfoQual": arrayLen(elems) >= 3 ? elems[3] : "",
                            "securityInfo": arrayLen(elems) >= 4 ? elems[4] : "",
                            "senderQualifier": arrayLen(elems) >= 5 ? elems[5] : "",
                            "senderId": arrayLen(elems) >= 6 ? trim(elems[6]) : "",
                            "receiverQualifier": arrayLen(elems) >= 7 ? elems[7] : "",
                            "receiverId": arrayLen(elems) >= 8 ? trim(elems[8]) : "",
                            "date": arrayLen(elems) >= 9 ? elems[9] : "",
                            "time": arrayLen(elems) >= 10 ? elems[10] : "",
                            "repetitionSeparator": arrayLen(elems) >= 11 ? elems[11] : "",
                            "version": arrayLen(elems) >= 12 ? elems[12] : "",
                            "controlNumber": arrayLen(elems) >= 13 ? elems[13] : "",
                            "ackRequested": arrayLen(elems) >= 14 ? elems[14] : "",
                            "usageIndicator": arrayLen(elems) >= 15 ? elems[15] : "",
                            "componentSeparator": arrayLen(elems) >= 16 ? elems[16] : "",
                            "groups": []
                        };
                        arrayAppend(ast.interchanges, currentInterchange);
                    } else if (segId == "IEA") {
                        if (isNull(currentInterchange)) {
                            result.addError("Unexpected IEA segment without preceding ISA envelope", "IEA_WITHOUT_ISA", currentSegment.line, currentSegment.column, "IEA");
                        } else {
                            var expectedCtl = currentInterchange.controlNumber;
                            var actualCtl = arrayLen(elems) >= 2 ? elems[2] : "";
                            if (expectedCtl != actualCtl) {
                                result.addError("ISA/IEA control number mismatch: expected [" & expectedCtl & "] got [" & actualCtl & "]", "INTERCHANGE_CONTROL_MISMATCH", currentSegment.line, currentSegment.column, "IEA");
                            }
                        }
                    } else if (segId == "GS") {
                        if (isNull(currentInterchange)) {
                            result.addError("GS segment outside of ISA envelope", "GS_WITHOUT_ISA", currentSegment.line, currentSegment.column, "GS");
                        } else {
                            currentGroup = {
                                "functionalCode": arrayLen(elems) >= 1 ? elems[1] : "",
                                "senderId": arrayLen(elems) >= 2 ? elems[2] : "",
                                "receiverId": arrayLen(elems) >= 3 ? elems[3] : "",
                                "date": arrayLen(elems) >= 4 ? elems[4] : "",
                                "time": arrayLen(elems) >= 5 ? elems[5] : "",
                                "controlNumber": arrayLen(elems) >= 6 ? elems[6] : "",
                                "agencyCode": arrayLen(elems) >= 7 ? elems[7] : "",
                                "version": arrayLen(elems) >= 8 ? elems[8] : "",
                                "transactionSets": []
                            };
                            arrayAppend(currentInterchange.groups, currentGroup);
                        }
                    } else if (segId == "GE") {
                        if (isNull(currentGroup)) {
                            result.addError("GE segment outside of GS functional group", "GE_WITHOUT_GS", currentSegment.line, currentSegment.column, "GE");
                        } else {
                            var expectedGsCtl = currentGroup.controlNumber;
                            var actualGsCtl = arrayLen(elems) >= 2 ? elems[2] : "";
                            if (expectedGsCtl != actualGsCtl) {
                                result.addError("GS/GE control number mismatch: expected [" & expectedGsCtl & "] got [" & actualGsCtl & "]", "GROUP_CONTROL_MISMATCH", currentSegment.line, currentSegment.column, "GE");
                            }
                        }
                    } else if (segId == "ST") {
                        if (isNull(currentGroup)) {
                            result.addError("ST segment outside of GS functional group", "ST_WITHOUT_GS", currentSegment.line, currentSegment.column, "ST");
                        } else {
                            segmentCountInTx = 1;
                            currentTransaction = {
                                "transactionCode": arrayLen(elems) >= 1 ? elems[1] : "",
                                "controlNumber": arrayLen(elems) >= 2 ? elems[2] : "",
                                "implementationRef": arrayLen(elems) >= 3 ? elems[3] : "",
                                "segments": [currentSegment]
                            };
                            arrayAppend(currentGroup.transactionSets, currentTransaction);
                        }
                    } else if (segId == "SE") {
                        if (isNull(currentTransaction)) {
                            result.addError("SE segment outside of ST transaction set", "SE_WITHOUT_ST", currentSegment.line, currentSegment.column, "SE");
                        } else {
                            segmentCountInTx++;
                            arrayAppend(currentTransaction.segments, currentSegment);

                            var declaredCount = arrayLen(elems) >= 1 ? val(elems[1]) : 0;
                            var expectedStCtl = currentTransaction.controlNumber;
                            var actualStCtl = arrayLen(elems) >= 2 ? elems[2] : "";

                            if (expectedStCtl != actualStCtl) {
                                result.addError("ST/SE control number mismatch: expected [" & expectedStCtl & "] got [" & actualStCtl & "]", "TX_CONTROL_MISMATCH", currentSegment.line, currentSegment.column, "SE");
                            }

                            if (declaredCount > 0 && declaredCount != segmentCountInTx) {
                                result.addWarning("SE01 segment count declared [" & declaredCount & "] differs from counted segments [" & segmentCountInTx & "]", "TX_SEGMENT_COUNT_MISMATCH", currentSegment.line, currentSegment.column);
                            }

                            currentTransaction = nullValue();
                        }
                    } else {
                        // Standard body segment within transaction
                        if (!isNull(currentTransaction)) {
                            segmentCountInTx++;
                            arrayAppend(currentTransaction.segments, currentSegment);
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
