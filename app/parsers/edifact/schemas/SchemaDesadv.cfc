component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "DESADV",
            "name": "Despatch Advice Message",
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
                "DTM": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Date/Time/Period", "type": "COMPOSITE", "usage": "M"}
                    ]
                },
                "CPS": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Hierarchical ID Number", "type": "AN", "usage": "M"},
                        {"index": 2, "name": "Hierarchical Parent ID", "type": "AN", "usage": "O"},
                        {"index": 3, "name": "Packaging Level Code", "type": "ID", "usage": "O"}
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
