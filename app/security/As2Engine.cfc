component {

    property name="micCalculator" type="any";
    property name="mdnGenerator" type="any";
    property name="crypto" type="any";
    property name="logger" type="any";

    /**
     * Constructor for As2Engine.
     */
    public any function init(
        any micCalculator = nullValue(),
        any mdnGenerator = nullValue(),
        any crypto = nullValue(),
        any logger = nullValue()
    ) {
        variables.micCalculator = isNull(arguments.micCalculator) ? new app.security.MicCalculator() : arguments.micCalculator;
        variables.mdnGenerator = isNull(arguments.mdnGenerator) ? new app.security.MdnGenerator(variables.micCalculator) : arguments.mdnGenerator;
        variables.crypto = isNull(arguments.crypto) ? new app.security.CryptoEngine() : arguments.crypto;
        variables.logger = arguments.logger;
        return this;
    }

    /**
     * Processes an inbound AS2 HTTP transmission.
     *
     * @headers HTTP headers struct
     * @body Raw HTTP request body string
     * @return Struct containing parsed payload, verification status, and MDN receipt
     */
    public struct function processInbound(required struct headers, required string body) {
        var normalizedHeaders = {};
        for (var h in arguments.headers) {
            normalizedHeaders[lcase(h)] = arguments.headers[h];
        }

        var as2From = normalizedHeaders["as2-from"] ?: "";
        var as2To = normalizedHeaders["as2-to"] ?: "";
        var messageId = normalizedHeaders["message-id"] ?: "";
        var as2Version = normalizedHeaders["as2-version"] ?: "1.0";
        var dispositionTo = normalizedHeaders["disposition-notification-to"] ?: "";
        var micOptions = normalizedHeaders["disposition-notification-options"] ?: "signed-receipt-protocol=optional, pkcs7-signature; signed-receipt-micalg=optional, sha-256";

        var errors = [];
        if (len(trim(as2From)) == 0) arrayAppend(errors, "Missing mandatory AS2-From header");
        if (len(trim(as2To)) == 0) arrayAppend(errors, "Missing mandatory AS2-To header");
        if (len(trim(messageId)) == 0) arrayAppend(errors, "Missing mandatory Message-ID header");

        var isSuccess = (arrayLen(errors) == 0);
        var errMsg = arrayToList(errors, "; ");

        var micAlg = "sha-256";
        if (findNoCase("sha-1", micOptions) > 0) micAlg = "sha-1";

        // Generate MDN receipt
        var mdnReceipt = variables.mdnGenerator.generateMdn(
            originalMessageId = messageId,
            as2From = as2From,
            as2To = as2To,
            payload = arguments.body,
            micAlgorithm = micAlg,
            isSuccess = isSuccess,
            errorMessage = errMsg
        );

        return {
            "isSuccess": isSuccess,
            "errors": errors,
            "as2From": as2From,
            "as2To": as2To,
            "messageId": messageId,
            "payload": arguments.body,
            "mic": mdnReceipt.mic,
            "mdn": mdnReceipt
        };
    }

    /**
     * Packages an outbound AS2 transmission with necessary headers.
     */
    public struct function buildOutbound(
        required string as2From,
        required string as2To,
        required string payload,
        string micAlgorithm = "sha-256"
    ) {
        var msgId = "<keystone-as2-" & createUUID() & "@keystone.local>";
        var mic = variables.micCalculator.calculateMic(arguments.payload, arguments.micAlgorithm);

        var headers = {
            "AS2-Version": "1.2",
            "AS2-From": arguments.as2From,
            "AS2-To": arguments.as2To,
            "Message-ID": msgId,
            "Date": dateTimeFormat(now(), "EEE, dd MMM yyyy HH:nn:ss 'GMT'"),
            "Content-Type": "application/edi-x12",
            "Disposition-Notification-To": arguments.as2From,
            "Disposition-Notification-Options": "signed-receipt-protocol=optional, pkcs7-signature; signed-receipt-micalg=optional, " & arguments.micAlgorithm
        };

        return {
            "messageId": msgId,
            "headers": headers,
            "payload": arguments.payload,
            "mic": mic
        };
    }
}
