component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "214",
            "name": "Transportation Carrier Shipment Status Message",
            "version": "005010",
            "functionalGroup": "QM",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "B10": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Reference Identification", "type": "AN", "min": 1, "max": 30, "usage": "O"},
                        {"index": 2, "name": "Shipment Identification Number", "type": "AN", "min": 1, "max": 30, "usage": "M"},
                        {"index": 3, "name": "Standard Carrier Alpha Code", "type": "ID", "min": 2, "max": 4, "usage": "M"}
                    ]
                },
                "AT7": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Shipment Status Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Shipment Status or Appointment Reason Code", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 5, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"},
                        {"index": 6, "name": "Time", "type": "TM", "min": 4, "max": 8, "usage": "M"}
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
