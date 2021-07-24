/**
 * Keystone Integration Tests - End-to-End Supply Chain Transaction Flow
 * Tests Inbound X12 850 PO to Canonical JSON Order and Outbound 855 PO Acknowledgment.
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: Supply Chain X12 850/855 Workflow", function(s) {

            var sample850Path = expandPath("/sample_data/x12/850_purchase_order.edi");

            s.it("processes inbound X12 850 PO through parsing, validation, mapping, and 997 generation", function() {
                var rawEdi = fileRead(sample850Path, "utf-8");

                // Stage 1: Parse
                var parser = new app.parsers.x12.X12Parser();
                var parseRes = parser.parse(rawEdi);
                s.assertTrue(parseRes.isSuccess());

                var ast = parseRes.getAst();
                s.assertEquals(1, arrayLen(ast.interchanges));

                // Stage 2: Validate
                var validator = new app.parsers.x12.X12Validator();
                var valErrors = validator.validate(parseRes);
                s.assertEquals(0, arrayLen(valErrors));

                // Stage 3: Transform to Canonical Orders JSON
                var mapper = new app.transform.templates.X12_850_To_OrdersJson();
                var order = mapper.transform(ast);

                s.assertEquals("PO-2026-90412", order.orderId);
                s.assertEquals("USD", order.currency);
                s.assertEquals(2, arrayLen(order.lineItems));
                s.assertEquals(250, order.lineItems[1].quantity);
                s.assertEquals(42.50, order.lineItems[1].unitPrice);
                s.assertEquals(1000, order.lineItems[2].quantity);

                // Stage 4: Generate 997 Acknowledgment
                var ackGen = new app.parsers.x12.X12AckGenerator();
                var ack997Res = ackGen.generate997(parseRes);
                var ack997 = ack997Res.wire;

                s.assertTrue(len(ack997) > 0);
                s.assertTrue(find("ST*997*", ack997) > 0);
                s.assertTrue(find("AK9*A*", ack997) > 0);
            });

            s.it("transforms canonical order to Outbound X12 855 and serializes to valid EDI wire format", function() {
                var canonicalOrder = {
                    "orderId": "PO-99120",
                    "orderDate": "20261102",
                    "ackType": "AC",
                    "seller": { "name": "KEYSTONE SUPPLY LLC", "id": "KEYSTONE01" },
                    "lineItems": [
                        { "lineNumber": 1, "quantity": 100, "uom": "EA", "unitPrice": 15.00, "itemCode": "ITEM-101", "ackCode": "IA", "scheduleDate": "20261110" }
                    ]
                };

                var mapper = new app.transform.templates.OrdersJson_To_X12_855();
                var ast855 = mapper.transform(canonicalOrder);

                var serializer = new app.parsers.x12.X12Serializer();
                var wireEdi = serializer.serialize(ast855);

                s.assertTrue(find("ST*855*", wireEdi) > 0);
                s.assertTrue(find("BAK*00*AC*PO-99120*", wireEdi) > 0);
                s.assertTrue(find("PO1*1*100*EA*15", wireEdi) > 0);
                s.assertTrue(find("SE*", wireEdi) > 0);
            });

        });
    }

}
