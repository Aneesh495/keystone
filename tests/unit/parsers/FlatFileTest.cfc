component {

    public void function run(required any suite) {
        var sampleFixedWidth = "ORD1001   ACME LOGISTICS      20261102    450.50" & chr(10) &
            "ORD1002   GLOBAL FREIGHT      20261103   1280.00" & chr(10);

        var sampleCsv = 'orderId,customer,status,notes' & chr(10) &
            'ORD-991,"Apex Corp, LLC",PENDING,"Standard order"' & chr(10) &
            'ORD-992,"Beta Industries",CONFIRMED,"Note with ""quoted"" text and, comma"' & chr(10);

        suite.describe("FlatFile: Fixed-Width Positional Parser", function(s) {
            s.it("parses positional fixed-width lines into records based on column schema", function() {
                var schema = [
                    {"name": "orderId", "start": 1, "length": 10},
                    {"name": "customer", "start": 11, "length": 20},
                    {"name": "date", "start": 31, "length": 8},
                    {"name": "amount", "start": 41, "length": 10}
                ];

                var parser = new app.parsers.flatfile.FixedWidthParser();
                var res = parser.parse(sampleFixedWidth, {"schema": schema});

                s.assertTrue(res.isSuccess());
                var records = res.getAst().records;
                s.assertEquals(2, arrayLen(records));

                s.assertEquals("ORD1001", records[1].orderId);
                s.assertEquals("ACME LOGISTICS", records[1].customer);
                s.assertEquals("20261102", records[1].date);
                s.assertEquals("450.50", records[1].amount);
            });

            s.it("serializes records to aligned fixed-width lines", function() {
                var schema = [
                    {"name": "code", "start": 1, "length": 5, "align": "left"},
                    {"name": "val", "start": 6, "length": 8, "align": "right", "padChar": "0"}
                ];

                var serializer = new app.parsers.flatfile.FixedWidthSerializer();
                var ast = {
                    "records": [
                        {"code": "ABC", "val": "1250"}
                    ]
                };

                var line = serializer.serialize(ast, {"schema": schema});
                s.assertEquals("ABC  00001250" & chr(10), line);
            });
        });

        suite.describe("FlatFile: RFC 4180 CSV Parser", function(s) {
            s.it("parses CSV with quoted commas and escaped quotes", function() {
                var parser = new app.parsers.flatfile.CsvParser();
                var res = parser.parse(sampleCsv);

                s.assertTrue(res.isSuccess());
                var records = res.getAst().records;
                s.assertEquals(2, arrayLen(records));

                s.assertEquals("ORD-991", records[1].orderId);
                s.assertEquals("Apex Corp, LLC", records[1].customer);

                s.assertEquals('Note with "quoted" text and, comma', records[2].notes);
            });

            s.it("serializes records back to RFC 4180 CSV escaping cells properly", function() {
                var serializer = new app.parsers.flatfile.CsvSerializer();
                var ast = {
                    "headers": ["id", "description"],
                    "records": [
                        {"id": "1", "description": "Simple"},
                        {"id": "2", "description": "Has, comma and ""quotes"""}
                    ]
                };

                var csvOut = serializer.serialize(ast);
                s.assertTrue(findNoCase('id,description', csvOut) == 1);
                s.assertTrue(findNoCase('"Has, comma and ""quotes"""', csvOut) > 0);
            });
        });
    }
}
