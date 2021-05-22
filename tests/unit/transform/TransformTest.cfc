component {

    public void function run(required any suite) {
        suite.describe("Transform: ExpressionEngine", function(s) {
            s.it("evaluates arithmetic, concatenation, and ternary expressions", function() {
                var engine = new app.transform.ExpressionEngine();
                var ctx = {
                    "item": {"qty": 10, "price": 12.50, "sku": "SKU-99"},
                    "user": {"tier": "GOLD", "active": true}
                };

                // Arithmetic
                s.assertEquals(125, engine.evaluate("item.qty * item.price", ctx));
                // Functions
                s.assertEquals("SKU-99", engine.evaluate("uppercase(item.sku)", ctx));
                // Ternary
                s.assertEquals("VIP_DISCOUNT", engine.evaluate("user.tier == 'GOLD' ? 'VIP_DISCOUNT' : 'STANDARD'", ctx));
            });

            s.it("handles nested array and dot-notation paths", function() {
                var engine = new app.transform.ExpressionEngine();
                var ctx = {
                    "order": {
                        "lines": [
                            {"id": "L1", "amount": 100},
                            {"id": "L2", "amount": 250}
                        ]
                    }
                };
                s.assertEquals("L1", engine.evaluate("order.lines[1].id", ctx));
                s.assertEquals(250, engine.evaluate("order.lines[2].amount", ctx));
            });
        });

        suite.describe("Transform: ValueTransforms & CodeLookup", function(s) {
            s.it("converts dates and currencies with precision", function() {
                var vt = new app.transform.ValueTransforms();
                s.assertEquals("2026-11-02", vt.toIsoDate("20261102"));
                s.assertEquals("20261102", vt.toX12Date("2026-11-02"));
                s.assertEquals("25.50", vt.centsToDollars(2550));
                s.assertEquals(2550, vt.dollarsToCents(25.50));
                s.assertEquals("00042", vt.padLeft("42", 5, "0"));
                s.assertEquals("Each", vt.mapUom("EA"));
            });

            s.it("resolves bidirectional code lookup tables", function() {
                var lookup = new app.transform.CodeLookupTable();
                s.assertEquals("United Parcel Service", lookup.lookup("carrier_scac", "UPSN"));
                s.assertEquals("UPSN", lookup.reverseLookup("carrier_scac", "United Parcel Service"));
                s.assertEquals("DEFAULT_CARRIER", lookup.lookup("carrier_scac", "UNKNOWN_SCAC", "DEFAULT_CARRIER"));
            });
        });

        suite.describe("Transform: Production X12 850 to Canonical JSON", function(s) {
            s.it("transforms parsed X12 850 AST into rich Canonical Orders model", function() {
                var sample850 = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *261102*1200*^*00501*000000001*0*T*:~" &
                    "GS*PO*SENDER*RECEIVER*20261102*1200*1*X*005010~" &
                    "ST*850*0001~" &
                    "BEG*00*SA*PO-ALPHA-77**20261102~" &
                    "CUR*BY*USD~" &
                    "N1*ST*WEST COAST DEPOT*92*DEPOT-09~" &
                    "N3*500 OCEAN VIEW AVE~" &
                    "N4*SEATTLE*WA*98101*US~" &
                    "PO1*1*20*EA*50.00**VN*SKU-MOTOR-1~" &
                    "PID*F****SERVO MOTOR ACTUATOR~" &
                    "PO1*2*10*EA*150.00**VN*SKU-SENSOR-2~" &
                    "PID*F****OPTICAL PROXIMITY SENSOR~" &
                    "CTT*2*30~" &
                    "SE*13*0001~" &
                    "GE*1*1~" &
                    "IEA*1*000000001~";

                var parser = new app.parsers.x12.X12Parser();
                var parseRes = parser.parse(sample850);

                var template = new app.transform.templates.X12_850_To_OrdersJson();
                var order = template.transform(parseRes.getAst());

                s.assertEquals("PO-ALPHA-77", order.orderNumber);
                s.assertEquals("2026-11-02", order.orderDate);
                s.assertEquals("USD", order.currency);
                s.assertEquals("WEST COAST DEPOT", order.shipTo.name);
                s.assertEquals("SEATTLE", order.shipTo.city);

                s.assertEquals(2, arrayLen(order.items));
                s.assertEquals("SKU-MOTOR-1", order.items[1].sku);
                s.assertEquals(20, order.items[1].quantity);
                s.assertEquals("Each", order.items[1].unitOfMeasure);
                s.assertEquals(1000.0, order.items[1].lineTotal);

                s.assertEquals(30, order.summary.totalQuantity);
                s.assertEquals(2500.0, order.summary.orderTotal);
            });
        });
    }
}
