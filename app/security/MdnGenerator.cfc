component {

    property name="micCalculator" type="any";

    /**
     * Constructor for MdnGenerator.
     */
    public any function init(any micCalculator = nullValue()) {
        variables.micCalculator = isNull(arguments.micCalculator) ? new app.security.MicCalculator() : arguments.micCalculator;
        return this;
    }

    /**
     * Generates an RFC 4130 multipart/report Message Disposition Notification (MDN).
     */
    public struct function generateMdn(
        required string originalMessageId,
        required string as2From,
        required string as2To,
        string payload = "",
        string micAlgorithm = "sha-256",
        boolean isSuccess = true,
        string errorMessage = "",
        string mic = "",
        string status = "processed"
    ) {
        var calculatedMic = len(trim(arguments.mic)) ? arguments.mic : (len(trim(arguments.payload)) ? variables.micCalculator.calculateMic(arguments.payload, arguments.micAlgorithm) : "");
        var boundary = "----=_Part_" & createUUID() & "_KeystoneMDN";
        var mdnMessageId = "<keystone-mdn-" & createUUID() & "@keystone.local>";

        var disposition = (arguments.isSuccess && arguments.status == "processed") ?
            "automatic-action/MDN-sent-automatically; processed" :
            "automatic-action/MDN-sent-automatically; failed/error: " & arguments.errorMessage;

        var sb = createObject("java", "java.lang.StringBuilder").init();
        var crlf = chr(13) & chr(10);

        // MIME preamble
        sb.append("This is an RFC 4130 Message Disposition Notification sent by Keystone AS2 Gateway.").append(crlf).append(crlf);

        // Part 1: Human-readable text report
        sb.append("--").append(boundary).append(crlf);
        sb.append("Content-Type: text/plain; charset=us-ascii").append(crlf);
        sb.append("Content-Transfer-Encoding: 7bit").append(crlf).append(crlf);

        if (arguments.isSuccess) {
            sb.append("The AS2 message with ID [").append(arguments.originalMessageId).append("] was successfully received, parsed, and verified.").append(crlf);
            sb.append("Message Integrity Check (MIC): ").append(calculatedMic).append(crlf);
        } else {
            sb.append("The AS2 message with ID [").append(arguments.originalMessageId).append("] failed processing: ").append(arguments.errorMessage).append(crlf);
        }
        sb.append(crlf);

        // Part 2: Machine-readable disposition notification headers
        sb.append("--").append(boundary).append(crlf);
        sb.append("Content-Type: message/disposition-notification").append(crlf);
        sb.append("Content-Transfer-Encoding: 7bit").append(crlf).append(crlf);

        sb.append("Reporting-UA: Keystone-AS2-Gateway/1.0").append(crlf);
        sb.append("Original-Recipient: rfc822; ").append(arguments.as2To).append(crlf);
        sb.append("Final-Recipient: rfc822; ").append(arguments.as2To).append(crlf);
        sb.append("Original-Message-ID: ").append(arguments.originalMessageId).append(crlf);
        sb.append("Disposition: ").append(disposition).append(crlf);
        if (arguments.isSuccess) {
            sb.append("Received-Content-MIC: ").append(calculatedMic).append(crlf);
        }
        sb.append(crlf);

        // Closing boundary
        sb.append("--").append(boundary).append("--").append(crlf);

        var headers = {
            "AS2-Version": "1.2",
            "AS2-From": arguments.as2To,
            "AS2-To": arguments.as2From,
            "Message-ID": mdnMessageId,
            "Date": dateTimeFormat(now(), "EEE, dd MMM yyyy HH:nn:ss 'GMT'"),
            "Content-Type": 'multipart/report; report-type=disposition-notification; boundary="' & boundary & '"',
            "Connection": "close"
        };

        return {
            "messageId": mdnMessageId,
            "boundary": boundary,
            "mic": mic,
            "headers": headers,
            "body": sb.toString(),
            "isSuccess": arguments.isSuccess
        };
    }
}
