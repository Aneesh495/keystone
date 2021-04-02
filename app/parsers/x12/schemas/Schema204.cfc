component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "204",
            "name": "Motor Carrier Load Tender",
            "version": "005010",
            "functionalGroup": "SM",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "B2": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Tariff Agency Code", "type": "ID", "min": 1, "max": 4, "usage": "O"},
                        {"index": 2, "name": "Standard Carrier Alpha Code", "type": "ID", "min": 2, "max": 4, "usage": "M"},
                        {"index": 4, "name": "Shipment Identification Number", "type": "AN", "min": 1, "max": 30, "usage": "M"},
                        {"index": 6, "name": "Payment Method Code", "type": "ID", "min": 2, "max": 2, "usage": "M"}
                    ]
                },
                "B2A": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Purpose Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Application Type", "type": "ID", "min": 2, "max": 2, "usage": "O"}
                    ]
                },
                "S5": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Stop Sequence Number", "type": "N0", "min": 1, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Stop Reason Code", "type": "ID", "min": 2, "max": 2, "usage": "M"}
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
