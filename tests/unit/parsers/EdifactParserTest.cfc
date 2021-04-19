component {

    public void function run(required any suite) {
        var sampleOrders = "UNA:+.? '" &
            "UNB+UNOC:3+SENDER001:ZZZ+RECIPIENT001:ZZZ+261102:1200+IREF0001+++++1'" &
            "UNH+MREF0001+ORDERS:D:01B:UN:EAN010'" &
            "BGM+220+ORD-450099+9'" &
            "DTM+137:20261102:102'" &
            "NAD+BY+BUYER_GLN::9++GLOBAL RETAIL CORP+CENTRAL AVE+NEW YORK+NY+10001+US'" &
            "NAD+SU+SUPPLIER_GLN::9++ACME INDUSTRIAL LOGISTICS+BAKER ST+LONDON+++GB'" &
            "LIN+1++PRODUCT_A:EN'" &
            "QTY+21:250:PCE'" &
            "MOA+203:6250.00'" &
            "PRI+AAA:25.00:CT:NTP'" &
            "LIN+2++PRODUCT_B:EN'" &
            "QTY+21:50:PCE'" &
            "MOA+203:4000.00'" &
            "PRI+AAA:80.00:CT:NTP'" &
            "UNS+S'" &
            "CNT+2:2'" &
            "MOA+86:10250.00'" &
            "UNT+17+MREF0001'" &
            "UNZ+1+IREF0001'";

        suite.describe("EDIFACT: Lexer and Delimiter Detection", function(s) {
            s.it("parses UNA service string advice", function() {
                var lexer = new app.parsers.edifact.EdifactLexer();
                var delims = lexer.detectDelimiters(sampleOrders);
                s.assertTrue(delims.hasUna);
                s.assertEquals(":", delims.component);
                s.assertEquals("+", delims.element);
                s.assertEquals(".", delims.decimal);
                s.assertEquals("?", delims.release);
                s.assertEquals("'", delims.segment);
            });

            s.it("decodes release character escape sequences cleanly", function() {
                var rawWithEscapes = "BGM+220+DOC?+123?:TEST?'VAL+9'";
                var lexer = new app.parsers.edifact.EdifactLexer();
                var tokens = lexer.tokenize(rawWithEscapes);

                s.assertEquals("SEGMENT_ID", tokens[1].getType());
                s.assertEquals("BGM", tokens[1].getValue());

                s.assertEquals("ELEMENT", tokens[2].getType());
                s.assertEquals("220", tokens[2].getValue());

                // Token 3 contains escaped data: DOC+123:TEST'VAL
                s.assertEquals("ELEMENT", tokens[3].getType());
                s.assertEquals("DOC+123:TEST'VAL", tokens[3].getValue());
            });
        });

        suite.describe("EDIFACT: Hierarchical Parser", function(s) {
            s.it("parses complete ORDERS interchange into AST", function() {
                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(sampleOrders);

                s.assertTrue(res.isSuccess());
                s.assertFalse(res.hasErrors());

                var ast = res.getAst();
                s.assertEquals(1, arrayLen(ast.interchanges));

                var ic = ast.interchanges[1];
                s.assertEquals("IREF0001", isArray(ic.controlReference) ? ic.controlReference[1] : ic.controlReference);

                s.assertEquals(1, arrayLen(ic.messages));
                var msg = ic.messages[1];
                s.assertEquals("MREF0001", msg.messageReference);
                s.assertEquals("ORDERS", msg.type);
                s.assertEquals("D", msg.version);
                s.assertEquals("01B", msg.release);

                // Check flat segments
                var bgm = res.findFirstSegment("BGM");
                s.assertEquals("ORD-450099", bgm.elements[2]);

                var lins = res.findSegments("LIN");
                s.assertEquals(2, arrayLen(lins));
            });

            s.it("records error when UNZ control reference does not match UNB", function() {
                var corrupted = replace(sampleOrders, "UNZ+1+IREF0001'", "UNZ+1+CORRUPT_REF'");
                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(corrupted);
                s.assertTrue(res.hasErrors());
                s.assertEquals("INTERCHANGE_REF_MISMATCH", res.getErrors()[1].code);
            });
        });

        suite.describe("EDIFACT: Serializer Roundtrip", function(s) {
            s.it("serializes AST back to valid wire representation", function() {
                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(sampleOrders);

                var serializer = new app.parsers.edifact.EdifactSerializer();
                var wire = serializer.serialize(res.getAst(), {"newlineAfterSegment": false, "emitUna": true});

                s.assertTrue(findNoCase("UNA:+.? '", wire) == 1);
                s.assertTrue(findNoCase("UNB+UNOC:3+", wire) > 0);
                s.assertTrue(findNoCase("UNH+MREF0001+ORDERS:D:01B:UN:EAN010'", wire) > 0);
                s.assertTrue(findNoCase("UNZ+1+IREF0001'", wire) > 0);
            });
        });

        suite.describe("EDIFACT: CONTRL Acknowledgment Generator", function(s) {
            s.it("generates positive CONTRL acknowledgment with UCI and UCM", function() {
                var parser = new app.parsers.edifact.EdifactParser();
                var res = parser.parse(sampleOrders);

                var contrlGen = new app.parsers.edifact.ContrlGenerator();
                var ack = contrlGen.generateContrl(res);

                s.assertEquals("7", ack.status); // 7 = Acknowledged
                s.assertTrue(findNoCase("UNH+", ack.wire) > 0);
                s.assertTrue(findNoCase("CONTRL:D:4:UN", ack.wire) > 0);
                s.assertTrue(findNoCase("UCI+IREF0001+", ack.wire) > 0);
                s.assertTrue(findNoCase("UCM+MREF0001+ORDERS:D:01B:UN+7'", ack.wire) > 0);
                s.assertTrue(findNoCase("UNZ+1+", ack.wire) > 0);
            });
        });
    }
}
