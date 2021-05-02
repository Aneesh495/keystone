component {

    public void function run(required any suite) {
        var sampleAdt = "MSH|^~\&|EPIC|HOSPITAL_A|KEYSTONE|CLINICAL_SYS|20261102120000||ADT^A01^ADT_A01|MSG-90210|P|2.5.1" & chr(13) &
            "EVN|A01|20261102120000" & chr(13) &
            "PID|1||MRN-554433^^^HOSPITAL_A^MR||DOE^JOHN^A^MR||19850615|M|||123 MAIN STREET^^METROPOLIS^NY^10001^USA||555-0199" & chr(13) &
            "PV1|1|I|ICU^01^A|MED|||12345^SMITH^ALICE^MD||||||||||ADM|A0" & chr(13) &
            "DG1|1|I10|J18.9^PNEUMONIA, UNSPECIFIED ORGANISM|PNEUMONIA|20261102120000|A";

        var sampleOru = "MSH|^~\&|LAB_SYS|QUEST|KEYSTONE|DIAGNOSTICS|20261102130000||ORU^R01^ORU_R01|LAB-887766|P|2.5.1" & chr(13) &
            "PID|1||MRN-554433^^^HOSPITAL_A^MR||DOE^JOHN^A||19850615|M" & chr(13) &
            "OBR|1|ORD-101|LAB-202|24331-1^LIPID PANEL^LN|||20261102123000" & chr(13) &
            "OBX|1|NM|2093-3^CHOLESTEROL, TOTAL^LN||185|mg/dL|<200|N|||F" & chr(13) &
            "OBX|2|NM|2345-7^GLUCOSE^LN||142|mg/dL|70-99|H|||F" & chr(13) &
            "OBX|3|ST|5770-3^URINE COLOR^LN||YELLOW||YELLOW|N|||F";

        suite.describe("HL7: Lexer and Delimiter Detection", function(s) {
            s.it("detects standard HL7 pipe-and-hat delimiters", function() {
                var lexer = new app.parsers.hl7.HL7Lexer();
                var delims = lexer.detectDelimiters(sampleAdt);
                s.assertTrue(delims.hasMsh);
                s.assertEquals("|", delims.field);
                s.assertEquals("^", delims.component);
                s.assertEquals("~", delims.repetition);
                s.assertEquals("\", delims.escape);
                s.assertEquals("&", delims.subcomponent);
            });

            s.it("splits segments preserving MSH special fields", function() {
                var lexer = new app.parsers.hl7.HL7Lexer();
                var segs = lexer.splitSegments(sampleAdt);
                s.assertEquals(5, arrayLen(segs));

                var mshFields = lexer.splitFields(segs[1]);
                s.assertEquals("|", mshFields[1]);
                s.assertEquals("^~\&", mshFields[2]);
                s.assertEquals("EPIC", mshFields[3]);
            });
        });

        suite.describe("HL7: Parser and Clinical Hierarchy", function(s) {
            s.it("parses ADT A01 message into structured AST", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleAdt);

                s.assertTrue(res.isSuccess());
                s.assertFalse(res.hasErrors());

                var ast = res.getAst();
                s.assertEquals("ADT", ast.header.messageType);
                s.assertEquals("A01", ast.header.triggerEvent);
                s.assertEquals("MSG-90210", ast.header.controlId);

                var pid = res.findFirstSegment("PID");
                s.assertFalse(structIsEmpty(pid));

                // PID-5 is name: [DOE, JOHN, A, MR]
                var nameField = pid.elements[5];
                s.assertTrue(isArray(nameField));
                s.assertEquals("DOE", nameField[1]);
                s.assertEquals("JOHN", nameField[2]);
            });

            s.it("parses ORU R01 lab results with multiple observations", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleOru);

                s.assertTrue(res.isSuccess());
                var obxList = res.findSegments("OBX");
                s.assertEquals(3, arrayLen(obxList));

                // OBX 1: Cholesterol 185 Normal
                s.assertEquals("185", obxList[1].elements[5]);
                s.assertEquals("N", obxList[1].elements[8]);

                // OBX 2: Glucose 142 High
                s.assertEquals("142", obxList[2].elements[5]);
                s.assertEquals("H", obxList[2].elements[8]);
            });
        });

        suite.describe("HL7: Serializer and ACK Generation", function(s) {
            s.it("serializes HL7 AST back to wire format", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleAdt);

                var serializer = new app.parsers.hl7.HL7Serializer();
                var wire = serializer.serialize(res.getAst());

                s.assertTrue(findNoCase("MSH|^~\&|EPIC|HOSPITAL_A", wire) == 1);
                s.assertTrue(findNoCase("PID|1||MRN-554433", wire) > 0);
            });

            s.it("generates valid positive AA acknowledgment", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleAdt);

                var ackGen = new app.parsers.hl7.HL7AckGenerator();
                var ack = ackGen.generateAck(res);

                s.assertEquals("AA", ack.status);
                s.assertTrue(findNoCase("MSA|AA|MSG-90210", ack.wire) > 0);
            });
        });

        suite.describe("HL7: Bidirectional FHIR R4 Converter", function(s) {
            s.it("transforms HL7 PID segment into FHIR R4 Patient resource", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleAdt);

                var fhirConv = new app.parsers.hl7.FhirConverter();
                var patient = fhirConv.toPatientResource(res);

                s.assertEquals("Patient", patient.resourceType);
                s.assertEquals("MRN-554433", patient.id);
                s.assertEquals("male", patient.gender);
                s.assertEquals("1985-06-15", patient.birthDate);
                s.assertEquals("DOE", patient.name[1].family);
                s.assertEquals("JOHN", patient.name[1].given[1]);
                s.assertEquals("METROPOLIS", patient.address[1].city);
                s.assertEquals("NY", patient.address[1].state);
            });

            s.it("compiles ORU message into FHIR R4 Bundle with Patient and Observations", function() {
                var parser = new app.parsers.hl7.HL7Parser();
                var res = parser.parse(sampleOru);

                var fhirConv = new app.parsers.hl7.FhirConverter();
                var bundle = fhirConv.toBundleResource(res);

                s.assertEquals("Bundle", bundle.resourceType);
                s.assertEquals("collection", bundle.type);
                // 1 Patient + 3 Observations = 4 entries
                s.assertEquals(4, arrayLen(bundle.entry));

                var obsGlucose = bundle.entry[3].resource;
                s.assertEquals("Observation", obsGlucose.resourceType);
                s.assertEquals("final", obsGlucose.status);
                s.assertEquals(142, obsGlucose.valueQuantity.value);
                s.assertEquals("mg/dL", obsGlucose.valueQuantity.unit);
            });
        });
    }
}
