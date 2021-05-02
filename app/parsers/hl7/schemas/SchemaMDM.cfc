component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "MDM",
            "name": "Medical Document Management",
            "version": "2.5.1",
            "segments": {
                "MSH": {"usage": "M", "description": "Message Header"},
                "EVN": {"usage": "M", "description": "Event Type"},
                "PID": {"usage": "M", "description": "Patient Identification"},
                "PV1": {"usage": "O", "description": "Patient Visit"},
                "TXA": {"usage": "M", "description": "Document Notification"},
                "OBX": {"usage": "O", "description": "Document Content / Observation"}
            }
        };
    }
}
