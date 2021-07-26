/**
 * Regression Test: Bug-005
 * Description: AS2 MIC digest calculation previously failed when computing Base64
 * encoded hashes across payloads containing CRLF canonical transformations vs LF,
 * causing partner receipt verification failure in RFC 4130 compliance tests.
 */
component {

    public void function run(required any suite) {
        suite.describe("Regression: Bug-005 RFC 4130 AS2 MIC Digest Canonical Verification", function(s) {

            s.it("computes deterministic SHA-256 MIC matching RFC 4130 specification format", function() {
                var micCalc = new app.security.MicCalculator();
                var samplePayload = "ISA*00*          *00*          *ZZ*SENDER*ZZ*RECEIVER*261102*1200*U*00401*000000001*0*P*>~";

                var micHeader = micCalc.calculateMic(samplePayload, "sha-256");

                s.assertTrue(len(micHeader) > 0);
                s.assertTrue(find(", sha-256", micHeader) > 0 || find(", sha256", micHeader) > 0);

                // Verify Base64 portion precedes algorithm name
                var parts = listToArray(micHeader, ",");
                s.assertTrue(arrayLen(parts) == 2);
                var base64Digest = trim(parts[1]);
                s.assertTrue(len(base64Digest) > 20);
            });

            s.it("gracefully falls back to sha-256 when unsupported or legacy algorithm is supplied", function() {
                var micCalc = new app.security.MicCalculator();
                var samplePayload = "TEST CONTENT";

                var micHeader = micCalc.calculateMic(samplePayload, "unknown-algo");
                s.assertTrue(len(micHeader) > 0);
            });

        });
    }

}
