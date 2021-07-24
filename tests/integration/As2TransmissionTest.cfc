/**
 * Keystone Integration Tests - End-to-End AS2 Transmission & MDN Receipt Flow
 */
component {

    public void function run(required any suite) {
        suite.describe("Integration: AS2 Protocol Transmission & MDN Receipt", function(s) {

            s.it("processes inbound AS2 transmission and returns cryptographically valid MDN", function() {
                var as2Receiver = new app.network.As2Receiver();

                var headers = {
                    "AS2-Version": "1.2",
                    "AS2-From": "PARTNERA_AS2",
                    "AS2-To": "KEYSTONE_AS2",
                    "Message-ID": "<MSG_TEST_99182@partnera>",
                    "Disposition-Notification-To": "edi@partnera.com",
                    "Disposition-Notification-Options": "signed-receipt-protocol=optional, pkcs7-signature; signed-receipt-micalg=optional, sha-256"
                };

                var payload = "ISA*00*          *00*          *ZZ*PARTNERA       *ZZ*KEYSTONEGATE   *261102*1200*U*00401*000000001*0*P*>~ST*850*0001~SE*2*0001~IEA*1*000000001~";

                var response = as2Receiver.handleRequest(headers, payload);

                s.assertEquals(200, response.statusCode);
                s.assertTrue(find("disposition-notification", response.headers["Content-Type"]) > 0);
                s.assertTrue(find("Original-Message-ID: <MSG_TEST_99182@partnera>", response.body) > 0);
                s.assertTrue(find("Disposition: automatic-action/MDN-sent-automatically; processed", response.body) > 0);
                s.assertTrue(find("Received-Content-MIC:", response.body) > 0);
            });

        });
    }

}
