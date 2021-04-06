component {

    property name="componentSeparator" type="string";
    property name="elementSeparator" type="string";
    property name="decimalPoint" type="string";
    property name="releaseCharacter" type="string";
    property name="repetitionSeparator" type="string";
    property name="segmentTerminator" type="string";
    property name="line" type="numeric";
    property name="column" type="numeric";
    property name="position" type="numeric";

    /**
     * Constructor for EdifactLexer.
     */
    public any function init(
        string componentSeparator = ":",
        string elementSeparator = "+",
        string decimalPoint = ".",
        string releaseCharacter = "?",
        string repetitionSeparator = "*",
        string segmentTerminator = "'"
    ) {
        variables.componentSeparator = arguments.componentSeparator;
        variables.elementSeparator = arguments.elementSeparator;
        variables.decimalPoint = arguments.decimalPoint;
        variables.releaseCharacter = arguments.releaseCharacter;
        variables.repetitionSeparator = arguments.repetitionSeparator;
        variables.segmentTerminator = arguments.segmentTerminator;
        variables.line = 1;
        variables.column = 1;
        variables.position = 1;
        return this;
    }

    /**
     * Inspects UNA Service String Advice if present at the start of raw EDIFACT payload.
     * Fixed length: 9 characters ("UNA:+.? '")
     */
    public struct function detectDelimiters(required string rawInput) {
        var trimmed = trim(arguments.rawInput);
        if (left(trimmed, 3) == "UNA" && len(trimmed) >= 9) {
            variables.componentSeparator = mid(trimmed, 4, 1);
            variables.elementSeparator = mid(trimmed, 5, 1);
            variables.decimalPoint = mid(trimmed, 6, 1);
            variables.releaseCharacter = mid(trimmed, 7, 1);
            variables.repetitionSeparator = mid(trimmed, 8, 1);
            variables.segmentTerminator = mid(trimmed, 9, 1);

            return {
                "component": variables.componentSeparator,
                "element": variables.elementSeparator,
                "decimal": variables.decimalPoint,
                "release": variables.releaseCharacter,
                "repetition": variables.repetitionSeparator,
                "segment": variables.segmentTerminator,
                "hasUna": true
            };
        }

        return {
            "component": variables.componentSeparator,
            "element": variables.elementSeparator,
            "decimal": variables.decimalPoint,
            "release": variables.releaseCharacter,
            "repetition": variables.repetitionSeparator,
            "segment": variables.segmentTerminator,
            "hasUna": false
        };
    }

    /**
     * Tokenizes raw EDIFACT stream, respecting the release escape character '?'.
     */
    public array function tokenize(required string rawInput) {
        var tokens = [];
        var input = arguments.rawInput;
        var delims = detectDelimiters(input);

        // If UNA is present, skip past UNA (9 characters)
        var startOffset = delims.hasUna ? (findNoCase("UNA", input) + 9) : 1;
        var inputLen = len(input);

        var currentToken = "";
        var inSegment = false;
        var tokenStartCol = 1;
        var tokenStartLine = 1;

        variables.line = 1;
        variables.column = 1;
        variables.position = startOffset;

        while (variables.position <= inputLen) {
            var ch = mid(input, variables.position, 1);

            if (ch == chr(10)) {
                variables.line++;
                variables.column = 0;
            }

            // Check for release escape character
            if (ch == variables.releaseCharacter && variables.position < inputLen) {
                var nextCh = mid(input, variables.position + 1, 1);
                // Append escaped character directly
                currentToken &= nextCh;
                variables.position += 2;
                variables.column += 2;
                continue;
            }

            if (ch == variables.segmentTerminator) {
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
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = "SEGMENT_END",
                    value = ch,
                    line = variables.line,
                    column = variables.column,
                    offset = variables.position
                ));
                inSegment = false;
            } else if (ch == variables.elementSeparator) {
                var tokType = inSegment ? "ELEMENT" : "SEGMENT_ID";
                arrayAppend(tokens, new app.parsers.base.Token(
                    type = tokType,
                    value = currentToken,
                    line = tokenStartLine,
                    column = tokenStartCol,
                    offset = variables.position - len(currentToken)
                ));
                currentToken = "";
                inSegment = true;
                tokenStartCol = variables.column + 1;
                tokenStartLine = variables.line;
            } else if (ch == variables.componentSeparator && inSegment) {
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
            } else {
                // Ignore whitespace outside of segments
                if (!inSegment && (ch == chr(13) || ch == chr(10) || ch == " " || ch == chr(9))) {
                    // skip
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

    public string function getComponentSeparator() { return variables.componentSeparator; }
    public string function getElementSeparator() { return variables.elementSeparator; }
    public string function getSegmentTerminator() { return variables.segmentTerminator; }
    public string function getReleaseCharacter() { return variables.releaseCharacter; }
}
