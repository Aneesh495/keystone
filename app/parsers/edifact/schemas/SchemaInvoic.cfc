component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "INVOIC",
            "name": "Commercial Invoice Message",
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
                        {"index": 2, "name": "Document Identification", "type": "AN", "usage": "M"},
                        {"index": 3, "name": "Message Function Code", "type": "ID", "usage": "O"}
                    ]
                },
                "MOA": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Monetary Amount Details", "type": "COMPOSITE", "usage": "M"}
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
