component {

    property name="idGenerator" type="any";
    property name="valueTransforms" type="any";

    public any function init(any idGenerator = nullValue()) {
        variables.idGenerator = isNull(arguments.idGenerator) ? new app.core.IdGenerator(nodeId = 1) : arguments.idGenerator;
        variables.valueTransforms = new app.transform.ValueTransforms();
        return this;
    }

    /**
     * Transforms Canonical Orders JSON into an X12 855 Purchase Order Acknowledgment AST.
     */
    public struct function transform(required struct orderJson) {
        var mySender = len(trim(arguments.orderJson.receiverId ?: "")) ? arguments.orderJson.receiverId : "KEYSTONE";
        var myReceiver = len(trim(arguments.orderJson.senderId ?: "")) ? arguments.orderJson.senderId : "PARTNER";
        var poNum = arguments.orderJson.orderNumber ?: "PO-0001";
        var poDate = variables.valueTransforms.toX12Date(arguments.orderJson.orderDate ?: dateFormat(now(), "yyyy-mm-dd"));

        var isaCtl = variables.idGenerator.nextControlNumber(9);
        var gsCtl = variables.idGenerator.nextControlNumber(6);
        var stCtl = variables.idGenerator.nextControlNumber(4);

        var segments = [];

        // ISA
        arrayAppend(segments, {
            "id": "ISA",
            "elements": [
                "00", "          ", "00", "          ",
                "ZZ", padString(mySender, 15),
                "ZZ", padString(myReceiver, 15),
                dateFormat(now(), "yymmdd"),
                timeFormat(now(), "HHnn"),
                "^", "00501", isaCtl, "0", "P", ":"
            ]
        });

        // GS
        arrayAppend(segments, {
            "id": "GS",
            "elements": [
                "PR", mySender, myReceiver,
                dateFormat(now(), "yyyymmdd"),
                timeFormat(now(), "HHnn"),
                gsCtl, "X", "005010"
            ]
        });

        // ST
        arrayAppend(segments, {
            "id": "ST",
            "elements": ["855", stCtl]
        });

        // BAK Purchase Order Acknowledgment Header
        // BAK01 = 00 (Original), BAK02 = AD (Acknowledge with Detail), BAK03 = PO Number, BAK04 = PO Date
        arrayAppend(segments, {
            "id": "BAK",
            "elements": ["00", "AD", poNum, poDate]
        });

        // Line Items
        var items = arguments.orderJson.items ?: [];
        var lineIdx = 0;
        for (var item in items) {
            lineIdx++;
            var qty = item.quantity ?: 1;
            var price = item.unitPrice ?: 0.0;
            var sku = item.sku ?: "";

            arrayAppend(segments, {
                "id": "PO1",
                "elements": [
                    toString(lineIdx),
                    qty,
                    "EA",
                    price,
                    "",
                    "VN",
                    sku
                ]
            });

            // ACK Line Item Status: IA = Item Accepted
            arrayAppend(segments, {
                "id": "ACK",
                "elements": ["IA", qty, "EA"]
            });
        }

        // CTT
        arrayAppend(segments, {
            "id": "CTT",
            "elements": [arrayLen(items)]
        });

        // SE
        var stIndex = 3;
        var seCount = (arrayLen(segments) - stIndex) + 2;
        arrayAppend(segments, {
            "id": "SE",
            "elements": [seCount, stCtl]
        });

        // GE
        arrayAppend(segments, {
            "id": "GE",
            "elements": ["1", gsCtl]
        });

        // IEA
        arrayAppend(segments, {
            "id": "IEA",
            "elements": ["1", isaCtl]
        });

        return {
            "format": "X12",
            "transactionCode": "855",
            "segments": segments,
            "controlNumber": isaCtl
        };
    }

    private string function padString(required string str, required numeric targetLen) {
        var s = trim(arguments.str);
        while (len(s) < arguments.targetLen) s &= " ";
        if (len(s) > arguments.targetLen) s = left(s, arguments.targetLen);
        return s;
    }
}
