/**
 * Keystone Integration Tests - End-to-End Healthcare HL7 v2 to FHIR R4 Pipeline
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: Healthcare HL7 to FHIR Pipeline", function(s) {

            var sampleHl7Path = expandPath("/sample_data/hl7/adt_a01_patient_admission.hl7");

            s.it("parses HL7 ADT A01, converts to FHIR R4 Patient resource, and returns MSA AA acknowledgment", function() {
                var rawHl7 = fileRead(sampleHl7Path, "utf-8");

                // Parse HL7
                var parser = new app.parsers.hl7.HL7Parser();
                var parseRes = parser.parse(rawHl7);
                s.assertTrue(parseRes.isSuccess());

                var ast = parseRes.getAst();
                s.assertEquals(6, arrayLen(ast.segments));

                // Convert to FHIR R4
                var converter = new app.parsers.hl7.FhirConverter();
                var fhir = converter.toFhirPatient(ast);

                s.assertEquals("Patient", fhir.resourceType);
                s.assertEquals("WILLIAMS", fhir.name[1].family);
                s.assertEquals("ROBERT", fhir.name[1].given[1]);
                s.assertEquals("male", fhir.gender);
                s.assertEquals("1974-08-22", fhir.birthDate);

                // Generate Acknowledgment
                var ackGen = new app.parsers.hl7.HL7AckGenerator();
                var ackHl7 = ackGen.generateAck(parseRes, "AA", "Patient record processed");

                s.assertTrue(find("MSA|AA|MSG202611020001", ackHl7.wire) > 0);
            });

        });
    }

}
