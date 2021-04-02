component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "855",
            "name": "Purchase Order Acknowledgment",
            "version": "005010",
            "functionalGroup": "PR",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BAK": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Purpose Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Acknowledgment Type", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 3, "name": "Purchase Order Number", "type": "AN", "min": 1, "max": 22, "usage": "M"},
                        {"index": 4, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"}
                    ]
                },
                "ACK": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Line Item Status Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Quantity", "type": "R", "min": 1, "max": 15, "usage": "O"},
                        {"index": 3, "name": "Unit of Measurement", "type": "ID", "min": 2, "max": 2, "usage": "O"}
                    ]
                },
                "CTT": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Number of Line Items", "type": "N0", "min": 1, "max": 6, "usage": "M"}
                    ]
                },
                "SE": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Number of Included Segments", "type": "N0", "min": 1, "max": 10, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                }
            }
        };
    }
}
