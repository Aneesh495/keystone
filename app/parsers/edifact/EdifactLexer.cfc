component {

    property name="componentSeparator" type="string";
    property name="elementSeparator" type="string";
    property name="decimalPoint" type="string";
    property name="releaseCharacter" type="string";
    property name="repetitionSeparator" type="string";
    property name="segmentTerminator" type="string";

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
     * Splits raw EDIFACT stream into array of raw segment strings, respecting release character escapes.
     */
    public array function splitSegments(required string rawInput) {
        var delims = detectDelimiters(arguments.rawInput);
        var input = arguments.rawInput;
        var startOffset = delims.hasUna ? (findNoCase("UNA", input) + 9) : 1;
        var inputLen = len(input);

        var segs = [];
        var cur = "";
        var i = startOffset;

        while (i <= inputLen) {
            var ch = mid(input, i, 1);
            if (ch == variables.releaseCharacter && i < inputLen) {
                cur &= ch & mid(input, i + 1, 1);
                i += 2;
                continue;
            }
            if (ch == variables.segmentTerminator) {
                var cleanSeg = trim(cur);
                if (len(cleanSeg) > 0) {
                    arrayAppend(segs, cleanSeg);
                }
                cur = "";
                i++;
                continue;
            }
            cur &= ch;
            i++;
        }

        var trailing = trim(cur);
        if (len(trailing) > 0) {
            arrayAppend(segs, trailing);
        }

        return segs;
    }

    /**
     * Splits string by delimiter while respecting escape character.
     */
    public array function splitTokens(required string text, required string delim) {
        var list = [];
        var cur = "";
        var lenText = len(arguments.text);
        var i = 1;

        while (i <= lenText) {
            var ch = mid(arguments.text, i, 1);
            if (ch == variables.releaseCharacter && i < lenText) {
                cur &= ch & mid(arguments.text, i + 1, 1);
                i += 2;
                continue;
            }
            if (ch == arguments.delim) {
                arrayAppend(list, cur);
                cur = "";
                i++;
                continue;
            }
            cur &= ch;
            i++;
        }
        arrayAppend(list, cur);
        return list;
    }

    /**
     * Unescapes release characters from string.
     */
    public string function unescape(required string text) {
        var res = "";
        var lenText = len(arguments.text);
        var i = 1;

        while (i <= lenText) {
            var ch = mid(arguments.text, i, 1);
            if (ch == variables.releaseCharacter && i < lenText) {
                res &= mid(arguments.text, i + 1, 1);
                i += 2;
                continue;
            }
            res &= ch;
            i++;
        }
        return res;
    }

    /**
     * Tokenizes raw EDIFACT stream into token list for compatibility.
     */
    public array function tokenize(required string rawInput) {
        var tokens = [];
        var segments = splitSegments(arguments.rawInput);
        var lineNum = 1;

        for (var segText in segments) {
            var rawParts = splitTokens(segText, variables.elementSeparator);
            var segId = rawParts[1];

            arrayAppend(tokens, new app.parsers.base.Token(
                type = "SEGMENT_ID",
                value = segId,
                line = lineNum,
                column = 1,
                offset = 0
            ));

            for (var p = 2; p <= arrayLen(rawParts); p++) {
                var elemPart = rawParts[p];
                var comps = splitTokens(elemPart, variables.componentSeparator);

                if (arrayLen(comps) > 1) {
                    for (var c in comps) {
                        arrayAppend(tokens, new app.parsers.base.Token(
                            type = "COMPONENT",
                            value = unescape(c),
                            line = lineNum,
                            column = 1,
                            offset = 0
                        ));
                    }
                } else {
                    arrayAppend(tokens, new app.parsers.base.Token(
                        type = "ELEMENT",
                        value = unescape(elemPart),
                        line = lineNum,
                        column = 1,
                        offset = 0
                    ));
                }
            }

            arrayAppend(tokens, new app.parsers.base.Token(
                type = "SEGMENT_END",
                value = variables.segmentTerminator,
                line = lineNum,
                column = 1,
                offset = 0
            ));
            lineNum++;
        }

        arrayAppend(tokens, new app.parsers.base.Token(
            type = "EOF",
            value = "",
            line = lineNum,
            column = 1,
            offset = 0
        ));

        return tokens;
    }

    public string function getComponentSeparator() { return variables.componentSeparator; }
    public string function getElementSeparator() { return variables.elementSeparator; }
    public string function getSegmentTerminator() { return variables.segmentTerminator; }
    public string function getReleaseCharacter() { return variables.releaseCharacter; }
}
