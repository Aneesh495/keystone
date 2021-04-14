component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "ORDERS",
            "name": "Purchase Order Message",
            "version": "D",
            "release": "01B",
            "agency": "UN",
            "segments": {
                "UNH": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Message Reference Number", "type": "AN", "usage": "M"},
                        {"index": 2, "name": "Message Identifier", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "BGM": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Document/Message Name", "type": "COMPOSITE", "usage": "M"},
                        {"index": 2, "name": "Document/Message Identification", "type": "AN", "usage": "M"},
                        {"index": 3, "name": "Message Function Code", "type": "ID", "usage": "O"}
                    ]
                },
                "DTM": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Date/Time/Period", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "NAD": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Party Function Code Qualifier", "type": "ID", "usage": "M"},
                        {"index": 2, "name": "Party Identification Details", "type": "COMPOSITE", "usage": "O"},
                        {"index": 4, "name": "Party Name", "type": "COMPOSITE", "usage": "O"}
                    ]
                },
                "LIN": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Line Item Number", "type": "N", "usage": "M"},
                        {"index": 3, "name": "Item Number Identification", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "QTY": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Quantity Details", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "MOA": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Monetary Amount Details", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "PRI": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Price Details", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "UNS": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Section Identification", "type": "ID", "usage": "M"}
                    ]
                },
                "CNT": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Control Total Details", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "UNT": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Number of Segments in a Message", "type": "N", "usage": "M"},
                        {"index": 2, "name": "Message Reference Number", "type": "AN", "usage": "M"}
                    ]
                }
            }
        };
    }
}
