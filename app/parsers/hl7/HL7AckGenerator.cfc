component {

    property name="idGenerator" type="any";
    property name="serializer" type="any";

    /**
     * Constructor for HL7AckGenerator.
     */
    public any function init(any idGenerator = nullValue(), any serializer = nullValue()) {
        variables.idGenerator = isNull(arguments.idGenerator) ? new app.core.IdGenerator(nodeId = 1) : arguments.idGenerator;
        variables.serializer = isNull(arguments.serializer) ? new app.parsers.hl7.HL7Serializer() : arguments.serializer;
        return this;
    }

    /**
     * Generates standard HL7 ACK message for an inbound HL7 message.
     */
    public any function generateAck(
        required any inboundParseResult,
        string ackCode = "AA",
        string textMessage = "Message accepted successfully"
    ) {
        var pResult = arguments.inboundParseResult;
        if (isSimpleValue(pResult)) {
            pResult = new app.parsers.hl7.HL7Parser().parse(pResult);
        }
        var inboundAst = pResult.getAst();
        var header = inboundAst.header ?: {};
        var hasErrors = pResult.hasErrors();

        var resolvedAckCode = hasErrors ? "AE" : arguments.ackCode;
        var inboundControlId = header.controlId ?: "00000001";
        var outControlId = variables.idGenerator.nextControlNumber(9);

        var myApp = len(trim(header.receivingApplication ?: "")) ? header.receivingApplication : "KEYSTONE_EHR";
        var myFac = len(trim(header.receivingFacility ?: "")) ? header.receivingFacility : "HOSPITAL_SYS";
        var sendApp = len(trim(header.sendingApplication ?: "")) ? header.sendingApplication : "CLIENT_APP";
        var sendFac = len(trim(header.sendingFacility ?: "")) ? header.sendingFacility : "CLIENT_FAC";

        var segments = [];

        // 1. MSH Message Header
        arrayAppend(segments, {
            "id": "MSH",
            "elements": [
                "|",
                "^~\&",
                myApp,
                myFac,
                sendApp,
                sendFac,
                dateTimeFormat(now(), "yyyymmddHHnnss"),
                "",
                ["ACK", header.triggerEvent ?: "A01", "ACK"],
                outControlId,
                header.processingId ?: "P",
                header.versionId ?: "2.5.1"
            ]
        });

        // 2. MSA Message Acknowledgment Segment
        arrayAppend(segments, {
            "id": "MSA",
            "elements": [
                resolvedAckCode,
                inboundControlId,
                hasErrors ? "Error processing message" : arguments.textMessage
            ]
        });

        // 3. Optional ERR segment if errors occurred
        if (hasErrors) {
            var errList = arguments.inboundParseResult.getErrors();
            var firstErr = arrayLen(errList) > 0 ? errList[1].message : "Validation failure";
            arrayAppend(segments, {
                "id": "ERR",
                "elements": [
                    ["", "", "", "207", firstErr]
                ]
            });
        }

        var ackAst = {
            "format": "HL7",
            "type": "ACK",
            "status": resolvedAckCode,
            "segments": segments
        };

        var wireString = variables.serializer.serialize(ackAst, {
            "lineTerminator": chr(13)
        });

        return {
            "ast": ackAst,
            "wire": wireString,
            "status": resolvedAckCode,
            "controlId": outControlId
        };
    }
}
