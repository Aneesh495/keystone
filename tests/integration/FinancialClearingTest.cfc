/**
 * Keystone Integration Tests - Financial Clearing ISO 20022 Pipeline
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: Financial ISO 20022 Clearing Pipeline", function(s) {

            var sampleIsoPath = expandPath("/sample_data/iso20022/pain_001_credit_transfer.xml");

            s.it("parses customer credit transfer pain.001 and validates financial transaction attributes", function() {
                var rawXml = fileRead(sampleIsoPath, "utf-8");

                var parser = new app.parsers.iso20022.Iso20022Parser();
                var parseRes = parser.parse(rawXml);
                s.assertTrue(parseRes.isSuccess());

                var data = parseRes.getData();
                s.assertEquals("pain.001.001.09", data.messageType);
                s.assertEquals("MSG-PAIN001-20261102-001", data.groupHeader.messageId);
                s.assertEquals(450000.00, val(data.groupHeader.controlSum));
                s.assertEquals("ACME INDUSTRIAL CORP", data.groupHeader.initiatingParty);
                s.assertEquals(1, arrayLen(data.transactions));
                s.assertEquals(450000.00, val(data.transactions[1].amount));
                s.assertEquals("USD", data.transactions[1].currency);
                s.assertEquals("GLOBAL LOGISTICS CORP", data.transactions[1].creditor);

                var validator = new app.parsers.iso20022.Iso20022Validator();
                var valErrors = validator.validate(data);
                s.assertEquals(0, arrayLen(valErrors));
            });

        });
    }

}
