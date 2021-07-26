/**
 * Regression Test: Bug-003
 * Description: HL7 v2 parser previously treated repeated fields with tilde ('~')
 * as simple string tokens rather than decomposing them into repeated field instances,
 * causing Patient Identifier List (PID-3) with multiple MRNs to lose secondary identifiers.
 */
component {

    public void function run(required any suite) {
        suite.describe("Regression: Bug-003 HL7 v2 Field Repetitions and PID-3 Deconstruction", function(s) {

            s.it("correctly decomposes repeated fields in PID-3 into separate identifier instances", function() {
                var rawHl7 = "MSH|^~\&|EPIC|HOSPITAL|KEYSTONE|GATEWAY|20261102120000||ADT^A01^ADT_A01|MSG90101|P|2.5" & chr(13) &
                    "EVN|A01|20261102120000" & chr(13) &
                    "PID|1||10001^^^HOSP^MR~99999^^^STATE^DL||DOE^JANE^M^^^^L||19850615|F|||123 MAIN ST^^SPRINGFIELD^IL^62701||555-0199" & chr(13) &
                    "PV1|1|I|4E^402^1";

                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(rawHl7);

                s.assertTrue(res.isSuccess());
                var ast = res.getAst();
                var pidSeg = {};
                for (var seg in ast.segments) {
                    if (seg.id == "PID") {
                        pidSeg = seg;
                        break;
                    }
                }

                s.assertFalse(structIsEmpty(pidSeg));
                var pid3 = pidSeg.elements[3];
                // PID-3 has repetition separator ~ yielding an array of repeated instances
                s.assertTrue(isArray(pid3));
                s.assertEquals(2, arrayLen(pid3));
            });

            s.it("preserves empty trailing components in HL7 fields without array out-of-bounds error", function() {
                var rawHl7 = "MSH|^~\&|EPIC|HOSPITAL|KEYSTONE|GATEWAY|20261102120000||ADT^A08|MSG90102|P|2.5" & chr(13) &
                    "EVN|A08|20261102120000" & chr(13) &
                    "PID|1||10002||DOE^JOHN^^^^^||19900101|M";

                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(rawHl7);

                s.assertTrue(res.isSuccess());
            });

        });
    }

}
