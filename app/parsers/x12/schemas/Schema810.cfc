component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "810",
            "name": "Invoice",
            "version": "005010",
            "functionalGroup": "IN",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BIG": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Invoice Date", "type": "DT", "min": 8, "max": 8, "usage": "M"},
                        {"index": 2, "name": "Invoice Number", "type": "AN", "min": 1, "max": 22, "usage": "M"},
                        {"index": 3, "name": "Purchase Order Date", "type": "DT", "min": 8, "max": 8, "usage": "O"},
                        {"index": 4, "name": "Purchase Order Number", "type": "AN", "min": 1, "max": 22, "usage": "O"}
                    ]
                },
                "IT1": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Assigned Identification", "type": "AN", "min": 1, "max": 20, "usage": "O"},
                        {"index": 2, "name": "Quantity Invoiced", "type": "R", "min": 1, "max": 10, "usage": "M"},
                        {"index": 3, "name": "Unit of Measurement", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 4, "name": "Unit Price", "type": "R", "min": 1, "max": 17, "usage": "M"}
                    ]
                },
                "TDS": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Total Invoice Amount", "type": "N2", "min": 1, "max": 15, "usage": "M"}
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
