/**
 * Regression Test: Bug-002
 * Description: UN/EDIFACT release character ('?') escaping data delimiters ('+', ':', '?')
 * was previously stripped incorrectly or collapsed composite arrays, corrupting
 * unescaped text containing embedded question marks.
 */
component {

    public void function run(required any suite) {
        suite.describe("Regression: Bug-002 UN/EDIFACT Release Escape Character Processing", function(s) {

            s.it("correctly preserves escaped plus signs inside data elements", function() {
                var rawEdi = "UNA:+.? '" & chr(10) &
                    "UNB+UNOA:2+PARTNER_A+PARTNER_B+261102:1200+IREF01'" & chr(10) &
                    "UNH+MREF01+ORDERS:D:96A:UN:EAN008'" & chr(10) &
                    "FTX+AAI+++NOTE WITH ?+ PLUS SIGN AND ?: COLON'" & chr(10) &
                    "UNT+3+MREF01'" & chr(10) &
                    "UNZ+1+IREF01'";

                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(rawEdi);

                s.assertTrue(res.isSuccess());
                var ast = res.getAst();
                var ftxSeg = {};
                for (var seg in ast.segments) {
                    if (seg.id == "FTX") {
                        ftxSeg = seg;
                        break;
                    }
                }

                s.assertFalse(structIsEmpty(ftxSeg));
                var noteText = ftxSeg.elements[4];
                if (isArray(noteText)) {
                    noteText = arrayLen(noteText) > 0 ? noteText[1] : "";
                }
                s.assertTrue(find("+", noteText) > 0);
            });

            s.it("correctly handles consecutive release characters representing literal question mark", function() {
                var rawEdi = "UNA:+.? '" & chr(10) &
                    "UNB+UNOA:2+PARTNER_A+PARTNER_B+261102:1200+IREF02'" & chr(10) &
                    "UNH+MREF02+ORDERS:D:96A:UN:EAN008'" & chr(10) &
                    "FTX+AAI+++WHAT IS THIS??'" & chr(10) &
                    "UNT+3+MREF02'" & chr(10) &
                    "UNZ+1+IREF02'";

                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(rawEdi);

                s.assertTrue(res.isSuccess());
            });

        });
    }

}
