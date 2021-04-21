component {

    property name="fieldSeparator" type="string";
    property name="componentSeparator" type="string";
    property name="repetitionSeparator" type="string";
    property name="escapeCharacter" type="string";
    property name="subcomponentSeparator" type="string";

    /**
     * Constructor for HL7Lexer.
     */
    public any function init(
        string fieldSeparator = "|",
        string componentSeparator = "^",
        string repetitionSeparator = "~",
        string escapeCharacter = "\",
        string subcomponentSeparator = "&"
    ) {
        variables.fieldSeparator = arguments.fieldSeparator;
        variables.componentSeparator = arguments.componentSeparator;
        variables.repetitionSeparator = arguments.repetitionSeparator;
        variables.escapeCharacter = arguments.escapeCharacter;
        variables.subcomponentSeparator = arguments.subcomponentSeparator;
        return this;
    }

    /**
     * Detects HL7 encoding characters from the MSH header.
     * MSH format: MSH|^~\&|...
     */
    public struct function detectDelimiters(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        if (left(trimmed, 3) == "MSH" && len(trimmed) >= 8) {
            variables.fieldSeparator = mid(trimmed, 4, 1);
            variables.componentSeparator = mid(trimmed, 5, 1);
            variables.repetitionSeparator = mid(trimmed, 6, 1);
            variables.escapeCharacter = mid(trimmed, 7, 1);
            variables.subcomponentSeparator = mid(trimmed, 8, 1);

            return {
                "field": variables.fieldSeparator,
                "component": variables.componentSeparator,
                "repetition": variables.repetitionSeparator,
                "escape": variables.escapeCharacter,
                "subcomponent": variables.subcomponentSeparator,
                "hasMsh": true
            };
        }

        return {
            "field": variables.fieldSeparator,
            "component": variables.componentSeparator,
            "repetition": variables.repetitionSeparator,
            "escape": variables.escapeCharacter,
            "subcomponent": variables.subcomponentSeparator,
            "hasMsh": false
        };
    }

    /**
     * Splits raw HL7 message into segment lines (separated by CR or LF).
     */
    public array function splitSegments(required string rawInput) {
        var lines = [];
        // Normalize CR+LF and bare CR to LF
        var normalized = replace(arguments.rawInput, chr(13) & chr(10), chr(10), "all");
        normalized = replace(normalized, chr(13), chr(10), "all");

        var rawList = listToArray(normalized, chr(10));
        for (var l in rawList) {
            var trimmed = trim(l);
            if (len(trimmed) > 0) {
                arrayAppend(lines, trimmed);
            }
        }

        return lines;
    }

    /**
     * Splits a segment string into field tokens.
     * Special handling for MSH: MSH[1] is the field separator itself.
     */
    public array function splitFields(required string segmentText) {
        var fields = [];
        var isMsh = (left(arguments.segmentText, 3) == "MSH");
        var sep = variables.fieldSeparator;

        if (isMsh) {
            // MSH is special:
            // segmentText: MSH|^~\&|SEND_APP|SEND_FAC|...
            // fields[1] = "|" (Field Separator, MSH-1)
            // fields[2] = "^~\&" (Encoding Characters, MSH-2)
            // fields[3] = "SEND_APP" (Sending Application, MSH-3)
            arrayAppend(fields, sep);
            var afterSep = right(arguments.segmentText, len(arguments.segmentText) - 4);
            var rest = listToArray(afterSep, sep, true); // keep empty fields
            for (var r in rest) {
                arrayAppend(fields, r);
            }
        } else {
            var allParts = listToArray(arguments.segmentText, sep, true);
            // First part is segment ID (e.g. PID), remaining are fields
            for (var i = 2; i <= arrayLen(allParts); i++) {
                arrayAppend(fields, allParts[i]);
            }
        }

        return fields;
    }

    /**
     * Splits a field value into components using '^'.
     */
    public array function splitComponents(required string fieldText) {
        return listToArray(arguments.fieldText, variables.componentSeparator, true);
    }

    /**
     * Splits repeating fields using '~'.
     */
    public array function splitRepetitions(required string fieldText) {
        return listToArray(arguments.fieldText, variables.repetitionSeparator, true);
    }

    public string function getFieldSeparator() { return variables.fieldSeparator; }
    public string function getComponentSeparator() { return variables.componentSeparator; }
    public string function getRepetitionSeparator() { return variables.repetitionSeparator; }
}
