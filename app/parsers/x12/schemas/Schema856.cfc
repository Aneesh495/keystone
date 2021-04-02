component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "856",
            "name": "Ship Notice / Manifest",
            "version": "005010",
            "functionalGroup": "SH",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BSN": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Purpose Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Shipment Identification", "type": "AN", "min": 2, "max": 30, "usage": "M"},
                        {"index": 3, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"},
                        {"index": 4, "name": "Time", "type": "TM", "min": 4, "max": 8, "usage": "M"}
                    ]
                },
                "HL": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Hierarchical ID Number", "type": "AN", "min": 1, "max": 12, "usage": "M"},
                        {"index": 2, "name": "Hierarchical Parent ID Number", "type": "AN", "min": 1, "max": 12, "usage": "O"},
                        {"index": 3, "name": "Hierarchical Level Code", "type": "ID", "min": 1, "max": 2, "usage": "M"}
                    ]
                },
                "LIN": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Assigned Identification", "type": "AN", "min": 1, "max": 20, "usage": "O"},
                        {"index": 2, "name": "Product/Service ID Qualifier", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 3, "name": "Product/Service ID", "type": "AN", "min": 1, "max": 48, "usage": "M"}
                    ]
                },
                "SN1": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Assigned Identification", "type": "AN", "min": 1, "max": 20, "usage": "O"},
                        {"index": 2, "name": "Number of Units Shipped", "type": "R", "min": 1, "max": 10, "usage": "M"},
                        {"index": 3, "name": "Unit of Measurement Code", "type": "ID", "min": 2, "max": 2, "usage": "M"}
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
