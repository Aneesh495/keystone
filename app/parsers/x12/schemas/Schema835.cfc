component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "835",
            "name": "Health Care Claim Payment / Advice",
            "version": "005010X221A1",
            "functionalGroup": "HP",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BPR": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Handling Code", "type": "ID", "min": 1, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Total Actual Provider Payment Amount", "type": "R", "min": 1, "max": 18, "usage": "M"},
                        {"index": 3, "name": "Credit or Debit Flag", "type": "ID", "min": 1, "max": 1, "usage": "M"},
                        {"index": 4, "name": "Payment Method Code", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 16, "name": "Check Issue or EFT Effective Date", "type": "DT", "min": 8, "max": 8, "usage": "M"}
                    ]
                },
                "TRN": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Trace Type Code", "type": "ID", "min": 1, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Reference Identification", "type": "AN", "min": 1, "max": 50, "usage": "M"},
                        {"index": 3, "name": "Originating Company Identifier", "type": "AN", "min": 10, "max": 10, "usage": "O"}
                    ]
                },
                "CLP": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Claim Submitter Identifier", "type": "AN", "min": 1, "max": 38, "usage": "M"},
                        {"index": 2, "name": "Claim Status Code", "type": "ID", "min": 1, "max": 2, "usage": "M"},
                        {"index": 3, "name": "Total Claim Charge Amount", "type": "R", "min": 1, "max": 18, "usage": "M"},
                        {"index": 4, "name": "Claim Payment Amount", "type": "R", "min": 1, "max": 18, "usage": "M"}
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
