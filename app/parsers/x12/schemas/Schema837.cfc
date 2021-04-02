component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "837",
            "name": "Health Care Claim",
            "version": "005010X222A1",
            "functionalGroup": "HC",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BHT": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Hierarchical Structure Code", "type": "ID", "min": 4, "max": 4, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Purpose Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 3, "name": "Reference Identification", "type": "AN", "min": 1, "max": 50, "usage": "M"},
                        {"index": 4, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"},
                        {"index": 5, "name": "Time", "type": "TM", "min": 4, "max": 8, "usage": "M"},
                        {"index": 6, "name": "Transaction Type Code", "type": "ID", "min": 2, "max": 2, "usage": "M"}
                    ]
                },
                "NM1": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Entity Identifier Code", "type": "ID", "min": 2, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Entity Type Qualifier", "type": "ID", "min": 1, "max": 1, "usage": "M"},
                        {"index": 3, "name": "Name Last or Organization", "type": "AN", "min": 1, "max": 60, "usage": "O"},
                        {"index": 4, "name": "Name First", "type": "AN", "min": 1, "max": 35, "usage": "O"},
                        {"index": 8, "name": "Identification Code Qualifier", "type": "ID", "min": 1, "max": 2, "usage": "O"},
                        {"index": 9, "name": "Identification Code", "type": "AN", "min": 2, "max": 80, "usage": "O"}
                    ]
                },
                "CLM": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Claim Submitter Identifier", "type": "AN", "min": 1, "max": 38, "usage": "M"},
                        {"index": 2, "name": "Total Claim Charge Amount", "type": "R", "min": 1, "max": 18, "usage": "M"},
                        {"index": 5, "name": "Health Care Service Location Info", "type": "AN", "min": 1, "max": 30, "usage": "O"}
                    ]
                },
                "SV1": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Composite Medical Procedure", "type": "AN", "min": 1, "max": 48, "usage": "M"},
                        {"index": 2, "name": "Monetary Amount", "type": "R", "min": 1, "max": 18, "usage": "M"},
                        {"index": 3, "name": "Unit of Measurement", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 4, "name": "Quantity", "type": "R", "min": 1, "max": 15, "usage": "O"}
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
