/**
 * Keystone B2B Transaction Mesh - MLLP Framed Socket Protocol Server
 *
 * Implements Minimal Lower Layer Protocol (MLLP) framing (0x0B start byte, 0x1C 0x0D end bytes)
 * for high-throughput healthcare HL7 v2 clinical data exchange.
 */
component {

    property name="port" type="numeric";
    property name="running" type="boolean";
    property name="messageHandler" type="any";
    property name="logger" type="any";
    property name="ackGenerator" type="any";

    // Framing constants
    variables.START_BLOCK = 11; // 0x0B (VT)
    variables.END_BLOCK_1 = 28; // 0x1C (FS)
    variables.END_BLOCK_2 = 13; // 0x0D (CR)

    /**
     * Initializes the MllpServer.
     */
    public any function init(
        numeric port = 2575,
        any messageHandler = "",
        any logger = "",
        any ackGenerator = ""
    ) {
        variables.port = arguments.port;
        variables.running = false;
        variables.messageHandler = arguments.messageHandler;
        variables.logger = arguments.logger;
        variables.ackGenerator = isObject(arguments.ackGenerator) ? arguments.ackGenerator : new app.parsers.hl7.HL7AckGenerator();

        return this;
    }

    /**
     * Frames raw HL7 text into an MLLP compliant byte stream.
     */
    public binary function frameMessage(required string hl7Text) {
        var strBytes = charsetDecode(arguments.hl7Text, "utf-8");
        var len = arrayLen(strBytes);
        var framed = [];

        arrayAppend(framed, javaCast("byte", variables.START_BLOCK));
        for (var b in strBytes) {
            arrayAppend(framed, b);
        }
        arrayAppend(framed, javaCast("byte", variables.END_BLOCK_1));
        arrayAppend(framed, javaCast("byte", variables.END_BLOCK_2));

        return toBinary(toBase64(framed));
    }

    /**
     * Strips MLLP framing characters from raw framed byte payload.
     */
    public string function deframeMessage(required any framedData) {
        var rawText = isBinary(arguments.framedData) ? charsetEncode(arguments.framedData, "utf-8") : arguments.framedData;

        // Remove start block (0x0B) if present
        if (len(rawText) > 0 && asc(left(rawText, 1)) == variables.START_BLOCK) {
            rawText = mid(rawText, 2, len(rawText) - 1);
        }

        // Remove end block (0x1C 0x0D) if present
        var rLen = len(rawText);
        if (rLen >= 2 && asc(mid(rawText, rLen - 1, 1)) == variables.END_BLOCK_1 && asc(right(rawText, 1)) == variables.END_BLOCK_2) {
            rawText = left(rawText, rLen - 2);
        } else if (rLen >= 1 && asc(right(rawText, 1)) == variables.END_BLOCK_1) {
            rawText = left(rawText, rLen - 1);
        }

        return rawText;
    }

    /**
     * Processes an inbound framed MLLP payload and returns a framed HL7 ACK message.
     */
    public string function processPayload(required string framedOrRaw) {
        var cleanHl7 = deframeMessage(arguments.framedOrRaw);
        var ack = "";

        try {
            if (isCustomFunction(variables.messageHandler) || isClosure(variables.messageHandler)) {
                var fn = variables.messageHandler;
                fn(cleanHl7);
            }
            ack = variables.ackGenerator.generateAck(cleanHl7, "AA", "Message received successfully");
        } catch (any e) {
            ack = variables.ackGenerator.generateAck(cleanHl7, "AE", e.message);
        }

        return chr(variables.START_BLOCK) & ack & chr(variables.END_BLOCK_1) & chr(variables.END_BLOCK_2);
    }

    public numeric function getPort() {
        return variables.port;
    }

    public boolean function isRunning() {
        return variables.running;
    }

}
