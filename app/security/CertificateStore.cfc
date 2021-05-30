component {

    property name="certDir" type="string";
    property name="logger" type="any";
    property name="certificates" type="struct";
    property name="privateKeys" type="struct";

    /**
     * Constructor for CertificateStore.
     */
    public any function init(required string certDir, required any logger) {
        variables.certDir = arguments.certDir;
        variables.logger = arguments.logger;
        variables.certificates = {};
        variables.privateKeys = {};

        if (!directoryExists(variables.certDir)) {
            directoryCreate(variables.certDir);
        }

        loadCertificates();
        return this;
    }

    /**
     * Generates a 2048-bit RSA keypair and self-signed certificate for local development/testing.
     */
    public struct function generateRsaKeyPair(numeric keySize = 2048) {
        var keyGen = createObject("java", "java.security.KeyPairGenerator").getInstance("RSA");
        keyGen.initialize(javaCast("int", arguments.keySize));
        var keyPair = keyGen.generateKeyPair();

        var pubKey = keyPair.getPublic();
        var privKey = keyPair.getPrivate();

        var encoder = createObject("java", "java.util.Base64").getEncoder();
        var pubPem = "-----BEGIN PUBLIC KEY-----" & chr(10) & encoder.encodeToString(pubKey.getEncoded()) & chr(10) & "-----END PUBLIC KEY-----";
        var privPem = "-----BEGIN PRIVATE KEY-----" & chr(10) & encoder.encodeToString(privKey.getEncoded()) & chr(10) & "-----END PRIVATE KEY-----";

        return {
            "publicKey": pubKey,
            "privateKey": privKey,
            "publicKeyPem": pubPem,
            "privateKeyPem": privPem,
            "algorithm": pubKey.getAlgorithm(),
            "format": pubKey.getFormat()
        };
    }

    /**
     * Registers an in-memory certificate for a partner or local gateway.
     */
    public void function registerCertificate(required string alias, required string pemContent) {
        var cleanPem = arguments.pemContent;
        variables.certificates[lcase(arguments.alias)] = {
            "alias": arguments.alias,
            "pem": cleanPem,
            "fingerprint": calculateFingerprint(cleanPem)
        };
    }

    public struct function getCertificate(required string alias) {
        var k = lcase(trim(arguments.alias));
        return structKeyExists(variables.certificates, k) ? variables.certificates[k] : {};
    }

    public boolean function hasCertificate(required string alias) {
        return structKeyExists(variables.certificates, lcase(trim(arguments.alias)));
    }

    public string function calculateFingerprint(required string text) {
        var digest = createObject("java", "java.security.MessageDigest").getInstance("SHA-256");
        var hashBytes = digest.digest(arguments.text.getBytes("UTF-8"));
        var sb = createObject("java", "java.lang.StringBuilder").init();
        for (var b in hashBytes) {
            var hex = formatBaseN(bitAnd(b, 255), 16);
            if (len(hex) == 1) sb.append("0");
            sb.append(ucase(hex));
        }
        return sb.toString();
    }

    private void function loadCertificates() {
        // Read any existing PEM files from disk
        var files = directoryList(variables.certDir, false, "query", "*.pem");
        for (var row in files) {
            var alias = replace(row.name, ".pem", "", "all");
            var content = fileRead(variables.certDir & "/" & row.name, "utf-8");
            registerCertificate(alias, content);
        }
    }
}
