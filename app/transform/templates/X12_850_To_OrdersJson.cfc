component {

    property name="valueTransforms" type="any";

    public any function init() {
        variables.valueTransforms = new app.transform.ValueTransforms();
        return this;
    }

    /**
     * Transforms an X12 850 Purchase Order AST into canonical Orders JSON model.
     */
    public struct function transform(required struct ast) {
        var segments = arguments.ast.segments ?: [];
        var order = {
            "orderNumber": "",
            "orderDate": "",
            "currency": "USD",
            "senderId": "",
            "receiverId": "",
            "shipTo": {},
            "items": [],
            "summary": {
                "totalItems": 0,
                "totalQuantity": 0,
                "orderTotal": 0.0
            }
        };

        // Extract sender and receiver from ISA
        if (structKeyExists(arguments.ast, "interchanges") && arrayLen(arguments.ast.interchanges) > 0) {
            var ic = arguments.ast.interchanges[1];
            order.senderId = ic.senderId ?: "";
            order.receiverId = ic.receiverId ?: "";
        }

        var currentItem = nullValue();
        var lineCount = 0;
        var totalQty = 0;
        var totalAmount = 0.0;

        for (var seg in segments) {
            var segId = seg.id;
            var elems = seg.elements ?: [];

            if (segId == "BEG") {
                order.orderNumber = arrayLen(elems) >= 3 ? toString(elems[3]) : "";
                var rawDt = arrayLen(elems) >= 5 ? toString(elems[5]) : "";
                order.orderDate = variables.valueTransforms.toIsoDate(rawDt);
            } else if (segId == "CUR") {
                order.currency = arrayLen(elems) >= 2 ? toString(elems[2]) : "USD";
            } else if (segId == "N1") {
                var entityCode = arrayLen(elems) >= 1 ? toString(elems[1]) : "";
                if (entityCode == "ST") {
                    order.shipTo = {
                        "name": arrayLen(elems) >= 2 ? toString(elems[2]) : "",
                        "codeQualifier": arrayLen(elems) >= 3 ? toString(elems[3]) : "",
                        "code": arrayLen(elems) >= 4 ? toString(elems[4]) : ""
                    };
                }
            } else if (segId == "N3") {
                if (!structIsEmpty(order.shipTo)) {
                    order.shipTo["address1"] = arrayLen(elems) >= 1 ? toString(elems[1]) : "";
                }
            } else if (segId == "N4") {
                if (!structIsEmpty(order.shipTo)) {
                    order.shipTo["city"] = arrayLen(elems) >= 1 ? toString(elems[1]) : "";
                    order.shipTo["state"] = arrayLen(elems) >= 2 ? toString(elems[2]) : "";
                    order.shipTo["postalCode"] = arrayLen(elems) >= 3 ? toString(elems[3]) : "";
                    order.shipTo["country"] = arrayLen(elems) >= 4 ? toString(elems[4]) : "US";
                }
            } else if (segId == "PO1") {
                lineCount++;
                var lineNum = arrayLen(elems) >= 1 ? toString(elems[1]) : toString(lineCount);
                var qty = arrayLen(elems) >= 2 ? val(elems[2]) : 0;
                var uom = arrayLen(elems) >= 3 ? toString(elems[3]) : "EA";
                var price = arrayLen(elems) >= 4 ? val(elems[4]) : 0.0;
                var sku = arrayLen(elems) >= 7 ? toString(elems[7]) : "";

                var lineTotal = round((qty * price) * 100) / 100;
                totalQty += qty;
                totalAmount += lineTotal;

                currentItem = {
                    "lineNumber": lineNum,
                    "quantity": qty,
                    "unitOfMeasure": variables.valueTransforms.mapUom(uom),
                    "unitPrice": price,
                    "lineTotal": lineTotal,
                    "sku": sku,
                    "description": ""
                };
                arrayAppend(order.items, currentItem);
            } else if (segId == "PID") {
                if (arrayLen(order.items) > 0) {
                    var lastIdx = arrayLen(order.items);
                    var desc = arrayLen(elems) >= 5 ? toString(elems[5]) : "";
                    order.items[lastIdx].description = desc;
                }
            }
        }

        order.summary.totalItems = arrayLen(order.items);
        order.summary.totalQuantity = totalQty;
        order.summary.orderTotal = round(totalAmount * 100) / 100;

        return order;
    }
}
