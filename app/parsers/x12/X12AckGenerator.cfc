component {

    property name="idGenerator" type="any";
    property name="serializer" type="any";

    /**
     * Constructor for X12AckGenerator.
     */
    public any function init(any idGenerator = nullValue(), any serializer = nullValue()) {
        variables.idGenerator = isNull(arguments.idGenerator) ? new app.core.IdGenerator(nodeId = 1) : arguments.idGenerator;
        variables.serializer = isNull(arguments.serializer) ? new app.parsers.x12.X12Serializer() : arguments.serializer;
        return this;
    }

    /**
     * Generates an X12 997 Functional Acknowledgment AST and wire string from an inbound ParseResult.
     *
     * @inboundParseResult app.parsers.base.ParseResult from parsed inbound X12 message
     * @receiverId Optional receiver ID override
     * @senderId Optional sender ID override
     * @return Struct containing 'ast' and 'wire' string
     */
    public struct function generate997(
        required any inboundParseResult,
        string senderId = "",
        string receiverId = ""
    ) {
        var inboundAst = arguments.inboundParseResult.getAst();
        var hasErrors = arguments.inboundParseResult.hasErrors();
        var errors = arguments.inboundParseResult.getErrors();

        // Extract inbound interchange and group details
        var inboundIc = (structKeyExists(inboundAst, "interchanges") && arrayLen(inboundAst.interchanges) > 0) ? inboundAst.interchanges[1] : {};
        var inboundSender = len(trim(arguments.senderId)) ? arguments.senderId : (inboundIc.receiverId ?: "KEYSTONE");
        var inboundReceiver = len(trim(arguments.receiverId)) ? arguments.receiverId : (inboundIc.senderId ?: "PARTNER");
        var inboundIcCtl = inboundIc.controlNumber ?: "000000001";

        var groups = structKeyExists(inboundIc, "groups") ? inboundIc.groups : [];
        var inboundGrp = arrayLen(groups) > 0 ? groups[1] : {};
        var inboundFuncCode = inboundGrp.functionalCode ?: "PO";
        var inboundGrpCtl = inboundGrp.controlNumber ?: "1";

        var txSets = structKeyExists(inboundGrp, "transactionSets") ? inboundGrp.transactionSets : [];
        var txCount = arrayLen(txSets);
        var acceptedCount = hasErrors ? 0 : txCount;

        var ackStatus = hasErrors ? "R" : "A"; // Rejected or Accepted

        var isaCtl = variables.idGenerator.nextControlNumber(9);
        var gsCtl = variables.idGenerator.nextControlNumber(6);
        var stCtl = variables.idGenerator.nextControlNumber(4);

        var segments = [];

        // 1. ISA Envelope
        arrayAppend(segments, {
            "id": "ISA",
            "elements": [
                "00", "          ", "00", "          ",
                "ZZ", padString(inboundSender, 15),
                "ZZ", padString(inboundReceiver, 15),
                dateFormat(now(), "yymmdd"),
                timeFormat(now(), "HHnn"),
                "^", "00501", isaCtl, "0", "P", ":"
            ]
        });

        // 2. GS Functional Group
        arrayAppend(segments, {
            "id": "GS",
            "elements": [
                "FA", inboundSender, inboundReceiver,
                dateFormat(now(), "yyyymmdd"),
                timeFormat(now(), "HHnn"),
                gsCtl, "X", "005010"
            ]
        });

        // 3. ST Transaction Set Header (997)
        arrayAppend(segments, {
            "id": "ST",
            "elements": ["997", stCtl]
        });

        // 4. AK1 Functional Group Response Header
        arrayAppend(segments, {
            "id": "AK1",
            "elements": [inboundFuncCode, inboundGrpCtl]
        });

        // 5. AK2 & AK5 for each transaction set
        if (txCount > 0) {
            for (var tx in txSets) {
                var txCode = tx.transactionCode ?: "850";
                var txCtl = tx.controlNumber ?: "0001";
                arrayAppend(segments, {
                    "id": "AK2",
                    "elements": [txCode, txCtl]
                });

                // If errors, append AK3/AK4 notes
                if (hasErrors) {
                    for (var err in errors) {
                        arrayAppend(segments, {
                            "id": "AK3",
                            "elements": [err.segmentId ?: "SEG", "1", ""]
                        });
                        arrayAppend(segments, {
                            "id": "AK4",
                            "elements": ["1", "1", "1", err.message]
                        });
                    }
                }

                arrayAppend(segments, {
                    "id": "AK5",
                    "elements": [ackStatus]
                });
            }
        } else {
            // Default AK2/AK5
            arrayAppend(segments, {
                "id": "AK2",
                "elements": ["850", "0001"]
            });
            arrayAppend(segments, {
                "id": "AK5",
                "elements": [ackStatus]
            });
        }

        // 6. AK9 Functional Group Response Trailer
        arrayAppend(segments, {
            "id": "AK9",
            "elements": [
                ackStatus,
                max(1, txCount),
                max(1, txCount),
                acceptedCount
            ]
        });

        // 7. SE Transaction Set Trailer
        // SE counts all segments between ST and SE inclusive
        // Current segments inside ST: ST(1), AK1(1), AK2/AK5 items, AK9(1), SE(1)
        var stIndex = 3;
        var seCount = (arrayLen(segments) - stIndex) + 2;
        arrayAppend(segments, {
            "id": "SE",
            "elements": [seCount, stCtl]
        });

        // 8. GE Functional Group Trailer
        arrayAppend(segments, {
            "id": "GE",
            "elements": ["1", gsCtl]
        });

        // 9. IEA Interchange Trailer
        arrayAppend(segments, {
            "id": "IEA",
            "elements": ["1", isaCtl]
        });

        var ackAst = {
            "format": "X12",
            "type": "997",
            "segments": segments,
            "status": ackStatus
        };

        var wireString = variables.serializer.serialize(ackAst, {
            "newlineAfterSegment": true
        });

        return {
            "ast": ackAst,
            "wire": wireString,
            "status": ackStatus,
            "controlNumber": isaCtl
        };
    }

    private string function padString(required string str, required numeric targetLen) {
        var s = trim(arguments.str);
        while (len(s) < arguments.targetLen) {
            s &= " ";
        }
        if (len(s) > arguments.targetLen) {
            s = left(s, arguments.targetLen);
        }
        return s;
    }
}
