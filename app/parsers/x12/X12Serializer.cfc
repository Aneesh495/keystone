component extends="app.parsers.base.ISerializer" {

    /**
     * Constructor for X12Serializer.
     */
    public any function init() {
        super.init();
        return this;
    }

    /**
     * Serializes an X12 AST into standard ASC X12 wire format.
     */
    public string function serialize(required struct ast, struct options = {}) {
        var elemSep = structKeyExists(arguments.options, "elementSeparator") ? arguments.options.elementSeparator : "*";
        var compSep = structKeyExists(arguments.options, "componentSeparator") ? arguments.options.componentSeparator : ":";
        var segTerm = structKeyExists(arguments.options, "segmentTerminator") ? arguments.options.segmentTerminator : "~";
        var addNewline = structKeyExists(arguments.options, "newlineAfterSegment") ? arguments.options.newlineAfterSegment : true;

        if (structKeyExists(arguments.ast, "delimiters") && isStruct(arguments.ast.delimiters)) {
            if (!structKeyExists(arguments.options, "elementSeparator")) elemSep = arguments.ast.delimiters.element ?: "*";
            if (!structKeyExists(arguments.options, "componentSeparator")) compSep = arguments.ast.delimiters.subElement ?: ":";
            if (!structKeyExists(arguments.options, "segmentTerminator")) segTerm = arguments.ast.delimiters.segment ?: "~";
        }

        var sb = createObject("java", "java.lang.StringBuilder").init();
        var nl = addNewline ? chr(10) : "";

        // If AST has flat segments array, serialize those directly
        if (structKeyExists(arguments.ast, "segments") && isArray(arguments.ast.segments) && arrayLen(arguments.ast.segments) > 0) {
            for (var seg in arguments.ast.segments) {
                var lineStr = formatSegment(seg, elemSep, compSep);
                sb.append(lineStr);
                sb.append(segTerm);
                sb.append(nl);
            }
            return sb.toString();
        }

        // If hierarchical interchanges structure
        if (structKeyExists(arguments.ast, "interchanges") && isArray(arguments.ast.interchanges)) {
            for (var ic in arguments.ast.interchanges) {
                // ISA segment fixed width formatting
                sb.append(formatIsa(ic, elemSep, compSep));
                sb.append(segTerm);
                sb.append(nl);

                if (structKeyExists(ic, "groups") && isArray(ic.groups)) {
                    for (var grp in ic.groups) {
                        // GS segment
                        var gsSeg = {
                            "id": "GS",
                            "elements": [
                                grp.functionalCode ?: "PO",
                                grp.senderId ?: "",
                                grp.receiverId ?: "",
                                grp.date ?: dateFormat(now(), "yyyymmdd"),
                                grp.time ?: timeFormat(now(), "HHnn"),
                                grp.controlNumber ?: "1",
                                grp.agencyCode ?: "X",
                                grp.version ?: "005010"
                            ]
                        };
                        sb.append(formatSegment(gsSeg, elemSep, compSep)).append(segTerm).append(nl);

                        if (structKeyExists(grp, "transactionSets") && isArray(grp.transactionSets)) {
                            for (var tx in grp.transactionSets) {
                                if (structKeyExists(tx, "segments") && isArray(tx.segments)) {
                                    for (var txSeg in tx.segments) {
                                        sb.append(formatSegment(txSeg, elemSep, compSep)).append(segTerm).append(nl);
                                    }
                                }
                            }
                        }

                        // GE segment
                        var geSeg = {
                            "id": "GE",
                            "elements": [
                                arrayLen(grp.transactionSets ?: []),
                                grp.controlNumber ?: "1"
                            ]
                        };
                        sb.append(formatSegment(geSeg, elemSep, compSep)).append(segTerm).append(nl);
                    }
                }

                // IEA segment
                var ieaSeg = {
                    "id": "IEA",
                    "elements": [
                        arrayLen(ic.groups ?: []),
                        ic.controlNumber ?: "000000001"
                    ]
                };
                sb.append(formatSegment(ieaSeg, elemSep, compSep)).append(segTerm).append(nl);
            }
            return sb.toString();
        }

        return "";
    }

    private string function formatSegment(required struct seg, required string elemSep, required string compSep) {
        // Special case for ISA to ensure strict 106 character layout
        if (seg.id == "ISA") {
            return formatIsaFromElements(seg.elements, arguments.elemSep, arguments.compSep);
        }

        var sb = createObject("java", "java.lang.StringBuilder").init(arguments.seg.id);
        if (structKeyExists(arguments.seg, "elements") && isArray(arguments.seg.elements)) {
            for (var elem in arguments.seg.elements) {
                sb.append(arguments.elemSep);
                if (isArray(elem)) {
                    // Composite element
                    var compSb = createObject("java", "java.lang.StringBuilder").init();
                    for (var cIdx = 1; cIdx <= arrayLen(elem); cIdx++) {
                        if (cIdx > 1) compSb.append(arguments.compSep);
                        compSb.append(toString(elem[cIdx]));
                    }
                    sb.append(compSb.toString());
                } else {
                    sb.append(toString(elem));
                }
            }
        }
        return sb.toString();
    }

    private string function formatIsa(required struct ic, required string elemSep, required string compSep) {
        var elements = [
            padString(ic.authorizationInfoQual ?: "00", 2),
            padString(ic.authorizationInfo ?: "", 10),
            padString(ic.securityInfoQual ?: "00", 2),
            padString(ic.securityInfo ?: "", 10),
            padString(ic.senderQualifier ?: "ZZ", 2),
            padString(ic.senderId ?: "", 15),
            padString(ic.receiverQualifier ?: "ZZ", 2),
            padString(ic.receiverId ?: "", 15),
            padString(ic.date ?: dateFormat(now(), "yymmdd"), 6),
            padString(ic.time ?: timeFormat(now(), "HHnn"), 4),
            ic.repetitionSeparator ?: "^",
            padString(ic.version ?: "00501", 5),
            padString(ic.controlNumber ?: "000000001", 9),
            ic.ackRequested ?: "0",
            ic.usageIndicator ?: "T",
            arguments.compSep
        ];
        return formatIsaFromElements(elements, arguments.elemSep, arguments.compSep);
    }

    private string function formatIsaFromElements(required array elems, required string elemSep, required string compSep) {
        var sb = createObject("java", "java.lang.StringBuilder").init("ISA");
        for (var i = 1; i <= arrayLen(arguments.elems); i++) {
            sb.append(arguments.elemSep);
            var rawVal = arguments.elems[i];
            var val = isArray(rawVal) ? arrayToList(rawVal, arguments.compSep) : toString(rawVal);

            // Apply X12 fixed width rules for ISA elements
            switch (i) {
                case 1: val = padString(val, 2); break;
                case 2: val = padString(val, 10); break;
                case 3: val = padString(val, 2); break;
                case 4: val = padString(val, 10); break;
                case 5: val = padString(val, 2); break;
                case 6: val = padString(val, 15); break;
                case 7: val = padString(val, 2); break;
                case 8: val = padString(val, 15); break;
                case 9: val = padString(val, 6); break;
                case 10: val = padString(val, 4); break;
                case 11: val = left(val, 1); break;
                case 12: val = padString(val, 5); break;
                case 13: val = padString(val, 9); break;
                case 14: val = left(val, 1); break;
                case 15: val = left(val, 1); break;
                case 16: val = left(val, 1); break;
            }
            sb.append(val);
        }
        return sb.toString();
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
