component {

    property name="masterKeySpec" type="any";

    /**
     * Constructor for CryptoEngine.
     *
     * @masterSecret 32-byte or passphrase secret key
     */
    public any function init(string masterSecret = "keystone-production-vault-secret-key-salt-32b") {
        var digest = createObject("java", "java.security.MessageDigest").getInstance("SHA-256");
        var keyBytes = digest.digest(arguments.masterSecret.getBytes("UTF-8"));
        variables.masterKeySpec = createObject("java", "javax.crypto.spec.SecretKeySpec").init(keyBytes, "AES");
        return this;
    }

    /**
     * Encrypts plaintext string using AES-256-GCM with authenticated tag.
     * Output format: base64(iv[12 bytes] + ciphertext + tag[16 bytes])
     */
    public string function encryptGcm(required string plaintext, string additionalData = "") {
        var secureRandom = createObject("java", "java.security.SecureRandom").init();
        var iv = javaCast("byte[]", secureRandom.generateSeed(12)); // 96-bit IV

        var cipher = createObject("java", "javax.crypto.Cipher").getInstance("AES/GCM/NoPadding");
        var gcmSpec = createObject("java", "javax.crypto.spec.GCMParameterSpec").init(128, iv);
        cipher.init(1, variables.masterKeySpec, gcmSpec); // 1 = ENCRYPT_MODE

        if (len(arguments.additionalData) > 0) {
            cipher.updateAAD(arguments.additionalData.getBytes("UTF-8"));
        }

        var cipherTextBytes = cipher.doFinal(arguments.plaintext.getBytes("UTF-8"));

        // Combine IV + Ciphertext
        var combined = createObject("java", "java.io.ByteArrayOutputStream").init();
        combined.write(iv);
        combined.write(cipherTextBytes);

        var encoder = createObject("java", "java.util.Base64").getEncoder();
        return encoder.encodeToString(combined.toByteArray());
    }

    /**
     * Decrypts AES-256-GCM encrypted base64 payload.
     */
    public string function decryptGcm(required string base64Payload, string additionalData = "") {
        var decoder = createObject("java", "java.util.Base64").getDecoder();
        var rawBytes = decoder.decode(arguments.base64Payload);

        if (arrayLen(rawBytes) < 28) {
            throw(type="InvalidPayloadException", message="Encrypted payload is shorter than IV + GCM tag header.");
        }

        var bais = createObject("java", "java.io.ByteArrayInputStream").init(rawBytes);
        var iv = javaCast("byte[]", createObject("java", "java.lang.reflect.Array").newInstance(javaCast("byte", 0).getClass(), 12));
        bais.read(iv, 0, 12);

        var cipherBytesLen = arrayLen(rawBytes) - 12;
        var cipherBytes = javaCast("byte[]", createObject("java", "java.lang.reflect.Array").newInstance(javaCast("byte", 0).getClass(), cipherBytesLen));
        bais.read(cipherBytes, 0, cipherBytesLen);

        var cipher = createObject("java", "javax.crypto.Cipher").getInstance("AES/GCM/NoPadding");
        var gcmSpec = createObject("java", "javax.crypto.spec.GCMParameterSpec").init(128, iv);
        cipher.init(2, variables.masterKeySpec, gcmSpec); // 2 = DECRYPT_MODE

        if (len(arguments.additionalData) > 0) {
            cipher.updateAAD(arguments.additionalData.getBytes("UTF-8"));
        }

        var plainBytes = cipher.doFinal(cipherBytes);
        return createObject("java", "java.lang.String").init(plainBytes, "UTF-8");
    }

    /**
     * Computes SHA-256 hexadecimal hash digest.
     */
    public string function sha256Hex(required string input) {
        var digest = createObject("java", "java.security.MessageDigest").getInstance("SHA-256");
        var hashBytes = digest.digest(arguments.input.getBytes("UTF-8"));
        return bytesToHex(hashBytes);
    }

    /**
     * Computes SHA-256 base64 digest.
     */
    public string function sha256Base64(required string input) {
        var digest = createObject("java", "java.security.MessageDigest").getInstance("SHA-256");
        var hashBytes = digest.digest(arguments.input.getBytes("UTF-8"));
        return createObject("java", "java.util.Base64").getEncoder().encodeToString(hashBytes);
    }

    /**
     * Computes HMAC-SHA256 signature for webhooks or AS2 authentication.
     */
    public string function hmacSha256(required string input, required string secretKey) {
        var mac = createObject("java", "javax.crypto.Mac").getInstance("HmacSHA256");
        var keySpec = createObject("java", "javax.crypto.spec.SecretKeySpec").init(arguments.secretKey.getBytes("UTF-8"), "HmacSHA256");
        mac.init(keySpec);
        var signatureBytes = mac.doFinal(arguments.input.getBytes("UTF-8"));
        return bytesToHex(signatureBytes);
    }

    private string function bytesToHex(required any bytes) {
        var sb = createObject("java", "java.lang.StringBuilder").init();
        for (var b in arguments.bytes) {
            var hex = formatBaseN(bitAnd(b, 255), 16);
            if (len(hex) == 1) sb.append("0");
            sb.append(lcase(hex));
        }
        return sb.toString();
    }
}
