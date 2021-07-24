component {

    property name="elementSeparator" type="string";
    property name="subElementSeparator" type="string";
    property name="segmentTerminator" type="string";
    property name="repetitionSeparator" type="string";
    property name="line" type="numeric";
    property name="column" type="numeric";
    property name="position" type="numeric";

    /**
     * Constructor for X12Lexer.
     */
    public any function init(
        string elementSeparator = "*",
        string subElementSeparator = ":",
        string segmentTerminator = "~",
        string repetitionSeparator = "^"
    ) {
        variables.elementSeparator = arguments.elementSeparator;
        variables.subElementSeparator = arguments.subElementSeparator;
        variables.segmentTerminator = arguments.segmentTerminator;
        variables.repetitionSeparator = arguments.repetitionSeparator;
        variables.line = 1;
        variables.column = 1;
        variables.position = 1;
        return this;
    }

    /**
     * Inspects the fixed-width ISA header to dynamically detect separators.
     * ISA length is standard 106 bytes.
     */
    public struct function detectDelimiters(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        if (left(trimmed, 3) != "ISA") {
            return {
                "element": variables.elementSeparator,
                "subElement": variables.subElementSeparator,
                "segment": variables.segmentTerminator,
                "repetition": variables.repetitionSeparator,
                "autoDetected": false
            };
        }

        // Element separator is at character index 4
        var elemSep = mid(trimmed, 4, 1);

        // Repetition separator is at character index 83 in 5010+ or default
        var repSep = mid(trimmed, 83, 1);
        if (repSep == " " || repSep == elemSep || reFind("^[A-Za-z0-9]$", repSep)) {
            repSep = "^";
        }

        // Component separator is at character index 105
        var subElemSep = mid(trimmed, 105, 1);

        // Segment terminator is at character index 106
        var segTerm = mid(trimmed, 106, 1);

        variables.elementSeparator = elemSep;
        variables.subElementSeparator = subElemSep;
        variables.segmentTerminator = segTerm;
        variables.repetitionSeparator = repSep;

        return {
            "element": elemSep,
            "subElement": subElemSep,
            "segment": segTerm,
            "repetition": repSep,
            "autoDetected": true
        };
    }

    /**
     * Tokenizes raw X12 text into an array of lexical Token components.
     */
    public array function tokenize(required string rawInput) {
        var tokens = [];
        var input = arguments.rawInput;
        var inputLen = len(input);
        var currentToken = "";
        var inSegment = false;
        var tokenStartCol = 1;
        var tokenStartLine = 1;

        detectDelimiters(input);

        variables.line = 1;
        variables.column = 1;
        variables.position = 1;

        while (variables.position <= inputLen) {
            var ch = mid(input, variables.position, 1);

            // Handle newline tracking
            if (ch == chr(10)) {
                variables.line++;
                variables.column = 0;
            }

            if (ch == variables.segmentTerminator) {
                // Emit pending element token if any
                if (len(currentToken) > 0 || inSegment) {
                    arrayAppend(tokens, new app.parsers.base.Token(
                        type = inSegment ? "ELEMENT" : "SEGMENT_ID",
                        value = currentToken,
                        line = tokenStartLine,
                        column = tokenStartCol,
                        offset = variables.position - len(currentToken)
                    ));
                    currentToken = "";
                }
                // Emit SEGMENT_END token
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = "SEGMENT_END",
                    value = ch,
                    line = variables.line,
                    column = variables.column,
                    offset = variables.position
                ));
                inSegment = false;
            } else if (ch == variables.elementSeparator) {
                // Delimiter marks element boundary
                var tokenType = inSegment ? "ELEMENT" : "SEGMENT_ID";
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = tokenType,
                    value = currentToken,
                    line = tokenStartLine,
                    column = tokenStartCol,
                    offset = variables.position - len(currentToken)
                ));
                currentToken = "";
                inSegment = true;
                tokenStartCol = variables.column + 1;
                tokenStartLine = variables.line;
            } else if (ch == variables.subElementSeparator && inSegment) {
                // Sub-element component boundary
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = "COMPONENT",
                    value = currentToken,
                    line = tokenStartLine,
                    column = tokenStartCol,
                    offset = variables.position - len(currentToken)
                ));
                currentToken = "";
                tokenStartCol = variables.column + 1;
                tokenStartLine = variables.line;
            } else if (ch == variables.repetitionSeparator && inSegment) {
                // Repetition separator
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = "REPETITION",
                    value = currentToken,
                    line = tokenStartLine,
                    column = tokenStartCol,
                    offset = variables.position - len(currentToken)
                ));
                currentToken = "";
                tokenStartCol = variables.column + 1;
                tokenStartLine = variables.line;
            } else {
                // Ignore trailing carriage returns and line feeds immediately following segment terminators
                if (!inSegment && (ch == chr(13) || ch == chr(10) || ch == " " || ch == chr(9))) {
                    // Skip whitespace between segments
                } else {
                    if (len(currentToken) == 0) {
                        tokenStartCol = variables.column;
                        tokenStartLine = variables.line;
                    }
                    currentToken &= ch;
                }
            }

            variables.position++;
            variables.column++;
        }

        // Flush any trailing token
        if (len(currentToken) > 0) {
            arrayAppend(tokens, new app.parsers.base.Token(
                type = inSegment ? "ELEMENT" : "SEGMENT_ID",
                value = currentToken,
                line = tokenStartLine,
                column = tokenStartCol,
                offset = variables.position - len(currentToken)
            ));
        }

        arrayAppend(tokens, new app.parsers.base.Token(
            type = "EOF",
            value = "",
            line = variables.line,
            column = variables.column,
            offset = variables.position
        ));

        return tokens;
    }

    public string function getElementSeparator() { return variables.elementSeparator; }
    public string function getSubElementSeparator() { return variables.subElementSeparator; }
    public string function getSegmentTerminator() { return variables.segmentTerminator; }
    public string function getRepetitionSeparator() { return variables.repetitionSeparator; }
}
