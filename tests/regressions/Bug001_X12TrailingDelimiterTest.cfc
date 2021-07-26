/**
 * Regression Test: Bug-001
 * Description: X12 Lexer ISA11 standard identifier 'U' was mistakenly interpreted
 * as a repetition delimiter, causing element values containing 'U' (such as currency 'USD')
 * to be truncated or split into composite components.
 */
component {

    public void function run(required any suite) {
        suite.describe("Regression: Bug-001 X12 ISA11 Delimiter and Trailing Delimiters", function(s) {

            s.it("correctly preserves alphanumeric characters in currency elements without repetition splitting", function() {
                var rawEdi = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *261102*1200*U*00401*000000001*0*P*>~" &
                    "GS*PO*SENDER*RECEIVER*20261102*1200*1*X*004010~" &
                    "ST*850*0001~" &
                    "CUR*BY*USD~" &
                    "SE*3*0001~" &
                    "GE*1*1~" &
                    "IEA*1*000000001~";

                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(rawEdi);

                s.assertTrue(res.isSuccess());
                var ast = res.getAst();
                var curSeg = {};
                for (var seg in ast.segments) {
                    if (seg.id == "CUR") {
                        curSeg = seg;
                        break;
                    }
                }

                s.assertFalse(structIsEmpty(curSeg));
                s.assertEquals("BY", curSeg.elements[1]);
                s.assertEquals("USD", curSeg.elements[2]);
            });

            s.it("handles trailing delimiters on segment endings without creating spurious empty elements", function() {
                var rawEdi = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *261102*1200*U*00401*000000001*0*P*>~" &
                    "GS*PO*SENDER*RECEIVER*20261102*1200*1*X*004010~" &
                    "ST*850*0001~" &
                    "REF*DP*90210*~" &
                    "SE*3*0001~" &
                    "GE*1*1~" &
                    "IEA*1*000000001~";

                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(rawEdi);

                s.assertTrue(res.isSuccess());
            });

        });
    }

}
