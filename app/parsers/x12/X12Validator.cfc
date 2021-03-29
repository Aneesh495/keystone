component {

    /**
     * Constructor for X12Validator.
     */
    public any function init() {
        return this;
    }

    /**
     * Validates an X12 AST or ParseResult against standard rules or transaction schema.
     *
     * @parseResult app.parsers.base.ParseResult instance
     * @schema Optional transaction schema definition component
     * @return Array of validation error structs
     */
    public array function validate(required any parseResult, any schema = nullValue()) {
        var errors = [];
        var ast = arguments.parseResult.getAst();

        if (!structKeyExists(ast, "segments") || !isArray(ast.segments)) {
            arrayAppend(errors, {
                "code": "MISSING_SEGMENTS",
                "message": "AST contains no valid segments",
                "segmentId": "",
                "position": 0
            });
            return errors;
        }

        var segments = ast.segments;
        var totalSegments = arrayLen(segments);

        // Rule 1: Interchange envelope integrity
        if (totalSegments > 0) {
            if (segments[1].id != "ISA") {
                arrayAppend(errors, {
                    "code": "FIRST_SEGMENT_NOT_ISA",
                    "message": "First segment in X12 stream must be ISA, found [" & segments[1].id & "]",
                    "segmentId": segments[1].id,
                    "position": 1
                });
            }

            if (segments[totalSegments].id != "IEA") {
                arrayAppend(errors, {
                    "code": "LAST_SEGMENT_NOT_IEA",
                    "message": "Final segment in X12 stream must be IEA, found [" & segments[totalSegments].id & "]",
                    "segmentId": segments[totalSegments].id,
                    "position": totalSegments
                });
            }
        }

        // Rule 2: Segment validation against schema if provided
        if (!isNull(arguments.schema)) {
            var schemaDef = arguments.schema.getDefinition();
            var segIndex = 0;

            for (var seg in segments) {
                segIndex++;
                var segId = seg.id;

                if (structKeyExists(schemaDef.segments, segId)) {
                    var segSpec = schemaDef.segments[segId];
                    var elemCount = arrayLen(seg.elements);

                    // Check element specifications
                    for (var eIdx = 1; eIdx <= arrayLen(segSpec.elements); eIdx++) {
                        var elemSpec = segSpec.elements[eIdx];
                        var isPresent = (eIdx <= elemCount) && len(trim(toString(seg.elements[eIdx])));
                        var elemVal = isPresent ? toString(seg.elements[eIdx]) : "";

                        // Mandatory check
                        if (elemSpec.usage == "M" && !isPresent) {
                            arrayAppend(errors, {
                                "code": "MANDATORY_ELEMENT_MISSING",
                                "message": "Mandatory element " & segId & padNumber(eIdx) & " is missing",
                                "segmentId": segId,
                                "elementIndex": eIdx,
                                "position": segIndex
                            });
                            continue;
                        }

                        if (isPresent) {
                            var valLen = len(elemVal);

                            // Min length check
                            if (structKeyExists(elemSpec, "min") && valLen < elemSpec.min) {
                                arrayAppend(errors, {
                                    "code": "ELEMENT_TOO_SHORT",
                                    "message": "Element " & segId & padNumber(eIdx) & " length [" & valLen & "] is shorter than minimum [" & elemSpec.min & "]",
                                    "segmentId": segId,
                                    "elementIndex": eIdx,
                                    "position": segIndex
                                });
                            }

                            // Max length check
                            if (structKeyExists(elemSpec, "max") && valLen > elemSpec.max) {
                                arrayAppend(errors, {
                                    "code": "ELEMENT_TOO_LONG",
                                    "message": "Element " & segId & padNumber(eIdx) & " length [" & valLen & "] exceeds maximum [" & elemSpec.max & "]",
                                    "segmentId": segId,
                                    "elementIndex": eIdx,
                                    "position": segIndex
                                });
                            }

                            // Data type validation
                            if (structKeyExists(elemSpec, "type")) {
                                var typeValid = validateDataType(elemVal, elemSpec.type);
                                if (!typeValid) {
                                    arrayAppend(errors, {
                                        "code": "INVALID_DATA_TYPE",
                                        "message": "Element " & segId & padNumber(eIdx) & " value [" & elemVal & "] violates data type [" & elemSpec.type & "]",
                                        "segmentId": segId,
                                        "elementIndex": eIdx,
                                        "position": segIndex
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }

        // Push detected validation errors into ParseResult
        for (var err in errors) {
            arguments.parseResult.addError(err.message, err.code, 0, 0, err.segmentId ?: "");
        }

        return errors;
    }

    private boolean function validateDataType(required string val, required string type) {
        var t = ucase(arguments.type);
        if (t == "AN") {
            // Printable string
            return true;
        } else if (t == "N0" || t == "N") {
            // Integer numeric
            return isValid("integer", arguments.val) || reFind("^\-?[0-9]+$", arguments.val);
        } else if (left(t, 1) == "N") {
            // Implied decimal N1, N2, etc. (digits only)
            return reFind("^\-?[0-9]+$", arguments.val);
        } else if (t == "R") {
            // Real / decimal number
            return isNumeric(arguments.val);
        } else if (t == "DT") {
            // Date format YYMMDD (6) or CCYYMMDD (8)
            var l = len(arguments.val);
            return (l == 6 || l == 8) && reFind("^[0-9]+$", arguments.val);
        } else if (t == "TM") {
            // Time format HHMM (4), HHMMSS (6), etc.
            var tl = len(arguments.val);
            return (tl >= 4 && tl <= 8) && reFind("^[0-9]+$", arguments.val);
        } else if (t == "ID") {
            // Code identifier
            return len(trim(arguments.val)) > 0;
        }
        return true;
    }

    private string function padNumber(required numeric num) {
        return arguments.num < 10 ? ("0" & arguments.num) : toString(arguments.num);
    }
}
