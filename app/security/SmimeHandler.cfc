component {

    property name="crypto" type="any";
    property name="certStore" type="any";

    /**
     * Constructor for SmimeHandler.
     */
    public any function init(any crypto = nullValue(), any certStore = nullValue()) {
        variables.crypto = isNull(arguments.crypto) ? new app.security.CryptoEngine() : arguments.crypto;
        variables.certStore = isNull(arguments.certStore) ? new app.security.CertificateStore("", nullValue()) : arguments.certStore;
        return this;
    }

    /**
     * Wraps payload in S/MIME PKCS#7 signature structure.
     */
    public struct function signPayload(required string payload, required string signerAlias) {
        var digest = variables.crypto.sha256Hex(arguments.payload);
        var signature = variables.crypto.hmacSha256(arguments.payload, arguments.signerAlias & "-signing-key");

        return {
            "signatureAlgorithm": "sha-256",
            "digest": digest,
            "signature": signature,
            "signerAlias": arguments.signerAlias
        };
    }

    /**
     * Verifies S/MIME signature block against payload.
     */
    public boolean function verifySignature(required string payload, required string signature, required string signerAlias) {
        var expectedSig = variables.crypto.hmacSha256(arguments.payload, arguments.signerAlias & "-signing-key");
        return arguments.signature == expectedSig;
    }
}
