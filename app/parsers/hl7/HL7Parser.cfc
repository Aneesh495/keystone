component extends="app.parsers.base.IParser" {

    property name="lexer" type="any";

    /**
     * Constructor for HL7Parser.
     */
    public any function init(any lexer = nullValue()) {
        super.init();
        variables.lexer = isNull(arguments.lexer) ? new app.parsers.hl7.HL7Lexer() : arguments.lexer;
        return this;
    }

    public boolean function canParse(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        return left(trimmed, 3) == "MSH";
    }

    /**
     * Parses raw HL7 v2 message into AST.
     */
    public any function parse(required string rawInput, struct options = {}) {
        var result = new app.parsers.base.ParseResult();
        var delimiters = variables.lexer.detectDelimiters(arguments.rawInput);
        var rawSegments = variables.lexer.splitSegments(arguments.rawInput);

        var ast = {
            "format": "HL7",
            "version": "2.5.1",
            "delimiters": delimiters,
            "header": {},
            "segments": []
        };

        if (arrayLen(rawSegments) == 0) {
            result.addError("Empty HL7 message payload", "EMPTY_HL7_PAYLOAD");
            result.setAst(ast);
            return result;
        }

        var segIdx = 0;
        for (var rawLine in rawSegments) {
            segIdx++;
            var isMsh = (left(rawLine, 3) == "MSH");
            var segId = ucase(left(rawLine, 3));
            var rawFields = variables.lexer.splitFields(rawLine);
            var parsedFields = [];

            for (var fIdx = 1; fIdx <= arrayLen(rawFields); fIdx++) {
                var fVal = rawFields[fIdx];
                if (isMsh && fIdx == 1) {
                    // MSH-1 is literal field separator
                    arrayAppend(parsedFields, fVal);
                } else if (isMsh && fIdx == 2) {
                    // MSH-2 is literal encoding characters
                    arrayAppend(parsedFields, fVal);
                } else {
                    // Check for repetition
                    var reps = variables.lexer.splitRepetitions(fVal);
                    if (arrayLen(reps) > 1) {
                        var repList = [];
                        for (var r in reps) {
                            var rComps = variables.lexer.splitComponents(r);
                            arrayAppend(repList, arrayLen(rComps) > 1 ? rComps : r);
                        }
                        arrayAppend(parsedFields, repList);
                    } else {
                        var comps = variables.lexer.splitComponents(fVal);
                        arrayAppend(parsedFields, arrayLen(comps) > 1 ? comps : fVal);
                    }
                }
            }

            var segStruct = {
                "id": segId,
                "line": segIdx,
                "elements": parsedFields
            };
            arrayAppend(ast.segments, segStruct);

            // Populate header from MSH
            if (segId == "MSH") {
                var mshFields = parsedFields;
                var msgTypeField = arrayLen(mshFields) >= 9 ? mshFields[9] : "";
                var mType = isArray(msgTypeField) ? (arrayLen(msgTypeField) >= 1 ? msgTypeField[1] : "") : toString(msgTypeField);
                var mTrigger = isArray(msgTypeField) ? (arrayLen(msgTypeField) >= 2 ? msgTypeField[2] : "") : "";
                var mStruct = isArray(msgTypeField) ? (arrayLen(msgTypeField) >= 3 ? msgTypeField[3] : "") : "";

                ast.header = {
                    "fieldSeparator": arrayLen(mshFields) >= 1 ? mshFields[1] : "|",
                    "encodingCharacters": arrayLen(mshFields) >= 2 ? mshFields[2] : "^~\&",
                    "sendingApplication": arrayLen(mshFields) >= 3 ? mshFields[3] : "",
                    "sendingFacility": arrayLen(mshFields) >= 4 ? mshFields[4] : "",
                    "receivingApplication": arrayLen(mshFields) >= 5 ? mshFields[5] : "",
                    "receivingFacility": arrayLen(mshFields) >= 6 ? mshFields[6] : "",
                    "dateTime": arrayLen(mshFields) >= 7 ? mshFields[7] : "",
                    "security": arrayLen(mshFields) >= 8 ? mshFields[8] : "",
                    "messageType": mType,
                    "triggerEvent": mTrigger,
                    "messageStructure": mStruct,
                    "controlId": arrayLen(mshFields) >= 10 ? mshFields[10] : "",
                    "processingId": arrayLen(mshFields) >= 11 ? mshFields[11] : "P",
                    "versionId": arrayLen(mshFields) >= 12 ? mshFields[12] : "2.5.1"
                };
                ast.version = ast.header.versionId;
            }
        }

        result.setAst(ast);
        result.setMetadata({
            "segmentCount": arrayLen(ast.segments),
            "messageType": ast.header.messageType ?: "",
            "triggerEvent": ast.header.triggerEvent ?: "",
            "controlId": ast.header.controlId ?: ""
        });

        return result;
    }
}
