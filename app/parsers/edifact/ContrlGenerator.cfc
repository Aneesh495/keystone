component {

    property name="idGenerator" type="any";
    property name="serializer" type="any";

    /**
     * Constructor for ContrlGenerator.
     */
    public any function init(any idGenerator = nullValue(), any serializer = nullValue()) {
        variables.idGenerator = isNull(arguments.idGenerator) ? new app.core.IdGenerator(nodeId = 1) : arguments.idGenerator;
        variables.serializer = isNull(arguments.serializer) ? new app.parsers.edifact.EdifactSerializer() : arguments.serializer;
        return this;
    }

    /**
     * Generates a UN/EDIFACT CONTRL acknowledgment message from an inbound ParseResult.
     */
    public struct function generateContrl(
        required any inboundParseResult,
        string senderId = "",
        string recipientId = ""
    ) {
        var inboundAst = arguments.inboundParseResult.getAst();
        var hasErrors = arguments.inboundParseResult.hasErrors();
        var errors = arguments.inboundParseResult.getErrors();

        var ic = (structKeyExists(inboundAst, "interchanges") && arrayLen(inboundAst.interchanges) > 0) ? inboundAst.interchanges[1] : {};
        var inboundSender = isArray(ic.sender) ? ic.sender[1] : (ic.sender ?: "PARTNER");
        var inboundRecipient = isArray(ic.recipient) ? ic.recipient[1] : (ic.recipient ?: "KEYSTONE");
        var inboundRef = isArray(ic.controlReference) ? ic.controlReference[1] : (ic.controlReference ?: "0001");

        var mySender = len(trim(arguments.senderId)) ? arguments.senderId : inboundRecipient;
        var myRecipient = len(trim(arguments.recipientId)) ? arguments.recipientId : inboundSender;

        var actionCode = hasErrors ? "4" : "7"; // 4 = Rejected, 7 = Acknowledged
        var unbRef = variables.idGenerator.nextControlNumber(9);
        var unhRef = variables.idGenerator.nextControlNumber(6);

        var segments = [];

        // 1. UNB Interchange Header
        arrayAppend(segments, {
            "id": "UNB",
            "elements": [
                ["UNOB", "2"],
                [mySender, "ZZZ"],
                [myRecipient, "ZZZ"],
                [dateFormat(now(), "yymmdd"), timeFormat(now(), "HHnn")],
                unbRef
            ]
        });

        // 2. UNH Message Header
        arrayAppend(segments, {
            "id": "UNH",
            "elements": [
                unhRef,
                ["CONTRL", "D", "4", "UN"]
            ]
        });

        // 3. UCI Interchange Response
        var uciElements = [
            inboundRef,
            [inboundSender, "ZZZ"],
            [inboundRecipient, "ZZZ"],
            actionCode
        ];
        if (hasErrors) {
            arrayAppend(uciElements, "12"); // Error code 12 = invalid value
        }
        arrayAppend(segments, {
            "id": "UCI",
            "elements": uciElements
        });

        // 4. UCM Message Response for each inbound message
        var messages = structKeyExists(ic, "messages") ? ic.messages : [];
        if (arrayLen(messages) > 0) {
            for (var msg in messages) {
                var mRef = msg.messageReference ?: "1";
                var mType = msg.type ?: "ORDERS";
                arrayAppend(segments, {
                    "id": "UCM",
                    "elements": [
                        mRef,
                        [mType, "D", "01B", "UN"],
                        actionCode
                    ]
                });
            }
        }

        // 5. UNT Message Trailer
        // Segments between UNH and UNT inclusive
        var untCount = (arrayLen(segments) - 1) + 1; // UNH to UNT
        arrayAppend(segments, {
            "id": "UNT",
            "elements": [untCount, unhRef]
        });

        // 6. UNZ Interchange Trailer
        arrayAppend(segments, {
            "id": "UNZ",
            "elements": ["1", unbRef]
        });

        var contrlAst = {
            "format": "EDIFACT",
            "type": "CONTRL",
            "segments": segments,
            "status": actionCode
        };

        var wireString = variables.serializer.serialize(contrlAst, {
            "newlineAfterSegment": true,
            "emitUna": false
        });

        return {
            "ast": contrlAst,
            "wire": wireString,
            "status": actionCode,
            "controlReference": unbRef
        };
    }
}
