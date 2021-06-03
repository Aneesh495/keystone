component {

    /**
     * Constructor for MicCalculator.
     */
    public any function init() {
        return this;
    }

    /**
     * Calculates RFC 4130 Message Integrity Check (MIC) over binary or string payload.
     * Format: <base64_digest>, <mic_algorithm>
     *
     * @payload The canonical data payload
     * @algorithm Hash algorithm (sha-256, sha-1, sha-384, sha-512)
     */
    public string function calculateMic(required string payload, string algorithm = "sha-256") {
        var jAlg = "SHA-256";
        var normAlg = lcase(trim(arguments.algorithm));

        switch (normAlg) {
            case "sha-256": case "sha256": jAlg = "SHA-256"; normAlg = "sha-256"; break;
            case "sha-1": case "sha1": jAlg = "SHA-1"; normAlg = "sha-1"; break;
            case "sha-384": case "sha384": jAlg = "SHA-384"; normAlg = "sha-384"; break;
            case "sha-512": case "sha512": jAlg = "SHA-512"; normAlg = "sha-512"; break;
            default: jAlg = "SHA-256"; normAlg = "sha-256"; break;
        }

        var digest = createObject("java", "java.security.MessageDigest").getInstance(jAlg);
        var hashBytes = digest.digest(arguments.payload.getBytes("UTF-8"));
        var base64Digest = createObject("java", "java.util.Base64").getEncoder().encodeToString(hashBytes);

        return base64Digest & ", " & normAlg;
    }

    /**
     * Verifies that a received MIC matches the expected calculated MIC.
     */
    public boolean function verifyMic(required string payload, required string expectedMic) {
        var parts = listToArray(arguments.expectedMic, ",");
        if (arrayLen(parts) < 2) return false;

        var expectedDigest = trim(parts[1]);
        var alg = trim(parts[2]);

        var calculated = calculateMic(arguments.payload, alg);
        var calculatedDigest = trim(listFirst(calculated, ","));

        return expectedDigest == calculatedDigest;
    }
}
