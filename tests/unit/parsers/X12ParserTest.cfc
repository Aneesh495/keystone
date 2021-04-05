component {

    public void function run(required any suite) {
        var sample850 = "ISA*00*          *00*          *ZZ*ACMESUPPLY     *ZZ*GLOBALRETAIL   *261102*1200*^*00501*000000101*0*T*:~" &
            "GS*PO*ACMESUPPLY*GLOBALRETAIL*20261102*1200*101*X*005010~" &
            "ST*850*0001~" &
            "BEG*00*SA*PO-987654**20261102~" &
            "CUR*BY*USD~" &
            "REF*DP*042~" &
            "DTM*002*20261115~" &
            "N1*ST*EAST WAREHOUSE*92*WH-01~" &
            "N3*100 LOGISTICS BLVD~" &
            "N4*NEWARK*NJ*07102*US~" &
            "PO1*1*100*EA*25.50**VN*SKU-ALPHA-99~" &
            "PID*F****INDUSTRIAL GRADE SENSOR MODULE~" &
            "PO1*2*50*EA*120.00**VN*SKU-BETA-44~" &
            "PID*F****PROGRAMMABLE LOGIC CONTROLLER~" &
            "CTT*2*150~" &
            "SE*14*0001~" &
            "GE*1*101~" &
            "IEA*1*000000101~";

        suite.describe("X12: Lexer and Delimiter Detection", function(s) {
            s.it("detects standard X12 delimiters from ISA header", function() {
                var lexer = new app.parsers.x12.X12Lexer();
                var delims = lexer.detectDelimiters(sample850);
                s.assertEquals("*", delims.element);
                s.assertEquals(":", delims.subElement);
                s.assertEquals("~", delims.segment);
                s.assertEquals("^", delims.repetition);
                s.assertTrue(delims.autoDetected);
            });

            s.it("tokenizes X12 stream into correct token sequence", function() {
                var lexer = new app.parsers.x12.X12Lexer();
                var tokens = lexer.tokenize("ST*850*0001~BEG*00*SA*PO-123**20261102~");
                s.assertTrue(arrayLen(tokens) > 0);
                s.assertEquals("SEGMENT_ID", tokens[1].getType());
                s.assertEquals("ST", tokens[1].getValue());
                s.assertEquals("ELEMENT", tokens[2].getType());
                s.assertEquals("850", tokens[2].getValue());
            });
        });

        suite.describe("X12: Parser and AST Construction", function(s) {
            s.it("parses sample 850 PO into hierarchical interchanges and groups", function() {
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(sample850);

                s.assertTrue(res.isSuccess());
                s.assertFalse(res.hasErrors());

                var ast = res.getAst();
                s.assertEquals(1, arrayLen(ast.interchanges));

                var ic = ast.interchanges[1];
                s.assertEquals("ACMESUPPLY", ic.senderId);
                s.assertEquals("GLOBALRETAIL", ic.receiverId);
                s.assertEquals("000000101", ic.controlNumber);

                s.assertEquals(1, arrayLen(ic.groups));
                var grp = ic.groups[1];
                s.assertEquals("PO", grp.functionalCode);
                s.assertEquals("101", grp.controlNumber);

                s.assertEquals(1, arrayLen(grp.transactionSets));
                var tx = grp.transactionSets[1];
                s.assertEquals("850", tx.transactionCode);
                s.assertEquals("0001", tx.controlNumber);
            });

            s.it("navigates AST with findSegments helper", function() {
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(sample850);
                var po1Segments = res.findSegments("PO1");
                s.assertEquals(2, arrayLen(po1Segments));
                s.assertEquals("100", po1Segments[1].elements[2]);
                s.assertEquals("50", po1Segments[2].elements[2]);

                var beg = res.findFirstSegment("BEG");
                s.assertEquals("PO-987654", beg.elements[3]);
            });

            s.it("records error on control number mismatch in IEA", function() {
                var corrupted = replace(sample850, "IEA*1*000000101~", "IEA*1*999999999~");
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(corrupted);
                s.assertTrue(res.hasErrors());
                s.assertEquals("INTERCHANGE_CONTROL_MISMATCH", res.getErrors()[1].code);
            });
        });

        suite.describe("X12: Serializer Roundtrip", function(s) {
            s.it("serializes AST back into wire format matching original structure", function() {
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(sample850);

                var serializer = new app.parsers.x12.X12Serializer();
                var serialized = serializer.serialize(res.getAst(), {"newlineAfterSegment": false});

                s.assertTrue(findNoCase("ISA*00*", serialized) == 1);
                s.assertTrue(findNoCase("ST*850*0001~", serialized) > 0);
                s.assertTrue(findNoCase("PO1*1*100*EA*25.50", serialized) > 0);
                s.assertTrue(findNoCase("IEA*1*000000101~", serialized) > 0);
            });
        });

        suite.describe("X12: Semantic Validator", function(s) {
            s.it("validates 850 PO against Schema850 successfully", function() {
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(sample850);
                var validator = new app.parsers.x12.X12Validator();
                var schema = new app.parsers.x12.schemas.Schema850();

                var errors = validator.validate(res, schema);
                s.assertEquals(0, arrayLen(errors));
            });

            s.it("detects missing mandatory elements according to schema", function() {
                // Remove mandatory PO Number from BEG (element 3)
                var invalid850 = replace(sample850, "BEG*00*SA*PO-987654**20261102~", "BEG*00*SA***20261102~");
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(invalid850);
                var validator = new app.parsers.x12.X12Validator();
                var schema = new app.parsers.x12.schemas.Schema850();

                var errors = validator.validate(res, schema);
                s.assertTrue(arrayLen(errors) > 0);
                s.assertEquals("MANDATORY_ELEMENT_MISSING", errors[1].code);
            });
        });

        suite.describe("X12: Automated 997 Functional Acknowledgment Generator", function(s) {
            s.it("generates accepted 997 for valid inbound 850", function() {
                var parser = new app.parsers.x12.X12Parser();
                var res = parser.parse(sample850);

                var ackGen = new app.parsers.x12.X12AckGenerator();
                var ack = ackGen.generate997(res);

                s.assertEquals("A", ack.status);
                s.assertTrue(findNoCase("ST*997*", ack.wire) > 0);
                s.assertTrue(findNoCase("AK1*PO*101~", ack.wire) > 0);
                s.assertTrue(findNoCase("AK2*850*0001~", ack.wire) > 0);
                s.assertTrue(findNoCase("AK5*A~", ack.wire) > 0);
                s.assertTrue(findNoCase("AK9*A*1*1*1~", ack.wire) > 0);
            });
        });
    }
}
