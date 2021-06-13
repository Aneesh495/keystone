component {

    public void function run(required any suite) {
        var baseDir = getDirectoryFromPath(getCurrentTemplatePath()) & "../../../";

        suite.describe("Security: CryptoEngine AES-256-GCM & Hashes", function(s) {
            s.it("encrypts and decrypts payloads authenticated with AES-GCM", function() {
                var crypto = new app.security.CryptoEngine("secret-vault-master-key-32b");
                var plaintext = "CONFIDENTIAL_FINANCIAL_PAYLOAD_100234";
                var aad = "partner_tenant_01";

                var encrypted = crypto.encryptGcm(plaintext, aad);
                s.assertTrue(len(encrypted) > 0);
                s.assertTrue(encrypted != plaintext);

                var decrypted = crypto.decryptGcm(encrypted, aad);
                s.assertEquals(plaintext, decrypted);
            });

            s.it("computes SHA-256 and HMAC-SHA256 digests accurately", function() {
                var crypto = new app.security.CryptoEngine();
                var text = "Hello Keystone Gateway";
                var shaHex = crypto.sha256Hex(text);
                s.assertEquals(64, len(shaHex));

                var hmac = crypto.hmacSha256(text, "api-secret-key");
                s.assertEquals(64, len(hmac));
            });
        });

        suite.describe("Security: CertificateStore & Key Management", function(s) {
            s.it("generates 2048-bit RSA keypair with valid PEM formatting", function() {
                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                var logger = new app.core.Logger(config = config, logDir = baseDir & "logs");
                var store = new app.security.CertificateStore(certDir = baseDir & "storage/certs", logger = logger);

                var keyPair = store.generateRsaKeyPair(2048);
                s.assertTrue(findNoCase("-----BEGIN PUBLIC KEY-----", keyPair.publicKeyPem) == 1);
                s.assertTrue(findNoCase("-----BEGIN PRIVATE KEY-----", keyPair.privateKeyPem) == 1);
                s.assertEquals("RSA", keyPair.algorithm);
            });
        });

        suite.describe("Security: AS2 & MDN Generation", function(s) {
            s.it("calculates RFC 4130 MIC and generates signed MDN receipt", function() {
                var micCalc = new app.security.MicCalculator();
                var payload = "ISA*00*...~";
                var mic = micCalc.calculateMic(payload, "sha-256");
                s.assertTrue(findNoCase(", sha-256", mic) > 0);
                s.assertTrue(micCalc.verifyMic(payload, mic));

                var mdnGen = new app.security.MdnGenerator(micCalc);
                var mdn = mdnGen.generateMdn(
                    originalMessageId = "<msg-101@partner.com>",
                    as2From = "PARTNER_CORP",
                    as2To = "KEYSTONE",
                    payload = payload
                );

                s.assertTrue(mdn.isSuccess);
                s.assertTrue(findNoCase("multipart/report", mdn.headers["Content-Type"]) > 0);
                s.assertTrue(findNoCase("Received-Content-MIC: " & mic, mdn.body) > 0);
                s.assertTrue(findNoCase("Disposition: automatic-action/MDN-sent-automatically; processed", mdn.body) > 0);
            });

            s.it("processes inbound AS2 transmission through As2Engine", function() {
                var as2Engine = new app.security.As2Engine();
                var headers = {
                    "AS2-From": "ACME_SUPPLY",
                    "AS2-To": "KEYSTONE_GW",
                    "Message-ID": "<order-776655@acme.com>",
                    "AS2-Version": "1.2"
                };
                var body = "ST*850*0001~BEG*00*SA*PO-1~SE*2*0001~";

                var outcome = as2Engine.processInbound(headers, body);
                s.assertTrue(outcome.isSuccess);
                s.assertEquals("ACME_SUPPLY", outcome.as2From);
                s.assertEquals("<order-776655@acme.com>", outcome.messageId);
                s.assertTrue(structKeyExists(outcome, "mdn"));
            });
        });

        suite.describe("Security: Merkle AuditLedger", function(s) {
            s.it("appends blocks with SHA-256 hash chaining and verifies chain integrity", function() {
                var testAuditDir = baseDir & "storage/audit_test_" & createUUID();
                if (directoryExists(testAuditDir)) directoryDelete(testAuditDir, true);
                directoryCreate(testAuditDir);

                var config = new app.core.Config(rootDir = baseDir);
                config.load();
                var logger = new app.core.Logger(config = config, logDir = baseDir & "logs");
                var crypto = new app.security.CryptoEngine();
                var ledger = new app.security.AuditLedger(storageDir = testAuditDir, crypto = crypto, logger = logger);

                // Add 3 transaction blocks
                var b1 = ledger.recordTransaction("TX-001", "PARTNER_A", "INBOUND", "X12", "ISA*00*...~", "mic1");
                var b2 = ledger.recordTransaction("TX-002", "PARTNER_B", "OUTBOUND", "EDIFACT", "UNB+...'", "mic2");
                var b3 = ledger.recordTransaction("TX-003", "PARTNER_C", "INBOUND", "HL7", "MSH|...~", "mic3");

                s.assertEquals(1, b1.blockIndex);
                s.assertEquals(2, b2.blockIndex);
                s.assertEquals(3, b3.blockIndex);

                // Check chaining
                s.assertEquals(b1.blockHash, b2.previousBlockHash);
                s.assertEquals(b2.blockHash, b3.previousBlockHash);

                // Verify chain integrity
                var verifyRes = ledger.verifyChain();
                s.assertTrue(verifyRes.isValid);
                s.assertTrue(verifyRes.verifiedBlocks >= 3);

                // Cleanup
                try { directoryDelete(testAuditDir, true); } catch (any e) {}
            });
        });
    }
}
