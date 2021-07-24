/**
 * Keystone B2B Transaction Mesh - AS2 Protocol Receiver
 *
 * Implements RFC 4130 AS2 endpoint processing: validates AS2 headers, unpacks S/MIME,
 * verifies digital signatures, computes MIC checksums, and renders signed MDN receipts.
 */
component {

    property name="as2Engine" type="any";
    property name="partnerRegistry" type="any";
    property name="idempotencyStore" type="any";
    property name="logger" type="any";
    property name="eventBus" type="any";

    /**
     * Initializes the As2Receiver.
     */
    public any function init(
        any as2Engine = "",
        any partnerRegistry = "",
        any idempotencyStore = "",
        any logger = "",
        any eventBus = ""
    ) {
        variables.as2Engine = arguments.as2Engine;
        variables.partnerRegistry = arguments.partnerRegistry;
        variables.idempotencyStore = arguments.idempotencyStore;
        variables.logger = arguments.logger;
        variables.eventBus = arguments.eventBus;

        return this;
    }

    /**
     * Processes an inbound AS2 HTTP POST request.
     *
     * @headers Struct of HTTP request headers
     * @rawBody Raw request payload string or binary
     * @return Struct { "statusCode": numeric, "headers": struct, "mdn": string, "payload": string }
     */
    public struct function handleRequest(required struct headers, required any rawBody) {
        var as2From = getHeader(arguments.headers, "as2-from");
        var as2To = getHeader(arguments.headers, "as2-to");
        var messageId = getHeader(arguments.headers, "message-id");
        var dispositionNotificationTo = getHeader(arguments.headers, "disposition-notification-to");
        var dispositionNotificationOptions = getHeader(arguments.headers, "disposition-notification-options");

        if (len(trim(as2From)) == 0 || len(trim(as2To)) == 0 || len(trim(messageId)) == 0) {
            return {
                "statusCode": 400,
                "headers": { "Content-Type": "text/plain" },
                "body": "Missing required AS2 transmission headers: AS2-From, AS2-To, or Message-ID"
            };
        }

        // Enforce idempotency if store is present
        if (isObject(variables.idempotencyStore)) {
            var idemKey = "AS2_" & as2From & "_" & messageId;
            var lease = variables.idempotencyStore.tryAcquire(idemKey);
            if (!lease.acquired && lease.status == "COMPLETED") {
                return {
                    "statusCode": 200,
                    "headers": { "Content-Type": "multipart/report; report-type=disposition-notification" },
                    "body": isSimpleValue(lease.cachedResult) ? lease.cachedResult : serializeJson(lease.cachedResult)
                };
            }
        }

        if (isObject(variables.eventBus)) {
            variables.eventBus.publish("as2.received", {
                "from": as2From,
                "to": as2To,
                "messageId": messageId
            });
        }

        // Process message via AS2 engine if configured
        var processedPayload = arguments.rawBody;
        var mic = "";
        var micAlg = "sha-256";

        if (len(trim(dispositionNotificationOptions)) > 0 && findNoCase("sha1", dispositionNotificationOptions)) {
            micAlg = "sha-1";
        }

        if (isObject(variables.as2Engine)) {
            var unpackResult = variables.as2Engine.unpackMessage(arguments.rawBody, arguments.headers);
            processedPayload = unpackResult.payload;
            mic = unpackResult.mic;
        } else {
            // Compute fallback MIC if engine is standalone
            var micCalc = new app.security.MicCalculator();
            mic = micCalc.calculate(arguments.rawBody, micAlg);
        }

        // Render synchronous MDN response
        var mdnGen = new app.security.MdnGenerator();
        var mdnRes = mdnGen.generateMdn(
            originalMessageId = messageId,
            as2From = as2To,
            as2To = as2From,
            status = "processed",
            mic = mic,
            micAlgorithm = micAlg
        );
        var mdnText = isStruct(mdnRes) ? mdnRes.body : mdnRes;

        if (isObject(variables.idempotencyStore)) {
            var idemKeySuccess = "AS2_" & as2From & "_" & messageId;
            variables.idempotencyStore.complete(idemKeySuccess, mdnText);
        }

        return {
            "statusCode": 200,
            "headers": {
                "AS2-Version": "1.2",
                "AS2-From": as2To,
                "AS2-To": as2From,
                "Message-ID": "<MDN_" & createUUID() & "@keystone>",
                "Content-Type": "multipart/report; report-type=disposition-notification"
            },
            "body": mdnText,
            "payload": processedPayload
        };
    }

    private string function getHeader(required struct headers, required string name) {
        for (var k in arguments.headers) {
            if (lCase(k) == lCase(arguments.name)) {
                return arguments.headers[k];
            }
        }
        return "";
    }

}
