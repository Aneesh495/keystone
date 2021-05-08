component {

    public void function run(required any suite) {
        var samplePain001 = '<?xml version="1.0" encoding="UTF-8"?>' & chr(10) &
            '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:pain.001.001.09">' & chr(10) &
            '  <CstmrCdtTrfInitn>' & chr(10) &
            '    <GrpHdr>' & chr(10) &
            '      <MsgId>MSG-20261102-001</MsgId>' & chr(10) &
            '      <CreDtTm>2026-11-02T14:00:00</CreDtTm>' & chr(10) &
            '      <NbOfTxs>1</NbOfTxs>' & chr(10) &
            '      <InitgPty><Nm>ACME CORP HOLDINGS</Nm></InitgPty>' & chr(10) &
            '    </GrpHdr>' & chr(10) &
            '    <PmtInf>' & chr(10) &
            '      <PmtInfId>PMT-INF-001</PmtInfId>' & chr(10) &
            '      <PmtMtd>TRF</PmtMtd>' & chr(10) &
            '      <CdtTrfTxInf>' & chr(10) &
            '        <PmtId>' & chr(10) &
            '          <EndToEndId>E2E-WIRE-9988</EndToEndId>' & chr(10) &
            '        </PmtId>' & chr(10) &
            '        <Amt>' & chr(10) &
            '          <InstdAmt Ccy="EUR">45000.00</InstdAmt>' & chr(10) &
            '        </Amt>' & chr(10) &
            '        <Dbtr><Nm>ACME CORP</Nm></Dbtr>' & chr(10) &
            '        <DbtrAcct><Id><IBAN>DE89370400440532013000</IBAN></Id></DbtrAcct>' & chr(10) &
            '        <DbtrAgt><FinInstnId><BICFI>DEUTDEDDFXX</BICFI></FinInstnId></DbtrAgt>' & chr(10) &
            '        <Cdtr><Nm>GLOBAL LOGISTICS LTD</Nm></Cdtr>' & chr(10) &
            '        <CdtrAcct><Id><IBAN>GB82WEST12345698765432</IBAN></Id></CdtrAcct>' & chr(10) &
            '        <CdtrAgt><FinInstnId><BICFI>NWBKGB2LXXX</BICFI></FinInstnId></CdtrAgt>' & chr(10) &
            '        <RmtInf><Ustrd>INVOICE INV-2026-0042 SETTLEMENT</Ustrd></RmtInf>' & chr(10) &
            '      </CdtTrfTxInf>' & chr(10) &
            '    </PmtInf>' & chr(10) &
            '  </CstmrCdtTrfInitn>' & chr(10) &
            '</Document>';

        suite.describe("ISO 20022: Streaming XML Parser", function(s) {
            s.it("parses pain.001 customer credit transfer message", function() {
                var parser = new app.parsers.iso20022.Iso20022Parser();
                var res = parser.parse(samplePain001);

                s.assertTrue(res.isSuccess());
                s.assertFalse(res.hasErrors());

                var ast = res.getAst();
                s.assertEquals("pain.001.001.09", ast.messageType);
                s.assertEquals("MSG-20261102-001", ast.groupHeader.messageId);
                s.assertEquals("ACME CORP HOLDINGS", ast.groupHeader.initiatingParty);

                s.assertEquals(1, arrayLen(ast.transactions));
                var tx = ast.transactions[1];
                s.assertEquals("E2E-WIRE-9988", tx.paymentId);
                s.assertEquals("45000.00", tx.amount);
                s.assertEquals("EUR", tx.currency);
                s.assertEquals("DE89370400440532013000", tx.debtorIban);
                s.assertEquals("GB82WEST12345698765432", tx.creditorIban);
                s.assertEquals("INVOICE INV-2026-0042 SETTLEMENT", tx.remittanceInfo);
            });
        });

        suite.describe("ISO 20022: IBAN Mod-97 and BIC Validation", function(s) {
            s.it("validates mathematically correct IBAN checksums via Mod-97", function() {
                var validator = new app.parsers.iso20022.Iso20022Validator();
                // Valid German IBAN
                s.assertTrue(validator.validateIban("DE89370400440532013000"));
                // Valid British IBAN
                s.assertTrue(validator.validateIban("GB82WEST12345698765432"));
                // Invalid IBAN (altered digit)
                s.assertFalse(validator.validateIban("GB82WEST12345698765433"));
                s.assertFalse(validator.validateIban("INVALID_IBAN"));
            });

            s.it("validates 8 and 11 character ISO 9362 BIC SWIFT codes", function() {
                var validator = new app.parsers.iso20022.Iso20022Validator();
                s.assertTrue(validator.validateBic("DEUTDEDD"));
                s.assertTrue(validator.validateBic("DEUTDEDDFXX"));
                s.assertTrue(validator.validateBic("NWBKGB2LXXX"));
                s.assertFalse(validator.validateBic("TOOLONG12345"));
                s.assertFalse(validator.validateBic("SHORT"));
            });

            s.it("performs full semantic validation on pain.001 document", function() {
                var parser = new app.parsers.iso20022.Iso20022Parser();
                var res = parser.parse(samplePain001);
                var validator = new app.parsers.iso20022.Iso20022Validator();
                var errors = validator.validate(res);
                s.assertEquals(0, arrayLen(errors));
            });
        });

        suite.describe("ISO 20022: Canonical XML Serializer", function(s) {
            s.it("serializes AST into valid XML document with namespaces", function() {
                var parser = new app.parsers.iso20022.Iso20022Parser();
                var res = parser.parse(samplePain001);

                var serializer = new app.parsers.iso20022.Iso20022Serializer();
                var xmlOut = serializer.serialize(res.getAst());

                s.assertTrue(findNoCase("<Document", xmlOut) > 0);
                s.assertTrue(findNoCase("<MsgId>MSG-20261102-001</MsgId>", xmlOut) > 0);
                s.assertTrue(findNoCase('<InstdAmt Ccy="EUR">45000.00</InstdAmt>', xmlOut) > 0);
                s.assertTrue(findNoCase("<IBAN>DE89370400440532013000</IBAN>", xmlOut) > 0);
            });
        });
    }
}
